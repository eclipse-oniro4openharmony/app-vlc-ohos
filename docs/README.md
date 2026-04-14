# VLC for OpenHarmony — Documentation Overview

This directory contains the design and execution documents for porting VLC media player to OpenHarmony / HarmonyOS NEXT. This README summarizes the two primary documents:

- [`Porting_VLC_to_OpenHarmony_research.md`](./Porting_VLC_to_OpenHarmony_research.md) — the architectural research/blueprint.
- [`vlc_ohos_implementation_plan.md`](./vlc_ohos_implementation_plan.md) — the atomic, phase-by-phase execution plan with live status.

Additional references:
- [`vlc_contrib_audit.md`](./vlc_contrib_audit.md) — audit of VLC's third-party contrib dependencies.
- [`vlc_ohos_napi_architecture.md`](./vlc_ohos_napi_architecture.md) — detailed NAPI binding layer design.

---

## 1. Research Blueprint (summary)

The research document outlines *why* the port is needed and *how* each VLC subsystem must be rebuilt for HarmonyOS NEXT, which has fully deprecated Android/JNI compatibility.

### Subsystem transition matrix

| Subsystem | Android | HarmonyOS NEXT |
|---|---|---|
| App framework | Java/Kotlin (ART) | ArkTS (Ark Compiler) |
| Native bridge | JNI | Node-API (NAPI) |
| Build system | Gradle + ndk-build/CMake | Hvigor + CMake (`ohos.toolchain.cmake`) |
| Video rendering | SurfaceView / ANativeWindow | XComponent / OHNativeWindow |
| Audio rendering | AudioTrack / OpenSL ES | OHAudio (AudioRenderer) |
| HW codecs | MediaCodec (OMX) | OH_AVCodec (async callbacks) |
| Page size | 4 KB | **16 KB enforced** |

### Key architectural decisions

- **Core is portable.** VLC's ~380 modules (demuxers, packetizers, software decoders) cross-compile with minimal change; effort concentrates on I/O boundaries.
- **Contribs via OpenHarmony NDK.** FFmpeg, libplacebo, libass, dav1d, x264/x265, etc. are built from source using `--target=aarch64-linux-ohos` and the SDK sysroot. 16 KB ELF segment alignment is mandatory.
- **NAPI replaces JNI.** `libvlc_instance_t`, `libvlc_media_t`, and `libvlc_media_player_t` are exposed via `napi_wrap` / `napi_unwrap`, with finalizers tied to the ArkTS GC for `libvlc_release`. SWIG is recommended to generate the broader API surface.
- **Thread safety.** VLC's background threads dispatch events to ArkTS via `napi_threadsafe_function`, with careful `napi_handle_scope` management in high-frequency callbacks (e.g., `TimeChanged`).
- **Video output.** An XComponent-backed vout reads an `OHNativeWindow*` from `onSurfaceCreated`, builds an EGL/GLES2 surface, and reuses VLC's existing GL shaders. System scaling modes (`SCALE_CROP_V2`, `SCALE_FIT_V2`, `SCALE_TO_WINDOW_V2`) offload aspect-ratio work to the compositor.
- **Audio output.** An OHAudio aout uses the builder pattern (`OH_AudioStreamBuilder_*`), registers a pull-based `OnWriteData` callback, and subscribes to native interrupt events for focus changes.
- **Hardware decoding.** A new `ohos_avcodec` decoder module wraps `OH_VideoDecoder_*` with async `OnNeedInputData` / `OnNewOutputData` callbacks. Surface mode (`OH_VideoDecoder_SetSurface` + `RenderOutputData`) enables zero-copy rendering directly to the XComponent.
- **Demuxing strategy.** Keep VLC's internal demuxers and libavformat for format breadth; use OpenHarmony demuxers only where advantageous.
- **Packaging.** `.hap` bundle via Hvigor, permissions declared in `module.json5`, mandatory Hapsigner cryptographic signing.

---

## 2. Implementation Plan (summary)

The plan is split into atomic, independently testable tasks across ten phases. Current progress (✅ = done, 🟡 = partial, ⬜ = pending):

| Phase | Topic | Status |
|---|---|---|
| 0 | SDK + project scaffold, submodule, master build script | ✅ |
| 1 | Cross-compile contribs (FFmpeg, x264/x265, dav1d, libass, …) | ✅ |
| 2 | Cross-compile libvlccore, libvlc, built-in plugins, install bundle | ✅ |
| 3 | NAPI bindings (instance / media / player / events / module registration / `.d.ts` / CMake) | ✅ (3.10 SWIG investigation pending) |
| 4 | Video output — XComponent + `OHNativeWindow`, software path, EGL/GLES2 path, scaling | ✅ (4.6 surface lifecycle robustness pending) |
| 5 | Audio output — OHAudio boilerplate, builder, async write callback, renderer lifecycle | ✅ through 5.4; 5.5 interrupts and 5.6 dynamic format pending |
| 6 | Hardware video decoding via `OH_AVCodec` (zero-copy to XComponent) | ⬜ |
| 7 | ArkTS UI — VlcService, player page, file picker, lifecycle | ✅ through 7.3, 7.5; 7.4 network streams pending |
| 8 | Packaging — permissions, build profile, library bundling, plugin path, signing | ✅ |
| 9 | Testing — functional matrix, perf benchmarks, ASan | ⬜ |
| 10 | Enhancements — subtitles, background audio, media session, cast, PiP | ⬜ |

### Critical implementation notes captured in the plan

- **Contribs (Phase 1):** Patches were required for `config.sub` (`linux-ohos*`), `aribb24` bootstrap, OpenHarmony's broken `diff` overriding GNU diff, `cddb`/AM_ICONV, `libgpg-error` pthread detection, `libvpx` cross-compile, missing `STRINGS/NM/OBJDUMP` in `HOSTTOOLS`, and sidplay2 narrowing. Disabled packages: `protobuf`, `lua`, `xcb`, `srt`, `cddb`.
- **libVLC (Phase 2):** `autoconf` patched to recognize `linux-ohos*` and define `HAVE_OHOS`. Stubbed `pthread_cancel`, `posix_close`. Disabled DBus. Forced `have_gl="no"`. Added `-lc++_shared` globally. NDK sysroot patched for missing `O_TMPFILE` in `fortify.h`.
- **NAPI (Phase 3):** Threadsafe function pattern used for all VLC events. Custom registry `g_windowRegistry` maps players to `OHNativeWindow*`. Plugin path injected via `--plugin-path=/data/storage/el1/bundle/libs/arm64` + `VLC_PLUGIN_PATH` env.
- **Video (Phase 4):** Software path uses `OH_NativeWindow_NativeWindowRequestBuffer` + `mmap` with `NATIVEBUFFER_PIXEL_FMT_RGBA_8888` (fmt 12) — using the wrong pixel format produced a persistent black screen. EGL config must include `EGL_ALPHA_SIZE, 8` to avoid `EGL_BAD_MATCH`. Aspect ratio work uses `SET_SCALING_MODE` (11) on the native window plus `libvlc_video_set_aspect_ratio`.
- **Audio (Phase 5):** Renderer creation must happen in `Start` (format is only known then). A thread-safe block chain bridges VLC's push model to OHAudio's pull callback, with a 2 MB overflow cap.
- **UI (Phase 7):** File picker returns URIs that are opened via `fs` and passed to `libvlc_media_new_from_fd` to avoid URI encoding issues. Player cleanup runs on a background `std::thread` to avoid UI deadlocks; `OHNativeWindow` destruction is deferred until `libvlc_media_player_stop` returns to avoid SIGSEGV. The global `libvlc_instance_t` is reused across ability lifecycle transitions to prevent `vlc_vaLog` crashes.
- **Packaging (Phase 8):** `scripts/run-ohos-app.sh` gathers `libvlc.so`, `libvlccore.so`, all plugins, and contribs into `entry/libs/arm64-v8a/` for Hvigor to bundle. Debug and release signing configured at the project level.

### Execution order

Phases 0 → 1 → 2 are strictly sequential. Phases 4, 5, and 6 can be developed in parallel after Phase 2. Phase 7 integrates them; Phase 8 packages; Phase 9 validates.

---

## Quick commands

```sh
# Build, deploy, run, collect logs (with optional grep filter)
scripts/run-ohos-app.sh --grep <pattern>

# Pull native init log from device
hdc file recv /data/app/el2/100/base/org.oniroproject.vlc/haps/entry/files/vlc_init.log ./vlc_init.log
```
