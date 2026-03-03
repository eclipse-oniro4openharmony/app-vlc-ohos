#include "vlc_napi.h"

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"vlcNew",                nullptr, VlcNew,                nullptr, nullptr, nullptr, napi_default, nullptr},
        {"vlcRelease",            nullptr, VlcRelease,            nullptr, nullptr, nullptr, napi_default, nullptr},
        
        {"mediaNewPath",          nullptr, MediaNewPath,          nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaNewLocation",      nullptr, MediaNewLocation,      nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaRelease",          nullptr, MediaRelease,          nullptr, nullptr, nullptr, napi_default, nullptr},
        
        {"mediaPlayerNew",        nullptr, MediaPlayerNew,        nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerSetMedia",   nullptr, MediaPlayerSetMedia,   nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerPlay",       nullptr, MediaPlayerPlay,       nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerPause",      nullptr, MediaPlayerPause,      nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerStop",       nullptr, MediaPlayerStop,       nullptr, nullptr, nullptr, napi_default, nullptr},
        
        {"mediaPlayerGetTime",    nullptr, MediaPlayerGetTime,    nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerSetTime",    nullptr, MediaPlayerSetTime,    nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerGetLength",  nullptr, MediaPlayerGetLength,  nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerGetPosition",nullptr, MediaPlayerGetPosition,nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerSetPosition",nullptr, MediaPlayerSetPosition,nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerGetVideoSize",nullptr, MediaPlayerGetVideoSize,nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerSetDisplaySize",nullptr, MediaPlayerSetDisplaySize,nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerSetNativeWindow", nullptr, MediaPlayerSetNativeWindow, nullptr, nullptr, nullptr, napi_default, nullptr},
        
        {"mediaPlayerAttachEvent",    nullptr, MediaPlayerAttachEvent,    nullptr, nullptr, nullptr, napi_default, nullptr},
        {"mediaPlayerDetachEvent",    nullptr, MediaPlayerDetachEvent,    nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

EXTERN_C_START
static napi_value RegisterModule(napi_env env, napi_value exports) { return Init(env, exports); }
EXTERN_C_END

static napi_module vlcModule = { 
    .nm_version = 1, 
    .nm_flags = 0, 
    .nm_filename = nullptr,
    .nm_register_func = RegisterModule, 
    .nm_modname = "vlcnative", 
    .nm_priv = nullptr, 
    .reserved = {0} 
};

extern "C" __attribute__((constructor)) void RegisterVlcNativeModule(void) { 
    napi_module_register(&vlcModule); 
}
