#include "vlc_napi.h"
#include <vlc/vlc.h>
#include <string>

static void MediaFinalizer(napi_env env, void* finalize_data, void* finalize_hint) {
    libvlc_media_t* media = static_cast<libvlc_media_t*>(finalize_data);
    if (media != nullptr) {
        libvlc_media_release(media);
    }
}

napi_value MediaNewPath(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 2 || args[0] == nullptr || args[1] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 2 arguments (VlcInstance wrapper, path string)");
        return nullptr;
    }

    void* instance_ptr = nullptr;
    status = napi_unwrap(env, args[0], &instance_ptr);
    if (status != napi_ok || instance_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcInstance argument");
        return nullptr;
    }
    libvlc_instance_t* instance = static_cast<libvlc_instance_t*>(instance_ptr);

    size_t str_len;
    status = napi_get_value_string_utf8(env, args[1], nullptr, 0, &str_len);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid path argument");
        return nullptr;
    }

    std::string path(str_len + 1, '\0');
    napi_get_value_string_utf8(env, args[1], &path[0], str_len + 1, &str_len);
    path.resize(str_len);

    libvlc_media_t* media = libvlc_media_new_path(instance, path.c_str());
    if (!media) {
        napi_throw_error(env, nullptr, "Failed to create libvlc_media_t from path");
        return nullptr;
    }

    napi_value obj;
    napi_create_object(env, &obj);
    
    status = napi_wrap(env, obj, media, MediaFinalizer, nullptr, nullptr);
    if (status != napi_ok) {
        libvlc_media_release(media);
        napi_throw_error(env, nullptr, "Failed to wrap libvlc_media_t");
        return nullptr;
    }

    return obj;
}

napi_value MediaNewLocation(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 2 || args[0] == nullptr || args[1] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 2 arguments (VlcInstance wrapper, location string)");
        return nullptr;
    }

    void* instance_ptr = nullptr;
    status = napi_unwrap(env, args[0], &instance_ptr);
    if (status != napi_ok || instance_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcInstance argument");
        return nullptr;
    }
    libvlc_instance_t* instance = static_cast<libvlc_instance_t*>(instance_ptr);

    size_t str_len;
    status = napi_get_value_string_utf8(env, args[1], nullptr, 0, &str_len);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid location argument");
        return nullptr;
    }

    std::string location(str_len + 1, '\0');
    napi_get_value_string_utf8(env, args[1], &location[0], str_len + 1, &str_len);
    location.resize(str_len);

    libvlc_media_t* media = libvlc_media_new_location(instance, location.c_str());
    if (!media) {
        napi_throw_error(env, nullptr, "Failed to create libvlc_media_t from location");
        return nullptr;
    }

    napi_value obj;
    napi_create_object(env, &obj);
    
    status = napi_wrap(env, obj, media, MediaFinalizer, nullptr, nullptr);
    if (status != napi_ok) {
        libvlc_media_release(media);
        napi_throw_error(env, nullptr, "Failed to wrap libvlc_media_t");
        return nullptr;
    }

    return obj;
}

napi_value MediaNewFd(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 2 || args[0] == nullptr || args[1] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 2 arguments (VlcInstance wrapper, fd number)");
        return nullptr;
    }

    void* instance_ptr = nullptr;
    status = napi_unwrap(env, args[0], &instance_ptr);
    if (status != napi_ok || instance_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcInstance argument");
        return nullptr;
    }
    libvlc_instance_t* instance = static_cast<libvlc_instance_t*>(instance_ptr);

    int fd;
    status = napi_get_value_int32(env, args[1], &fd);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid fd argument");
        return nullptr;
    }

    libvlc_media_t* media = libvlc_media_new_fd(instance, fd);
    if (!media) {
        napi_throw_error(env, nullptr, "Failed to create libvlc_media_t from fd");
        return nullptr;
    }

    napi_value obj;
    napi_create_object(env, &obj);
    
    status = napi_wrap(env, obj, media, MediaFinalizer, nullptr, nullptr);
    if (status != napi_ok) {
        libvlc_media_release(media);
        napi_throw_error(env, nullptr, "Failed to wrap libvlc_media_t");
        return nullptr;
    }

    return obj;
}

napi_value MediaRelease(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcMedia wrapper)");
        return nullptr;
    }

    void* native_ptr = nullptr;
    status = napi_remove_wrap(env, args[0], &native_ptr);
    if (status == napi_ok && native_ptr != nullptr) {
        libvlc_media_release(static_cast<libvlc_media_t*>(native_ptr));
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}
