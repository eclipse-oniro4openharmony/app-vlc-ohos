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

2.  **Configure Environment**:
    Edit `scripts/build_ohos.sh` and set `OHOS_SDK_ROOT` to your local SDK path.

3.  **Build libVLC and Dependencies**:
    The build is orchestrated via shell scripts to handle the complex VLC contrib system:
    ```bash
    # Cross-compile third-party libraries (FFmpeg, libass, etc.)
    bash scripts/build_ohos.sh
    # Compile libVLC core and plugins
    bash scripts/build_libvlc_ohos.sh
    ```

4.  **Build the HAP Application**:
    Open the project in DevEco Studio or use the command line:
    ```bash
    hvigorw assembleHap
    ```

5.  **Run on Device**:
    Use the provided utility script to bundle libraries and deploy:
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
- [ ] **Phase 6**: Hardware-accelerated decoding via `OH_AVCodec` (Planned).
- [ ] **Phase 10**: Subtitle rendering, PiP mode, and Media Session integration.

See the [Implementation Plan](docs/vlc_ohos_implementation_plan.md) for a detailed breakdown.

## License

VLC for OpenHarmony is licensed under the same terms as the core VLC project: **GPL-2.0-or-later** for the application and **LGPL-2.1-or-later** for `libVLC` and its plugins.

