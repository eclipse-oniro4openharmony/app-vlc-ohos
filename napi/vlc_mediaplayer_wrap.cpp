#include "vlc_napi.h"
#include <vlc/vlc.h>

static void MediaPlayerFinalizer(napi_env env, void* finalize_data, void* finalize_hint) {
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(finalize_data);
    if (player != nullptr) {
        libvlc_media_player_release(player);
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
