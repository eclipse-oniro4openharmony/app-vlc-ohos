# **Technical Blueprint for Porting VLC Media Player to OpenHarmony and HarmonyOS Next**

## **Executive Summary and Strategic Context**

The transition from the Android Open Source Project (AOSP) ecosystem to the fully native HarmonyOS NEXT architecture represents a monumental shift in mobile and embedded operating system paradigms. With Huawei deprecating the Android compatibility layer, over 800 million active devices are migrating to a purely native ecosystem.1 HarmonyOS NEXT requires applications to be built using ArkTS for application logic and the Native Development Kit (NDK) for system-level operations, completely discarding traditional Android frameworks like the Java Native Interface (JNI), Android SDK components, and Dalvik/ART virtual machine dependencies.1

For foundational multimedia software like VLC media player, this OS migration necessitates a comprehensive architectural overhaul. VLC is globally recognized for its unparalleled format support and aggressively modular design.3 The core engine, libVLC, dynamically constructs a graph of modules at runtime to handle specific input protocols, codecs, and video/audio output mechanisms.3 Porting this engine to HarmonyOS NEXT involves translating the build system to OpenHarmony's CMake environment, replacing JNI bindings with Node-API (NAPI), re-engineering hardware-accelerated decoding pipelines to utilize OH\_AVCodec, and rewriting the video and audio output modules (vout and aout) to interface with XComponent and OHAudio, respectively.2

This technical report provides an exhaustive, low-level architectural blueprint for migrating the VLC codebase to OpenHarmony and HarmonyOS NEXT. It dissects every required subsystem transition, from cross-compiling the complex third-party contrib tree to ensuring zero-copy memory management within the ArkTS/Native boundary.

## **Architectural Alignment: libVLC and the HarmonyOS NDK**

The fundamental integrity of the VLC architecture relies on its modularity. The VLC 4.0 architecture comprises over 380 distinct modules categorized into decoders, demuxers, access modules, audio filters, and video outputs.3 In the existing vlc-android port, the Android application layer communicates with the C-based libVLC engine via JNI.9 The native C/C++ code handles the computationally expensive tasks of parsing bitstreams and negotiating with the hardware layer.10

HarmonyOS NEXT maintains a similar separation of concerns but alters the underlying technologies. The primary application language is ArkTS, a strictly typed extension of TypeScript.11 The bridge to native C/C++ code is facilitated by Node-API (NAPI), which provides an Application Binary Interface (ABI) stable layer derived from Node.js.2 The OpenHarmony NDK exposes a comprehensive suite of POSIX-compliant C APIs, including a standard C runtime (libc) based on musl, a C++ standard library (libc++\_shared), and low-level multimedia frameworks.2

The transition matrix below illustrates the required systemic shifts between the Android and OpenHarmony target environments.

| Subsystem Domain | Android Implementation | HarmonyOS NEXT Target | Architectural Implication |
| :---- | :---- | :---- | :---- |
| **Primary Framework** | Java / Kotlin (Dalvik/ART) | ArkTS (Ark Compiler) | Strict typing; distinct memory management lifecycles. |
| **Native Bridge** | JNI (Java Native Interface) | Node-API (NAPI) | Transition from JNI Env pointers to NAPI contexts and object wrapping. |
| **Build System** | Gradle \+ ndk-build / CMake | Hvigor \+ CMake | Realignment of toolchains to use ohos.toolchain.cmake. |
| **Video Rendering** | SurfaceView / ANativeWindow | XComponent / OHNativeWindow | Adoption of ArkUI declarative syntax mapped to native C++ surfaces. |
| **Audio Rendering** | AudioTrack / OpenSL ES | OHAudio (AudioRenderer) | Shift from OpenSL ES global engine to modern builder-pattern APIs. |
| **Hardware Codecs** | MediaCodec (OMX/Stagefright) | OH\_AVCodec | Migration from Java-centric buffer passing to purely native C async callbacks. |
| **Memory Pages** | 4 KB (Historically) | 16 KB Enforced | Stricter memory alignment for ELF binaries and shared objects. |

Because the OpenHarmony NDK provides robust standard library support, the vast majority of VLC's purely computational modules—such as software demuxers (e.g., MKV, MP4 parsers), packetizers, and software decoders—can be directly cross-compiled for the arm64-v8a architecture with minimal alterations to the core C code.13 The engineering effort must therefore be concentrated on the I/O boundaries: the build system, the NAPI bindings, and the hardware abstraction layers.

## **Build System Overhaul and Toolchain Integration**

The VLC build system is historically complex, heavily utilizing GNU Autotools (autoconf, automake, m4 macros) to configure its vast array of internal modules and external dependencies.3 While recent Google Summer of Code projects have successfully ported portions of libvlc and libvlccore to the Meson build system, cross-platform deployments still largely rely on highly customized shell scripts to orchestrate the build graph.14

### **Cross-Compiling the Contrib System**

A critical aspect of compiling VLC is its contrib system, which manages the compilation of third-party libraries (e.g., FFmpeg, libmad, libplacebo) required by VLC's plugins.4 In the Android port, a script (compile.sh) orchestrates the Android NDK to build these dependencies.16 For HarmonyOS NEXT, this orchestration must be completely rewritten to utilize the OpenHarmony NDK.13

OpenHarmony mandates CMake as the primary build system for native development.2 The SDK provides a specific toolchain file, ohos.toolchain.cmake, located in the build directory, which configures the LLVM/Clang compiler to target the OpenHarmony ABI.13 To compile the VLC contribs, the Autotools environments of the third-party libraries must be instrumented to recognize this toolchain. This involves overriding standard environment variables prior to executing ./configure scripts.

The sysroot parameter is paramount; it must point to the sysroot directory within the OpenHarmony SDK ($(SDK\_ROOT)/native/sysroot), which contains the essential headers and dynamic libraries for the target OS.13 Furthermore, variables such as CC, CXX, AR, NM, and RANLIB must explicitly point to the Clang binaries within the OpenHarmony NDK (/path/to/OpenHarmony/Sdk/native/llvm/bin/clang).17 The compiler flags must specify the target architecture, typically utilizing \--target=aarch64-linux-ohos to ensure compatibility with 64-bit HarmonyOS devices.17

### **FFmpeg Integration and Configuration**

FFmpeg is the most vital external dependency for VLC, acting as the primary demuxer and fallback software decoder.18 Cross-compiling FFmpeg for OpenHarmony requires precise configuration flags. The compilation process assumes a Linux host environment (e.g., Ubuntu).18

The FFmpeg configure script must be executed with parameters adapted for the OpenHarmony environment. While a pre-compiled .har (Harmony Archive) library exists in third-party repositories (e.g., io.openharmony.tpc.thirdlib:FFmpeg:1.0.1), relying on a pre-compiled binary restricts VLC's ability to prune or customize FFmpeg features to reduce the final APK/HAP size.21 Therefore, compiling FFmpeg from source using the OpenHarmony NDK is the optimal approach.

The configuration requires enabling cross-compilation (--enable-cross-compile), defining the target OS (--target-os=linux), and pointing the cross-prefix to the OpenHarmony LLVM toolchain.20 Due to the advanced memory security features increasingly enforced by modern operating systems, including Android 15's mandate for 16 KB page sizes, the OpenHarmony toolchain should be configured to align ELF segments to 16 KB boundaries, ensuring the resulting libavcodec.so and libavformat.so libraries load correctly into the HarmonyOS kernel memory space.22

## **The Framework Bridge: Replacing JNI with Node-API (NAPI)**

The existing vlc-android repository heavily relies on the Java Native Interface (JNI) to bridge the JVM with the native C codebase.9 Files such as libvlcjni.c and libvlcjni-vlcobject.h manage thread attachment, method mapping, and the lifecycle of C pointers stored within Java objects.23 Transitioning to HarmonyOS NEXT requires the complete eradication of JNI in favor of Node-API (NAPI).2

Node-API is an ABI-stable interface derived from Node.js, designed to insulate native addons from changes in the underlying JavaScript/ArkTS engine.12 In OpenHarmony, the inclusion of \<napi/native\_api.h\> and the linking of libace\_napi.z.so enable C++ code to seamlessly interact with ArkTS objects.12

### **Complex Object Wrapping and Memory Lifecycles**

The core challenge in the NAPI transition is exposing complex C structures, specifically libvlc\_instance\_t and libvlc\_media\_player\_t, to the ArkTS runtime. In NAPI, this is accomplished through "object wrapping".24 The napi\_wrap function binds a native C++ instance to an ArkTS JavaScript object, allowing the ArkTS runtime to hold a reference to the native memory.26

Crucially, memory management differs drastically from JNI. When the ArkTS garbage collector determines that the wrapped JavaScript object is no longer in use, it triggers a finalizer callback defined during the napi\_wrap invocation.26 This C++ destructor function must execute the corresponding libvlc\_release calls to free the native resources.26 To interact with the media player from ArkTS UI events (e.g., pressing a play button), the C++ layer uses napi\_unwrap to retrieve the libvlc\_media\_player\_t pointer from the incoming ArkTS object reference, enabling it to call the underlying libVLC API.26

The sheer size of the libVLC API surface makes manual NAPI binding highly inefficient. To mitigate the risk of introducing memory leaks or type mismatch errors, the development team should employ tools like SWIG (Simplified Wrapper and Interface Generator).27 SWIG can parse the C header files of libVLC and automatically generate the hundreds of thousands of lines of boilerplate Node-API wrapping code required to expose the library fully.27 This approach, proven successful in porting massive C++ libraries like ImageMagick to Node.js environments, drastically accelerates the HarmonyOS porting timeline.27

| NAPI Function | Purpose in VLC Integration | Lifecycle Implication |
| :---- | :---- | :---- |
| napi\_wrap | Binds libvlc\_media\_player\_t to an ArkTS object. | Establishes memory ownership link. |
| napi\_unwrap | Retrieves native C++ object for method execution. | Validates object existence before C execution. |
| napi\_create\_reference | Prevents garbage collection of active callbacks. | Maintains persistent connection to ArkTS layer. |
| napi\_threadsafe\_function | Safely dispatches background VLC events to ArkTS. | Resolves single-thread execution limits of NAPI. |

### **Thread Safety and Asynchronous Callbacks**

VLC is intrinsically multi-threaded. Demuxing, decoding, and rendering pipelines all execute on dedicated background threads spawned internally by the libVLC engine.23 When playback events occur—such as buffering progress, stream state changes, or end-of-file notifications—the native layer must notify the UI.23

However, the ArkTS runtime environment is fundamentally single-threaded per worker context. Invoking standard napi\_ functions directly from a background VLC thread will result in immediate fatal runtime violations.12 The NAPI implementation must therefore utilize napi\_create\_threadsafe\_function. This construct allows the background VLC threads to safely queue event payloads into the main ArkTS event loop.12 The system then safely context-switches and invokes the corresponding ArkTS callback function, ensuring thread-safe UI updates. High-frequency event generation, such as time-update callbacks, requires meticulous management of the NAPI handle scope (napi\_handle\_scope) to prevent memory exhaustion resulting from the ArkTS garbage collector failing to keep pace with object creation in tight loops.28

## **Hardware-Accelerated Decoding: Transitioning to OH\_AVCodec**

Software decoding of modern, high-bitrate video formats (such as 4K HDR HEVC) is computationally prohibitive, leading to unacceptable battery drain and thermal throttling.29 VLC relies on operating system APIs for hardware acceleration. In the Android ecosystem, this is handled by the mediacodec module, which wraps the Android MediaCodec API (interacting heavily with OMX IL and Stagefright).29 The historical instability and fragmentation of Android's hardware decoding layer across different OEM implementations necessitated complex fallback logic within VLC.29

For HarmonyOS NEXT, the hardware decoding pipeline must be entirely re-engineered to utilize OpenHarmony’s native multimedia codec API, OH\_AVCodec.6 This C-based API interacts directly with the system's hardware abstraction layers, bypassing the JVM/ArkTS runtime entirely for maximum efficiency.6

### **The OH\_AVCodec Video Pipeline**

The integration of OH\_AVCodec into a new VLC decoder plugin follows a highly asynchronous, callback-driven architecture.6 The operational flow requires strict adherence to the OpenHarmony state machine:

1. **Capability Querying:** Upon receiving a stream, VLC must interrogate the OS to determine if hardware acceleration is viable. By invoking OH\_AVCodec\_GetCapability (e.g., querying for OH\_AVCODEC\_MIMETYPE\_VIDEO\_AVC for H.264 or OH\_AVCODEC\_MIMETYPE\_VIDEO\_HEVC for H.265), VLC ascertains supported profiles and levels.32 To guarantee hardware execution and avoid overlapping software fallbacks, OH\_AVCodec\_GetCapabilityByCategory can be executed with the HARDWARE constant.34  
2. **Decoder Instantiation and Configuration:** The decoder instance is instantiated using OH\_VideoDecoder\_CreateByName.34 It is then configured using an OH\_AVFormat key-value dictionary, translating VLC's parsed resolution, frame rate, and color space metrics into the OH\_AVCodec standard definitions.6  
3. **Asynchronous Callbacks:** The OH\_AVCodec architecture mandates non-blocking data flow. VLC must register callback functions via OH\_VideoDecoder\_RegisterCallback.6 The most critical of these are OnNeedInputData and OnNewOutputData.35  
4. **Buffer Management and Zero-Copy Rendering:**  
   * When the hardware is ready for more data, OnNeedInputData is triggered, providing VLC with a buffer index. VLC extracts the compressed bitstream (e.g., Annex B NAL units), utilizes OH\_AVMemory\_GetAddr to map the shared memory space, copies the payload, and submits it back to the hardware via OH\_VideoDecoder\_PushInputData.35  
   * Once a frame is decoded, OnNewOutputData is invoked. If the decoder was configured in surface mode (linked to an OHNativeWindow), VLC does not need to read the raw pixel data back to CPU memory. Instead, invoking OH\_VideoDecoder\_RenderOutputData (or equivalent freeing routines) commands the hardware compositor to draw the frame directly to the display, achieving a zero-copy rendering pipeline.19

### **Audio Decoding Optimization**

While VLC traditionally defaults to software decoding for audio streams (using FFmpeg, libmad, or libfaad) due to relatively low CPU overhead, power-constrained mobile environments benefit from offloading all possible tasks to dedicated silicon. OpenHarmony provides OH\_AudioCodec for hardware-accelerated audio decoding, natively supporting formats like AAC, FLAC, Vorbis, MP3, and G711mu.6

A complementary VLC audio decoder module can be developed utilizing the exact same architectural pattern as the video decoder.6 The instance is created using OH\_AudioCodec\_CreateByMime, configured, and fed compressed packets.33 The decoded PCM streams are then retrieved and forwarded to the audio output module.36 During playback, if the stream parameters change dynamically, OH\_AudioCodec\_GetOutputDescription allows VLC to re-negotiate the audio output parameters on the fly.6

## **Video Output (vout) Implementation: XComponent and NativeWindow**

The Video Output (vout) module is the final stage of the visual pipeline, responsible for rendering decoded frames to the display. In the Android port, this module interfaces with Java-based SurfaceView or TextureView elements, acquiring an ANativeWindow for C++ level drawing.5 HarmonyOS NEXT replaces these elements with the XComponent framework, specifically designed for high-performance C++ integration.5

### **XComponent Lifecycle and Native Integration**

The XComponent is an ArkUI declarative component that acts as a placeholder for native rendering.5 To construct the HarmonyOS vout module for VLC, developers must coordinate the ArkTS UI layer with the C++ rendering logic.5

In the ArkTS .ets file, the XComponent is declared with a specific type parameter, usually set to 'texture' or 'surface'.5 The 'texture' type is highly recommended for complex media players like VLC, as it supports transparency, rotation, and complex Z-ordering with other UI elements (like playback controls), whereas 'surface' provides a rigid, isolated composition layer optimized solely for raw throughput.5 The libraryname parameter within the ArkTS declaration maps the component directly to the compiled VLC shared object (e.g., libvlcnative.so).5

Upon initialization, the native C++ layer must unwrap the NativeXComponent from the JavaScript environment and register lifecycle hooks via OH\_NativeXComponent\_RegisterCallback.5 When the ArkTS engine successfully prepares the display surface, it triggers the OnSurfaceCreatedCB callback, passing a raw void\* window handle. This pointer is strictly cast to an OHNativeWindow\*, which VLC caches within its internal display structure (typically sys-\>display analogous to other VLC vout modules).5

### **EGL Context Generation and Scaling Mechanics**

VLC requires robust hardware scaling and color conversion. By utilizing the obtained OHNativeWindow\*, VLC can establish a standard EGL surface.41 Passing the window instance to eglCreateWindowSurface integrates the VLC rendering pipeline directly into OpenHarmony's GPU compositor.41 This enables VLC's existing OpenGL/GLES shaders to execute natively, handling complex tasks like HDR-to-SDR tonemapping, hardware deinterlacing, and custom aspect ratio enforcement without CPU intervention.10

Furthermore, OpenHarmony provides native window buffer scaling controls that offload resizing calculations from VLC to the system compositor. Through the OH\_NativeWindow\_NativeWindowHandleOpt API, VLC can apply specific scaling constants 5:

| OpenHarmony Scaling Mode | VLC Behavioral Equivalence | Visual Result |
| :---- | :---- | :---- |
| OH\_SCALING\_MODE\_SCALE\_CROP\_V2 | Crop to Fill | Buffer scales to fill window; excess is cropped. |
| OH\_SCALING\_MODE\_SCALE\_FIT\_V2 | Best Fit (Letterbox) | Buffer fully displayed; empty space is padded. |
| OH\_SCALING\_MODE\_SCALE\_TO\_WINDOW\_V2 | Stretch | Aspect ratio ignored; buffer stretches to boundaries. |

By translating user-selected aspect ratios in the VLC UI into these OH\_SCALING\_MODE directives, the vout module guarantees pixel-perfect rendering synchronized with the device's display refresh rate.43 If software-decoded frames must be manually rendered, the vout module requests an OHNativeWindowBuffer, maps it to virtual memory using mmap, writes the raw RGB/YUV pixels, unmaps the memory, and executes OH\_NativeWindow\_NativeWindowFlushBuffer to push the frame to the graphics queue.5 This requires meticulous synchronization, utilizing the returned fenceFd and poll mechanisms to prevent screen tearing or memory corruption.5

## **Audio Output (aout) Implementation: Transitioning to OHAudio**

The Audio Output (aout) module manages the final delivery of PCM audio data to the physical hardware. VLC's Android implementation relied heavily on native OpenSL ES or JNI-wrapped AudioTrack APIs.44 HarmonyOS NEXT deprecates OpenSL ES as the primary audio interface, introducing the OHAudio framework as the modern, native solution.7

### **The Builder Pattern and OHAudio Initialization**

The architectural shift from OpenSL ES to OHAudio requires discarding the global engine interface approach in favor of a granular builder pattern.44 The OpenSL ES code initialized a massive global SLEngineItf object and configured complex sink and source data structures.44 In contrast, the OHAudio API focuses strictly on stream generation.

To implement the new VLC aout module, the initialization sequence utilizes OH\_AudioStreamBuilder\_Create, explicitly requesting the AUDIOSTREAM\_TYPE\_RENDERER mode.7 The builder is subsequently configured to match the audio format negotiated by VLC's internal core.38

The native API exposes functions to set critical parameters:

* OH\_AudioStreamBuilder\_SetSamplingRate: Defines the frequency (e.g., 44100 Hz, 48000 Hz).44  
* OH\_AudioStreamBuilder\_SetChannelCount: Sets mono, stereo, or multi-channel configurations.44  
* OH\_AudioStreamBuilder\_SetSampleFormat: Defines bit depth, typically AUDIOSTREAM\_SAMPLE\_S16LE or AUDIOSTREAM\_SAMPLE\_F32LE.44

A vital addition in the OHAudio framework is the explicit definition of audio usage policies. By calling OH\_AudioStreamBuilder\_SetRendererInfo and passing AUDIOSTREAM\_USAGE\_MUSIC, VLC informs the HarmonyOS kernel of the audio stream's intent.44 This allows the OS to apply appropriate routing, equalization, and volume control logic natively, circumventing the need for VLC to manage device-specific acoustic quirks.44

### **Asynchronous Playback and Interrupt Management**

VLC's historical audio output models often utilized blocking calls, pushing buffers to the hardware in a tight loop. OHAudio enforces an asynchronous, pull-based architecture.7 The VLC aout module must register an onWriteData callback.46 When the hardware audio buffer approaches depletion, the OS fires this callback, providing VLC with a pre-allocated memory address and a requested byte length.46 VLC then extracts the required PCM data from its internal audio FIFO queues, copies it into the provided buffer, and returns execution to the OS.46

Once the builder is fully configured and callbacks attached, OH\_AudioStreamBuilder\_GenerateRenderer constructs the final OH\_AudioRenderer instance.7 Playback lifecycle is managed through explicit state commands: OH\_AudioRenderer\_Start, Pause, Flush, and Stop.7

Crucially, modern media players must react instantly to system-level audio focus changes, such as incoming calls or alarms. The VLC module must utilize OHAudio's interrupt listeners to intercept these events.38 When an interrupt is received, the native C++ layer pauses the stream internally, preventing audio overlap and ensuring a seamless user experience without requiring a round-trip to the ArkTS UI layer.38 Furthermore, track volume adjustments are executed natively via audioRenderer-\>SetVolume(float), maintaining low-latency acoustic response.38

## **Container Demuxing: System Capabilities vs. Custom Parsing**

Demuxing is the process of extracting raw audio and video streams from container files (such as MP4, MKV, or FLV). OpenHarmony provides native demuxing capabilities through the libnative\_media\_avdemuxer.so and libnative\_media\_avsource.so libraries, which support standard formats like MP4, M4A, FLAC, and OGG.47

While adopting the system demuxer reduces the application footprint, VLC's primary competitive advantage is its ubiquitous format support. VLC handles severely damaged files, proprietary network streaming protocols (RTSP, RTMP, HLS, DASH), and obscure legacy formats utilizing its internal demuxer modules and FFmpeg's libavformat.4

To maintain this unparalleled versatility on HarmonyOS NEXT, the architectural recommendation is to bypass the native OpenHarmony demuxer APIs. Instead, VLC should continue relying on its internal, cross-compiled parsing logic. The extracted, raw bitstreams (such as Annex B encoded H.264 data) are then securely passed to the OpenHarmony OH\_AVCodec hardware decoders. This hybrid approach guarantees maximum format compatibility while fully leveraging native hardware acceleration for the most computationally intensive tasks.

## **Packaging, Security, and Final Deployment**

The final phase of the porting effort involves integrating the disparate native components—the libVLC core, the Node-API bindings, the OH\_AVCodec hardware accelerators, and the XComponent/OHAudio rendering modules—into a distributable HarmonyOS application package.

HarmonyOS NEXT utilizes the .hap (Harmony Ability Package) format, entirely distinct from Android's APK.11 The build system, Hvigor, orchestrates the compilation of ArkTS source code (.ets files) and links the NDK-compiled shared objects (.so) located in the src/main/cpp directory.11 To expose the native functions to the ArkTS developers creating the VLC user interface, TypeScript declaration files (index.d.ts) must be meticulously maintained alongside the native modules, ensuring strict compile-time type checking.11

Security constraints in HarmonyOS NEXT are highly rigorous. Applications must adhere to the Stage Model architecture, explicitly declaring all required permissions (such as ohos.permission.INTERNET for network streams and ohos.permission.READ\_MEDIA for local file access) within the module.json5 and oh-package.json5 manifest files.11 The build-profile.json5 configuration dictates the target runtime environment.11

Finally, the operating system enforces mandatory cryptographic signing. The application bundle cannot be sideloaded or executed without a valid cryptographic signature verified by the OS kernel.11 The Hapsigner tool is employed during the final build phase to sign the application; for proprietary HarmonyOS NEXT distributions, DevEco Studio automatically manages the generation and application of these cryptographic keys, facilitating secure distribution to the end user.11

## **Conclusion**

The endeavor to port VLC media player to OpenHarmony and HarmonyOS NEXT is a complex, multi-layered architectural translation. It requires dismantling a deeply entrenched Android dependency stack and reconstructing it atop a purely native, highly rigorous POSIX and ArkTS ecosystem.

Success dictates a total overhaul of the build environment to align the VLC contrib system with the OpenHarmony CMake toolchain, specifically ensuring 16 KB page alignment for ELF binaries. The Java Native Interface (JNI) must be entirely systematically eradicated, replaced by Node-API (NAPI) object wrappers that carefully synchronize native C++ lifecycles with the ArkTS garbage collector while safely dispatching asynchronous playback events to the main thread.

Furthermore, performance parity demands the complete replacement of Android's graphical and audio rendering subsystems. The integration of XComponent combined with OHNativeWindow establishes a zero-copy, EGL-backed rendering pipeline capable of hardware scaling. Similarly, adopting the OHAudio builder pattern replaces legacy OpenSL ES implementations, guaranteeing low-latency, system-integrated acoustic routing. Finally, the strategic adoption of OH\_AVCodec for hardware-accelerated video decoding—while retaining VLC's internal software demuxers—ensures the media player maintains its legendary format versatility while achieving the thermal and battery efficiency required by modern mobile hardware. Through this meticulous re-engineering, VLC will seamlessly integrate into the next generation of native mobile operating systems.

#### **Works cited**

1. The Complete Guide to HarmonyOS NEXT \- AppInChina, accessed February 26, 2026, [https://appinchina.co/the-complete-guide-to-harmonyos-next/](https://appinchina.co/the-complete-guide-to-harmonyos-next/)  
2. NDK Basics \- OpenHarmony/docs, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/master/en/application-dev/napi/ndk-development-overview.md](https://gitee.com/openharmony/docs/blob/master/en/application-dev/napi/ndk-development-overview.md)  
3. VLC media player \- Wikipedia, accessed February 26, 2026, [https://en.wikipedia.org/wiki/VLC\_media\_player](https://en.wikipedia.org/wiki/VLC_media_player)  
4. Steve Lhomme / VLC \- GitLab, accessed February 26, 2026, [https://code.videolan.org/robUx4/vlc](https://code.videolan.org/robUx4/vlc)  
5. OpenHarmony/docs \- Gitee, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/master/en/application-dev/graphics/native-window-guidelines.md](https://gitee.com/openharmony/docs/blob/master/en/application-dev/graphics/native-window-guidelines.md)  
6. native\_avcodec\_audiocodec.h \- OpenHarmony/docs, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/94657d281ba72a901cf9930f1cc68802a7b53274/en/application-dev/reference/apis-avcodec-kit/native\_\_avcodec\_\_audiocodec\_8h.md](https://gitee.com/openharmony/docs/blob/94657d281ba72a901cf9930f1cc68802a7b53274/en/application-dev/reference/apis-avcodec-kit/native__avcodec__audiocodec_8h.md)  
7. Using OHAudio for Audio Playback (C/C++) \- OpenHarmony/docs, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/73f242a3d024f6ee18c48b22242c2aa458ae3839/en/application-dev/media/using-ohaudio-for-playback.md](https://gitee.com/openharmony/docs/blob/73f242a3d024f6ee18c48b22242c2aa458ae3839/en/application-dev/media/using-ohaudio-for-playback.md)  
8. VideoLAN / VLC-Android · GitLab, accessed February 26, 2026, [https://code.videolan.org/videolan/vlc-android/-/tree/libvlc-4.0.0-eap18](https://code.videolan.org/videolan/vlc-android/-/tree/libvlc-4.0.0-eap18)  
9. vlc-android/vlc-android/jni/libvlcjni.c at master · xhochy/vlc-android \- GitHub, accessed February 26, 2026, [https://github.com/xhochy/vlc-android/blob/master/vlc-android/jni/libvlcjni.c](https://github.com/xhochy/vlc-android/blob/master/vlc-android/jni/libvlcjni.c)  
10. VideoLAN / VLC-Android \- GitLab, accessed February 26, 2026, [https://code.videolan.org/videolan/vlc-android](https://code.videolan.org/videolan/vlc-android)  
11. OpenHarmony OS for Next Gen Mobile \- Servo, accessed February 26, 2026, [https://servo.org/files/2024-05-06-openharmony-os-for-next-gen-mobile.pdf](https://servo.org/files/2024-05-06-openharmony-os-for-next-gen-mobile.pdf)  
12. Node-API \- OpenHarmony/docs, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/master/en/application-dev/reference/native-lib/napi.md](https://gitee.com/openharmony/docs/blob/master/en/application-dev/reference/native-lib/napi.md)  
13. 鸿蒙Next实战开发-OpenHarmony的NDK开发 \- CSDN博客, accessed February 26, 2026, [https://blog.csdn.net/m0\_70749039/article/details/139298001](https://blog.csdn.net/m0_70749039/article/details/139298001)  
14. GSoC 2018: Port VLC build system to Meson \- ePirat's Blog, accessed February 26, 2026, [https://epir.at/2018/08/13/gsoc-2018/](https://epir.at/2018/08/13/gsoc-2018/)  
15. doc/BUILD-win32.md · master · VideoLAN / VLC \- GitLab, accessed February 26, 2026, [https://code.videolan.org/videolan/vlc/-/blob/master/doc/BUILD-win32.md?ref\_type=heads](https://code.videolan.org/videolan/vlc/-/blob/master/doc/BUILD-win32.md?ref_type=heads)  
16. Using libVLC for Android on windows platform \- Stack Overflow, accessed February 26, 2026, [https://stackoverflow.com/questions/20493368/using-libvlc-for-android-on-windows-platform](https://stackoverflow.com/questions/20493368/using-libvlc-for-android-on-windows-platform)  
17. Building Qt for OpenHarmony \- Qt Wiki, accessed February 26, 2026, [https://wiki.qt.io/Building\_Qt\_for\_OpenHarmony](https://wiki.qt.io/Building_Qt_for_OpenHarmony)  
18. Building FFmpeg from source for Android on Linux | Qt Multimedia | Qt 6.10.1, accessed February 26, 2026, [https://doc.qt.io/qt-6//qtmultimedia-building-ffmpeg-android-linux.html](https://doc.qt.io/qt-6//qtmultimedia-building-ffmpeg-android-linux.html)  
19. HVD \- Hardware Video Decoder C library \- GitHub, accessed February 26, 2026, [https://github.com/bmegli/hardware-video-decoder](https://github.com/bmegli/hardware-video-decoder)  
20. Android Cross-compiling ffmpeg \- Stack Overflow, accessed February 26, 2026, [https://stackoverflow.com/questions/5966700/android-cross-compiling-ffmpeg](https://stackoverflow.com/questions/5966700/android-cross-compiling-ffmpeg)  
21. HarmonyOS-TPC/FFmpeg \- Gitee, accessed February 26, 2026, [https://gitee.com/HarmonyOS-tpc/FFmpeg](https://gitee.com/HarmonyOS-tpc/FFmpeg)  
22. Seeking guidance on VLC Android and 16KB memory page size support : r/androiddev \- Reddit, accessed February 26, 2026, [https://www.reddit.com/r/androiddev/comments/1mbbh8q/seeking\_guidance\_on\_vlc\_android\_and\_16kb\_memory/](https://www.reddit.com/r/androiddev/comments/1mbbh8q/seeking_guidance_on_vlc_android_and_16kb_memory/)  
23. libvlc/jni/libvlcjni.c · 94d3c15122d54b4ab29e0d6a7ca530ab9bd7a148 · VideoLAN / VLC-Android, accessed February 26, 2026, [https://code.videolan.org/videolan/vlc-android/blob/94d3c15122d54b4ab29e0d6a7ca530ab9bd7a148/libvlc/jni/libvlcjni.c](https://code.videolan.org/videolan/vlc-android/blob/94d3c15122d54b4ab29e0d6a7ca530ab9bd7a148/libvlc/jni/libvlcjni.c)  
24. Object wrap · The Node-API Resource \- GitHub Pages, accessed February 26, 2026, [https://nodejs.github.io/node-addon-examples/getting-started/objectwrap/](https://nodejs.github.io/node-addon-examples/getting-started/objectwrap/)  
25. node-addon-api/doc/object\_wrap.md at main \- GitHub, accessed February 26, 2026, [https://github.com/nodejs/node-addon-api/blob/main/doc/object\_wrap.md](https://github.com/nodejs/node-addon-api/blob/main/doc/object_wrap.md)  
26. Introduction to Node-API & Wrapping Native C++ Objects in ArkTS on HarmonyOSNext \- HUAWEI Developer Forum, accessed February 26, 2026, [https://forums.developer.huawei.com/forumPortal/en/topic/0203190036169712060](https://forums.developer.huawei.com/forumPortal/en/topic/0203190036169712060)  
27. Effortlessly porting a major C++ library to Node.js with SWIG Node-API \- Momtchil Momtchev, accessed February 26, 2026, [https://mmomtchev.medium.com/effortlessly-porting-a-major-c-library-to-node-js-with-swig-napi-3c1a5c4a233f](https://mmomtchev.medium.com/effortlessly-porting-a-major-c-library-to-node-js-with-swig-napi-3c1a5c4a233f)  
28. Napi::ObjectWrap has significant memory bloat · Issue \#526 · nodejs/node-addon-api, accessed February 26, 2026, [https://github.com/nodejs/node-addon-api/issues/526](https://github.com/nodejs/node-addon-api/issues/526)  
29. Hardware-acceleration of video decoding on Android is really a mess... In additi... | Hacker News, accessed February 26, 2026, [https://news.ycombinator.com/item?id=7608997](https://news.ycombinator.com/item?id=7608997)  
30. Jerky H264 rendering on RK decoder \- how to change hw decoder settings \- comparison with VLC-Android · Issue \#2090 · androidx/media \- GitHub, accessed February 26, 2026, [https://github.com/androidx/media/issues/2090](https://github.com/androidx/media/issues/2090)  
31. Developing H264 hardware decoder Android \- Stagefright or OpenMax IL? \- Stack Overflow, accessed February 26, 2026, [https://stackoverflow.com/questions/32427289/developing-h264-hardware-decoder-android-stagefright-or-openmax-il](https://stackoverflow.com/questions/32427289/developing-h264-hardware-decoder-android-stagefright-or-openmax-il)  
32. Video Encoding \- OpenHarmony/docs \- Gitee, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/39467f023bec8cfca8ec2f97b99039b1dbd141e5/en/application-dev/media/avcodec/video-encoding.md](https://gitee.com/openharmony/docs/blob/39467f023bec8cfca8ec2f97b99039b1dbd141e5/en/application-dev/media/avcodec/video-encoding.md)  
33. en/application-dev/media/avcodec/audio-decoding.md · OpenHarmony/docs \- Gitee.com, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/94657d281ba72a901cf9930f1cc68802a7b53274/en/application-dev/media/avcodec/audio-decoding.md?skip\_mobile=true](https://gitee.com/openharmony/docs/blob/94657d281ba72a901cf9930f1cc68802a7b53274/en/application-dev/media/avcodec/audio-decoding.md?skip_mobile=true)  
34. Video Decoding \- Huawei Developer Official Website\_Innovation Starts Here, accessed February 26, 2026, [https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/video-decoding-V5](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/video-decoding-V5)  
35. harmony 鸿蒙Video Encoding \- seaxiang, accessed February 26, 2026, [https://www.seaxiang.com/blog/62a241fa198d4b5e8206445c7cb30ed7](https://www.seaxiang.com/blog/62a241fa198d4b5e8206445c7cb30ed7)  
36. en/application-dev/media/avcodec/audio-decoding.md · OpenHarmony/docs \- Gitee.com, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/11de65f7c5cef042ad815f42a174f1bba02be3da/en/application-dev/media/avcodec/audio-decoding.md?skip\_mobile=true](https://gitee.com/openharmony/docs/blob/11de65f7c5cef042ad815f42a174f1bba02be3da/en/application-dev/media/avcodec/audio-decoding.md?skip_mobile=true)  
37. harmony 鸿蒙Audio Encoding \- seaxiang, accessed February 26, 2026, [https://www.seaxiang.com/blog/df0e26029aca4edda1f80f8ea5aba8e9](https://www.seaxiang.com/blog/df0e26029aca4edda1f80f8ea5aba8e9)  
38. openharmony/multimedia\_audio\_standard: Audio management implementation | 音频管理功能实现 \- GitHub, accessed February 26, 2026, [https://github.com/openharmony/multimedia\_audio\_standard](https://github.com/openharmony/multimedia_audio_standard)  
39. modules/video\_output · 31e1756c9117f8cbac5361a36d69383015baf3d2 · VideoLAN / VLC \- GitLab, accessed February 26, 2026, [https://code.videolan.org/videolan/vlc/-/tree/31e1756c9117f8cbac5361a36d69383015baf3d2/modules/video\_output](https://code.videolan.org/videolan/vlc/-/tree/31e1756c9117f8cbac5361a36d69383015baf3d2/modules/video_output)  
40. src/video\_output/video\_output.c · 152883b6980fb7f6369c16a69e2bc1d65a7e120a · VideoLAN / VLC, accessed February 26, 2026, [https://code.videolan.org/videolan/vlc/-/blob/152883b6980fb7f6369c16a69e2bc1d65a7e120a/src/video\_output/video\_output.c](https://code.videolan.org/videolan/vlc/-/blob/152883b6980fb7f6369c16a69e2bc1d65a7e120a/src/video_output/video_output.c)  
41. Custom Rendering (XComponent) \- OpenHarmony/docs, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/master/en/application-dev/ui/napi-xcomponent-guidelines.md](https://gitee.com/openharmony/docs/blob/master/en/application-dev/ui/napi-xcomponent-guidelines.md)  
42. OpenGL vout helper calls msg\_ with NULL object (\#17795) · Issue · videolan/vlc \- GitLab, accessed February 26, 2026, [https://code.videolan.org/videolan/vlc/-/work\_items/17795](https://code.videolan.org/videolan/vlc/-/work_items/17795)  
43. NativeWindow \- OpenHarmony/docs, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/43726785b4033887cd1a838aaaca5e255897a71e/en/application-dev/reference/apis-arkgraphics2d/\_native\_window.md](https://gitee.com/openharmony/docs/blob/43726785b4033887cd1a838aaaca5e255897a71e/en/application-dev/reference/apis-arkgraphics2d/_native_window.md)  
44. harmony 鸿蒙Switching from OpenSL ES to OHAudio (C/C++) \- seaxiang, accessed February 26, 2026, [https://www.seaxiang.com/blog/ltdM6K](https://www.seaxiang.com/blog/ltdM6K)  
45. openharmony \- seaxiang, accessed February 26, 2026, [https://www.seaxiang.com/blog/bk-blog-7](https://www.seaxiang.com/blog/bk-blog-7)  
46. Using AudioRenderer for Audio Playback \- OpenHarmony/docs \- Gitee, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/f013f0d3312a247aac9c4eb1e6f29d636eafbeed/en/application-dev/media/audio/using-audiorenderer-for-playback.md](https://gitee.com/openharmony/docs/blob/f013f0d3312a247aac9c4eb1e6f29d636eafbeed/en/application-dev/media/audio/using-audiorenderer-for-playback.md)  
47. Audio and Video Demuxing \- OpenHarmony/docs \- Gitee, accessed February 26, 2026, [https://gitee.com/openharmony/docs/blob/ac028985bc5cc01527e31478995d1748bcde7432/en/application-dev/media/avcodec/audio-video-demuxer.md](https://gitee.com/openharmony/docs/blob/ac028985bc5cc01527e31478995d1748bcde7432/en/application-dev/media/avcodec/audio-video-demuxer.md)