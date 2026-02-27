# VLC for OpenHarmony: NAPI Binding Layer Architecture

This document provides a comprehensive overview of the **NAPI (Node-API)** binding layer used in the VLC port to OpenHarmony. It explains the transition from the Android JNI model to the HarmonyOS NEXT native bridge and dissects the communication patterns between ArkTS and C++.

---

## 1. Conceptual Overview: JNI vs. Node-API

In the Android port of VLC, the architecture relies on **JNI (Java Native Interface)**. In HarmonyOS NEXT, JNI is replaced by **Node-API (NAPI)**.

| Feature | JNI (Android) | Node-API (OpenHarmony) |
| :--- | :--- | :--- |
| **Runtime** | JVM / ART (Dalvik) | ArkTS / Ark Compiler (JS-based) |
| **Pointer Storage** | Native pointers are stored as `long` fields in Java objects. | Native pointers are "wrapped" directly into JS objects. |
| **Call Overhead** | Significant (JNI transition costs). | Lower (Direct ABI-stable C interface). |
| **GC Integration** | Manual cleanup (`release()` calls) or `Finalizer` (deprecated). | Native Finalizers are called automatically by the GC. |
| **Threading** | `DetachCurrentThread` / `AttachCurrentThread`. | `napi_threadsafe_function` for async callbacks. |

---

## 2. Object Wrapping: The Core Link

The most critical part of the NAPI layer is **Object Wrapping**. This is how a `libvlc_instance_t*` or `libvlc_media_player_t*` is exposed to ArkTS.

### How it works:
1. **Creation**: When you call `vlcNew()` from ArkTS, the C++ layer creates a native `libvlc_instance_t`.
2. **Object Creation**: C++ creates an empty ArkTS object using `napi_create_object`.
3. **Binding**: C++ uses `napi_wrap` to "glue" the native pointer to that ArkTS object.
4. **Finalization**: A C++ **Finalizer** function is attached. If the ArkTS garbage collector (GC) destroys the JS object, the finalizer automatically calls `libvlc_release`.

### Example (from `vlc_instance_wrap.cpp`):
```cpp
// 1. Create native instance
libvlc_instance_t* instance = libvlc_new(argc, argv);

// 2. Create JS Wrapper Object
napi_value obj;
napi_create_object(env, &obj);

// 3. Wrap & Attach Finalizer
napi_wrap(env, 
          obj,               // JS Object
          instance,          // Native Pointer
          VlcInstanceFinalizer, // Callback to libvlc_release
          nullptr, 
          nullptr);

return obj; // ArkTS receives this as an opaque object
```

---

## 3. Communication Flow (ArkTS ↔ C++)

### From ArkTS to C++ (Synchronous)
When ArkTS calls a method like `mediaPlayerPlay(player)`, the following happens:
1. **Context Passing**: NAPI passes the `napi_env` (the JS context) and `napi_callback_info` (arguments) to C++.
2. **Unwrapping**: C++ uses `napi_unwrap` to retrieve the hidden native `libvlc_media_player_t*` from the JS object.
3. **Execution**: C++ calls the actual libVLC C function.
4. **Return**: C++ converts the result (e.g., an int or boolean) back into a `napi_value` for ArkTS.

### From C++ to ArkTS (Asynchronous / Events)
VLC is multi-threaded. Events like `TimeChanged` or `EndReached` occur on internal VLC threads. **ArkTS cannot be called directly from these threads.**

**The solution is `napi_threadsafe_function`:**
1. **Initialization**: When attaching an event, C++ creates a `threadsafe_function`.
2. **Triggering**: The VLC background thread calls `napi_call_threadsafe_function`.
3. **Execution**: NAPI queues this event. Once the ArkTS main thread is idle, it executes a C++ wrapper that finally invokes the ArkTS callback.

---

## 4. Lifecycle Management

Lifecycle management is "Safe and Hybrid":
- **GC Management**: If you lose all references to a `VlcInstance` in ArkTS, the GC will eventually free it via the NAPI finalizer.
- **Explicit Release**: For deterministic behavior, the binding provides `vlcRelease()`. This uses `napi_remove_wrap` to immediately retrieve the pointer and free it, preventing the finalizer from running later (avoiding double-free).

---

## 5. Mapping the API Surface

The NAPI layer is divided into logical modules matching the VLC core structure:

1. **`vlc_napi.h`**: Central header defining the bridge signatures.
2. **`vlc_instance_wrap.cpp`**: Global VLC context and initialization.
3. **`vlc_media_wrap.cpp`**: Source management (Paths, URLs).
4. **`vlc_mediaplayer_wrap.cpp`**: Playback controls (Play/Pause/Seek).
5. **`vlc_events.cpp`**: The bridge for high-frequency playback events.

---

## 6. TypeScript Integration

To provide a premium developer experience in DevEco Studio, we use `.d.ts` files to describe the native layer:

```typescript
// index.d.ts
export interface VlcInstance {} // Opaque type

/**
 * Creates a new VLC instance.
 * @param args Command line arguments (e.g., ["--verbose=2"])
 */
export function vlcNew(args: string[]): VlcInstance;

/**
 * Explicitly releases the VLC instance.
 */
export function vlcRelease(instance: VlcInstance): void;
```

This ensures ArkTS developers get full IntelliSense and compile-time checking, even though the underlying logic is C++.
