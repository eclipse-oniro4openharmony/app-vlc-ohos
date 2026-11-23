# VLC for OpenHarmony & Oniro

VLC for OpenHarmony is a native port of the world-renowned [VLC Media Player](https://www.videolan.org/vlc/) to the **OpenHarmony**, **HarmonyOS NEXT**, and **Oniro** ecosystems. This repository contains a Git submodule pointing to a fork of the native `libVLC` engine with OpenHarmony adaptations, alongside custom OpenHarmony I/O modules, and the ArkTS-based user interface.

## Overview

The project bridges the powerful, format-agnostic `libVLC` core with the modern, high-performance HarmonyOS NEXT/Oniro architecture. By discarding legacy Android dependencies (JNI, Dalvik/ART), this port utilizes the **OpenHarmony Native Development Kit (NDK)** and **Node-API (NAPI)** to achieve deep system integration and low-latency multimedia performance.

### Key Features
- **Ubiquitous Format Support**: Inherited from VLC's modular core (MKV, MP4, AVI, TS, FLV, and more).
- **Native Rendering**: High-performance video output via `XComponent` and `OHNativeWindow` (supporting both software and EGL/GLES paths).
- **Low-Latency Audio**: Integration with the `OHAudio` framework for system-native audio routing and management.
- **ArkTS Interface**: A modern, responsive UI built with ArkUI, featuring a full-featured player controls, file picker integration, and adaptive scaling.
- **NAPI Binding Layer**: Robust C++/ArkTS bridge with thread-safe event handling and automatic memory lifecycle management.

## Architecture

The application follows a multi-layered architectural approach:

1.  **UI Layer (ArkTS)**: The main application logic and declarative UI components (ArkUI).
2.  **NAPI Bridge (C++)**: An ABI-stable bridge between the ArkTS engine and the native C/C++ core.
3.  **libVLC Engine**: The core multimedia engine, cross-compiled for the `aarch64-linux-ohos` target.
4.  **OpenHarmony Native Modules**: Custom VLC plugins for video output (`vout`), audio output (`aout`), and hardware acceleration (`OH_AVCodec`).

For more details, see:
- [Technical Blueprint](docs/Porting_VLC_to_OpenHarmony_research.md)
- [NAPI Binding Layer Architecture](docs/vlc_ohos_napi_architecture.md)

## Project Structure

```text
.
├── AppScope/                # Application-wide resources
├── entry/                   # Main HAP module (ArkTS UI + Native CMake)
│   └── src/main/cpp/        # Native source and NAPI entry points
├── libvlc/                  # libVLC source code (Git submodule)
├── modules/                 # Custom OpenHarmony VLC plugins (vout, aout)
├── napi/                    # Reusable NAPI wrapper logic
├── scripts/                 # Build and deployment orchestration scripts
└── docs/                    # Architectural and implementation documentation
```

## Getting Started

### Prerequisites
- **OpenHarmony SDK** (API 20+ / HarmonyOS NEXT compatible).
- **DevEco Studio** (latest stable version).
- **Node.js** and **npm** (for Hvigor build system).
- **Linux** build host (recommended for cross-compiling the `libVLC` contrib system).

### Build Instructions

1.  **Clone the repository**:
    ```bash
    git clone --recursive https://github.com/eclipse-oniro4openharmony/app-vlc-ohos.git
    cd app-vlc-ohos
    ```

2.  **Build libVLC and Dependencies**:
    `scripts/build_native.sh` cross-compiles the third-party libraries (FFmpeg, libass, etc.) and libVLC with the SDK's NDK, then copies the libraries into `entry/libs/arm64-v8a`:
    ```bash
    # --install-deps installs the host build tools with apt-get (Ubuntu 24.04)
    bash scripts/build_native.sh --install-deps
    ```
    The NDK is found at `~/setup-ohos-sdk/linux/<compileSdkVersion>/native`; set `OHOS_BASE_SDK_HOME` or `OHOS_NDK_HOME` if the SDK is elsewhere. The steps (`contribs`, `libvlc`, `stage`) can be run one at a time, and re-running one rebuilds only what changed. See `scripts/build_native.sh --help`.

3.  **Build the HAP Application**:
    Open the project in DevEco Studio or use the command line:
    ```bash
    hvigorw assembleHap
    ```

4.  **Run on Device**:
    Use the provided utility script to stage the libraries, build and deploy:
    ```bash
    bash scripts/run-ohos-app.sh
    ```

## Status & Roadmap

The project is currently in a functional prototype phase.

- [x] **Phase 1-2**: Cross-compilation of `libVLC` and critical contribs (FFmpeg, Freetype, etc.).
- [x] **Phase 3**: Core NAPI binding layer (Instance, Media, MediaPlayer, Events).
- [x] **Phase 4**: Software and GLES2 Video Output (`XComponent` + `OHNativeWindow`).
- [x] **Phase 5**: Audio Output via `OHAudio`.
- [x] **Phase 7**: Basic ArkTS UI with File Picker and lifecycle management.
- [x] **Phase 8**: App screens modelled on VLC for Android 3.7 (see below).
- [ ] **Phase 6**: Hardware-accelerated decoding via `OH_AVCodec` (Planned).
- [ ] **Phase 10**: Subtitle rendering, PiP mode, and Media Session integration.

See the [Implementation Plan](docs/vlc_ohos_implementation_plan.md) for a detailed breakdown.

### App screens

The UI follows VLC for Android 3.7:

- **Video**: the user picks videos with the system file picker. Access to them is persisted (`ohos.permission.FILE_ACCESS_PERSIST`), so the list is still playable after a restart. Each row shows the duration, resolution and a thumbnail, and has Information and Remove actions.
- **Player**: play/pause, seek bar with elapsed or remaining time, forward and back jumps, screen lock, resize modes, audio and subtitle track selection, playback speed, and resume from the last position.
- **Information**: the media's duration, size and tracks, read by libVLC's parser (`mediaParse` in `napi/vlc_extra_wrap.cpp`) and by the platform's `AVMetadataExtractor`.
- **More**: history of played media, streams (play a network address), Settings (resume playback, playback history, jump delay, theme) and About.

The library, history and streams live in a relational store (`vlc.db`), and settings in Preferences. Unit tests for the stores and formatters are in `entry/src/ohosTest`.

Known issues:
- Network streams (`http://`) do not open yet: libVLC's HTTP access reports "connection failure", even for addresses the device can reach.
- Subtitle tracks can be selected, but the subtitles are not drawn on the video yet.
- A resumed video starts at 0 and then jumps to the saved position.

## Publishing to the Oniro App Store

Pushing a version tag publishes the app: bump `versionCode` and `versionName` in `AppScope/app.json5`, commit, then `git tag v1.2.3 && git push origin v1.2.3`. The [store workflow](.github/workflows/oniro-store.yml) checks out the commit with the `libvlc` submodule, runs `scripts/build_native.sh` on a GitHub runner, builds and signs the HAP, attaches it to the tag's GitHub release and registers it with the store, which shows it as *Built from source*. libVLC and its contribs are built from scratch on every run, which takes most of the build time; pull requests that change the native code run the same build without publishing.

## Possible Problem

**SysCap Verification Failed**: Please try to match the API version of the device and the app. The current device does not contain the following SysCap attributes in the rpcid.json file: XXX. Make sure the device supports all the SysCap attributes required for running the app.  

**Solution**  
Method 1: Update the device system version.  
Method 2: Create a syscap.json file in the src/main directory of the HAP module and remove the unsupported SysCap indicated in the error message.
The following uses SystemCapability.Security.DeviceAuth as an example:

```bash
// entry/src/main/syscap.json
{
  "devices": {
    "general": ["phone"]  // Same as deviceTypes in module.json5
  },
  "production": {
    "removedSysCaps": [
      "SystemCapability.Security.DeviceAuth"
    ]
  }
}
```

Reference [link](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-debug-errorcode-00401#section1453383454618)

## License

VLC for OpenHarmony is licensed under the same terms as the core VLC project: **GPL-2.0-or-later** for the application and **LGPL-2.1-or-later** for `libVLC` and its plugins.

