#include "vlc_napi.h"
#include <vlc/vlc.h>
#include <vector>
#include <string>

static void VlcInstanceFinalizer(napi_env env, void* finalize_data, void* finalize_hint) {
    libvlc_instance_t* instance = static_cast<libvlc_instance_t*>(finalize_data);
    if (instance != nullptr) {
        libvlc_release(instance);
    }
}

napi_value VlcNew(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    std::vector<std::string> arg_strs;
    std::vector<const char*> c_args;

    if (argc > 0 && args[0] != nullptr) {
        bool is_array = false;
        napi_is_array(env, args[0], &is_array);
        if (is_array) {
            uint32_t length = 0;
            napi_get_array_length(env, args[0], &length);
            for (uint32_t i = 0; i < length; ++i) {
                napi_value elem;
                napi_get_element(env, args[0], i, &elem);

                size_t str_len;
                status = napi_get_value_string_utf8(env, elem, nullptr, 0, &str_len);
                if (status == napi_ok) {
                    std::string str(str_len + 1, '\0');
                    napi_get_value_string_utf8(env, elem, &str[0], str_len + 1, &str_len);
                    str.resize(str_len);
                    arg_strs.push_back(std::move(str));
                }
            }
        }
    }

    c_args.push_back("vlc_ohos"); // Prepend dummy program name
    for (const auto& s : arg_strs) {
        c_args.push_back(s.c_str());
    }

    setenv("VLC_PLUGIN_PATH", "/data/storage/el1/bundle/libs/arm64", 1);
    
    // Redirect stderr to file for debugging
    freopen("/data/storage/el2/base/haps/entry/files/vlc_init.log", "w", stderr);
    freopen("/data/storage/el2/base/haps/entry/files/vlc_init.log", "a", stdout);

    libvlc_instance_t* instance = libvlc_new(c_args.size(), c_args.data());
    if (!instance) {
        napi_throw_error(env, nullptr, "Failed to create libvlc instance");
        return nullptr;
    }

    napi_value obj;
    napi_create_object(env, &obj);
    
    status = napi_wrap(env, obj, instance, VlcInstanceFinalizer, nullptr, nullptr);
    if (status != napi_ok) {
        libvlc_release(instance);
        napi_throw_error(env, nullptr, "Failed to wrap libvlc instance");
        return nullptr;
    }

    return obj;
}

napi_value VlcRelease(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcInstance wrapper)");
        return nullptr;
    }

    void* native_ptr = nullptr;
    status = napi_remove_wrap(env, args[0], &native_ptr);
    if (status == napi_ok && native_ptr != nullptr) {
        libvlc_release(static_cast<libvlc_instance_t*>(native_ptr));
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}
