#include "vlc_napi.h"
#include <vlc/vlc.h>
#include <string>
#include <map>
#include <mutex>
#include <unistd.h>

// A media made from a file descriptor owns a dup() of it, so it outlives the JS close.
static std::mutex g_fdMutex;
static std::map<libvlc_media_t*, int> g_mediaFds;
// The preparser skips an fd:// item (its type is unknown), so mediaParse
// reparses it from /proc/self/fd/N with the instance it was made with.
static std::map<libvlc_media_t*, libvlc_instance_t*> g_mediaInstances;

libvlc_instance_t* MediaFdInstance(libvlc_media_t* media) {
    std::lock_guard<std::mutex> lock(g_fdMutex);
    auto it = g_mediaInstances.find(media);
    return it != g_mediaInstances.end() ? it->second : nullptr;
}

static void MediaFinalizer(napi_env env, void* finalize_data, void* finalize_hint) {
    libvlc_media_t* media = static_cast<libvlc_media_t*>(finalize_data);
    if (media != nullptr) {
        libvlc_media_release(media);
        std::lock_guard<std::mutex> lock(g_fdMutex);
        auto it = g_mediaFds.find(media);
        if (it != g_mediaFds.end()) {
            close(it->second);
            g_mediaFds.erase(it);
        }
        auto inst = g_mediaInstances.find(media);
        if (inst != g_mediaInstances.end()) {
            libvlc_release(inst->second);
            g_mediaInstances.erase(inst);
        }
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

    // The media keeps its own descriptor: the caller may close fd at any time.
    int own = dup(fd);
    if (own < 0) {
        napi_throw_error(env, nullptr, "Failed to duplicate the fd");
        return nullptr;
    }
    libvlc_media_t* media = libvlc_media_new_fd(instance, own);
    if (!media) {
        close(own);
        napi_throw_error(env, nullptr, "Failed to create libvlc_media_t from fd");
        return nullptr;
    }
    {
        std::lock_guard<std::mutex> lock(g_fdMutex);
        g_mediaFds[media] = own;
        libvlc_retain(instance);
        g_mediaInstances[media] = instance;
    }

    napi_value obj;
    napi_create_object(env, &obj);

    status = napi_wrap(env, obj, media, MediaFinalizer, nullptr, nullptr);
    if (status != napi_ok) {
        MediaFinalizer(env, media, nullptr); // releases the media, its fd and the instance reference
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

    // On ArkTS napi_remove_wrap runs MediaFinalizer synchronously, which is what
    // releases the media. Releasing again here would be a double free.
    void* native_ptr = nullptr;
    napi_remove_wrap(env, args[0], &native_ptr);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}
