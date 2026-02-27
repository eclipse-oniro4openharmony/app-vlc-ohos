#include "vlc_napi.h"
#include <vlc/vlc.h>
#include <string>
#include <mutex>
#include <unordered_map>
#include <native_window/external_window.h>

static std::mutex g_windowRegistryMutex;
static std::unordered_map<libvlc_media_player_t*, OHNativeWindow*> g_windowRegistry;

extern "C" __attribute__((visibility("default"))) OHNativeWindow* GetOHNativeWindowForPlayer(libvlc_media_player_t* player) {
    std::lock_guard<std::mutex> lock(g_windowRegistryMutex);
    auto it = g_windowRegistry.find(player);
    if (it != g_windowRegistry.end()) {
        return it->second;
    }
    return nullptr;
}

static void MediaPlayerFinalizer(napi_env env, void* finalize_data, void* finalize_hint) {
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(finalize_data);
    if (player != nullptr) {
        MediaPlayerDetachAllEvents(player);
        libvlc_media_player_release(player);

        std::lock_guard<std::mutex> lock(g_windowRegistryMutex);
        auto it = g_windowRegistry.find(player);
        if (it != g_windowRegistry.end()) {
            if (it->second != nullptr) {
                OH_NativeWindow_DestroyNativeWindow(it->second);
            }
            g_windowRegistry.erase(it);
        }
    }
}

napi_value MediaPlayerNew(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcInstance wrapper)");
        return nullptr;
    }

    void* instance_ptr = nullptr;
    status = napi_unwrap(env, args[0], &instance_ptr);
    if (status != napi_ok || instance_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcInstance argument");
        return nullptr;
    }
    libvlc_instance_t* instance = static_cast<libvlc_instance_t*>(instance_ptr);

    libvlc_media_player_t* player = libvlc_media_player_new(instance);
    if (!player) {
        napi_throw_error(env, nullptr, "Failed to create libvlc_media_player_t");
        return nullptr;
    }

    napi_value obj;
    napi_create_object(env, &obj);
    
    status = napi_wrap(env, obj, player, MediaPlayerFinalizer, nullptr, nullptr);
    if (status != napi_ok) {
        libvlc_media_player_release(player);
        napi_throw_error(env, nullptr, "Failed to wrap libvlc_media_player_t");
        return nullptr;
    }

    return obj;
}

napi_value MediaPlayerSetMedia(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 2 || args[0] == nullptr || args[1] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 2 arguments (VlcMediaPlayer, VlcMedia)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    void* media_ptr = nullptr;
    status = napi_unwrap(env, args[1], &media_ptr);
    if (status != napi_ok || media_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMedia argument");
        return nullptr;
    }
    libvlc_media_t* media = static_cast<libvlc_media_t*>(media_ptr);

    libvlc_media_player_set_media(player, media);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value MediaPlayerPlay(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcMediaPlayer)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    libvlc_media_player_play(player);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value MediaPlayerPause(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcMediaPlayer)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    libvlc_media_player_pause(player);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value MediaPlayerStop(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcMediaPlayer)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    libvlc_media_player_stop(player);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value MediaPlayerGetTime(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcMediaPlayer)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    libvlc_time_t time = libvlc_media_player_get_time(player);

    napi_value result;
    napi_create_int64(env, time, &result);
    return result;
}

napi_value MediaPlayerSetTime(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 2 || args[0] == nullptr || args[1] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 2 arguments (VlcMediaPlayer, time)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    int64_t time = 0;
    status = napi_get_value_int64(env, args[1], &time);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid time argument (must be integer)");
        return nullptr;
    }

    libvlc_media_player_set_time(player, static_cast<libvlc_time_t>(time));

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value MediaPlayerGetLength(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcMediaPlayer)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    libvlc_time_t length = libvlc_media_player_get_length(player);

    napi_value result;
    napi_create_int64(env, length, &result);
    return result;
}

napi_value MediaPlayerGetPosition(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcMediaPlayer)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    float position = libvlc_media_player_get_position(player);

    napi_value result;
    napi_create_double(env, static_cast<double>(position), &result);
    return result;
}

napi_value MediaPlayerSetPosition(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 2 || args[0] == nullptr || args[1] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 2 arguments (VlcMediaPlayer, position)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    double position = 0.0;
    status = napi_get_value_double(env, args[1], &position);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid position argument (must be number)");
        return nullptr;
    }

    libvlc_media_player_set_position(player, static_cast<float>(position));

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value MediaPlayerSetNativeWindow(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 2 || args[0] == nullptr || args[1] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 2 arguments (VlcMediaPlayer, surfaceId)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    char surfaceIdStr[256] = {0};
    size_t result_len = 0;
    status = napi_get_value_string_utf8(env, args[1], surfaceIdStr, sizeof(surfaceIdStr) - 1, &result_len);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid surfaceId argument (must be string)");
        return nullptr;
    }

    std::string surfaceId(surfaceIdStr, result_len);

    std::lock_guard<std::mutex> lock(g_windowRegistryMutex);
    
    // Release previous if exists
    auto it = g_windowRegistry.find(player);
    if (it != g_windowRegistry.end()) {
        if (it->second != nullptr) {
            OH_NativeWindow_DestroyNativeWindow(it->second);
        }
        g_windowRegistry.erase(it);
    }

    if (!surfaceId.empty()) {
        try {
            uint64_t surfaceIdInt = std::stoull(surfaceId);
            OHNativeWindow* nativeWindow = nullptr;
            int32_t ret = OH_NativeWindow_CreateNativeWindowFromSurfaceId(surfaceIdInt, &nativeWindow);
            if (ret == 0 && nativeWindow != nullptr) {
                g_windowRegistry[player] = nativeWindow;
                // Also optionally set it on VLC via nsobject
                libvlc_media_player_set_nsobject(player, nativeWindow);
            } else {
                napi_throw_error(env, nullptr, "Failed to create NativeWindow from surfaceId");
                return nullptr;
            }
        } catch (const std::exception& e) {
            napi_throw_error(env, nullptr, "Invalid surfaceId format (stoull failed)");
            return nullptr;
        }
    } else {
        libvlc_media_player_set_nsobject(player, nullptr);
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}
