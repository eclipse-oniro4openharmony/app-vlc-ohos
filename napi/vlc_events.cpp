#include "vlc_napi.h"
#include <vlc/vlc.h>
#include <mutex>
#include <vector>
#include <map>

// Struct to pass event data from background thread to JS thread
struct VlcEventData {
    libvlc_event_type_t type;
    union {
        float position;
        int64_t time;
        float buffering;
    } u;
};

struct EventContext {
    napi_env env;
    napi_threadsafe_function tsfn;
    libvlc_media_player_t* player;
    libvlc_event_type_t event_type;
};

static std::mutex g_event_mutex;
static std::multimap<libvlc_media_player_t*, EventContext*> g_event_contexts;

static void VlcEventCallFromJS(napi_env env, napi_value js_callback, void* context, void* data) {
    if (env == nullptr || js_callback == nullptr) {
        if (data) delete static_cast<VlcEventData*>(data);
        return;
    }

    napi_handle_scope scope;
    napi_open_handle_scope(env, &scope);

    VlcEventData* eventData = static_cast<VlcEventData*>(data);

    napi_value eventObj;
    napi_create_object(env, &eventObj);

    napi_value typeVal;
    napi_create_uint32(env, eventData->type, &typeVal);
    napi_set_named_property(env, eventObj, "type", typeVal);

    if (eventData->type == libvlc_MediaPlayerPositionChanged) {
        napi_value val;
        napi_create_double(env, eventData->u.position, &val);
        napi_set_named_property(env, eventObj, "position", val);
    } else if (eventData->type == libvlc_MediaPlayerTimeChanged) {
        napi_value val;
        napi_create_int64(env, eventData->u.time, &val);
        napi_set_named_property(env, eventObj, "time", val);
    } else if (eventData->type == libvlc_MediaPlayerBuffering) {
        napi_value val;
        napi_create_double(env, eventData->u.buffering, &val);
        napi_set_named_property(env, eventObj, "buffering", val);
    }

    napi_value result;
    napi_call_function(env, nullptr, js_callback, 1, &eventObj, &result);

    delete eventData;

    napi_close_handle_scope(env, scope);
}

static void NativeEventCallback(const struct libvlc_event_t* p_event, void* p_data) {
    EventContext* ctx = static_cast<EventContext*>(p_data);

    VlcEventData* data = new VlcEventData();
    data->type = p_event->type;

    if (p_event->type == libvlc_MediaPlayerPositionChanged) {
        data->u.position = p_event->u.media_player_position_changed.new_position;
    } else if (p_event->type == libvlc_MediaPlayerTimeChanged) {
        data->u.time = p_event->u.media_player_time_changed.new_time;
    } else if (p_event->type == libvlc_MediaPlayerBuffering) {
        data->u.buffering = p_event->u.media_player_buffering.new_cache;
    }

    napi_status status = napi_call_threadsafe_function(ctx->tsfn, data, napi_tsfn_nonblocking);
    if (status != napi_ok) {
        delete data;
    }
}

napi_value MediaPlayerAttachEvent(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr, nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 3) {
        napi_throw_type_error(env, nullptr, "Expected 3 arguments (VlcMediaPlayer, eventType, callback)");
        return nullptr;
    }

    // Unwrap player
    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    // Get event type
    uint32_t event_type;
    status = napi_get_value_uint32(env, args[1], &event_type);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid eventType argument");
        return nullptr;
    }

    // Identify callback
    napi_valuetype valuetype;
    napi_typeof(env, args[2], &valuetype);
    if (valuetype != napi_function) {
        napi_throw_type_error(env, nullptr, "Callback must be a function");
        return nullptr;
    }

    napi_value resourceName;
    napi_create_string_utf8(env, "VLCEvent", NAPI_AUTO_LENGTH, &resourceName);

    EventContext* ctx = new EventContext();
    ctx->env = env;
    ctx->player = player;
    ctx->event_type = static_cast<libvlc_event_type_t>(event_type);

    status = napi_create_threadsafe_function(
        env,
        args[2],
        nullptr,
        resourceName,
        0,
        1,
        nullptr,
        nullptr,
        ctx,
        VlcEventCallFromJS,
        &ctx->tsfn
    );

    if (status != napi_ok) {
        delete ctx;
        napi_throw_error(env, nullptr, "Failed to create threadsafe function");
        return nullptr;
    }

    libvlc_event_manager_t* em = libvlc_media_player_event_manager(player);
    libvlc_event_attach(em, ctx->event_type, NativeEventCallback, ctx);

    {
        std::lock_guard<std::mutex> lock(g_event_mutex);
        g_event_contexts.insert(std::make_pair(player, ctx));
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value MediaPlayerDetachEvent(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 2) {
        napi_throw_type_error(env, nullptr, "Expected 2 arguments (VlcMediaPlayer, eventType)");
        return nullptr;
    }

    void* player_ptr = nullptr;
    status = napi_unwrap(env, args[0], &player_ptr);
    if (status != napi_ok || player_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);

    uint32_t event_type;
    status = napi_get_value_uint32(env, args[1], &event_type);
    if (status != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid eventType argument");
        return nullptr;
    }

    libvlc_event_type_t target_type = static_cast<libvlc_event_type_t>(event_type);
    libvlc_event_manager_t* em = libvlc_media_player_event_manager(player);

    std::vector<EventContext*> to_delete;

    {
        std::lock_guard<std::mutex> lock(g_event_mutex);
        auto range = g_event_contexts.equal_range(player);
        for (auto it = range.first; it != range.second; ) {
            if (it->second->event_type == target_type) {
                to_delete.push_back(it->second);
                it = g_event_contexts.erase(it);
            } else {
                ++it;
            }
        }
    }

    for (auto* ctx : to_delete) {
        libvlc_event_detach(em, target_type, NativeEventCallback, ctx);
        napi_release_threadsafe_function(ctx->tsfn, napi_tsfn_release);
        delete ctx;
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

void MediaPlayerDetachAllEvents(void* player_ptr) {
    if (!player_ptr) return;
    libvlc_media_player_t* player = static_cast<libvlc_media_player_t*>(player_ptr);
    libvlc_event_manager_t* em = libvlc_media_player_event_manager(player);

    std::vector<EventContext*> to_delete;

    {
        std::lock_guard<std::mutex> lock(g_event_mutex);
        auto range = g_event_contexts.equal_range(player);
        for (auto it = range.first; it != range.second; ) {
            to_delete.push_back(it->second);
            it = g_event_contexts.erase(it);
        }
    }

    for (auto* ctx : to_delete) {
        libvlc_event_detach(em, ctx->event_type, NativeEventCallback, ctx);
        napi_release_threadsafe_function(ctx->tsfn, napi_tsfn_release);
        delete ctx;
    }
}
