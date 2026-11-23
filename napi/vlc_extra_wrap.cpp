// Rate, track selection, parse-without-play and the engine version.
#include "vlc_napi.h"
#include <vlc/vlc.h>
#include <string>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <unistd.h>
#include <cmath>
#include <hilog/log.h>
#undef LOG_DOMAIN

static libvlc_media_player_t* UnwrapPlayer(napi_env env, napi_value v) {
    void* ptr = nullptr;
    if (v == nullptr || napi_unwrap(env, v, &ptr) != napi_ok || ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMediaPlayer argument");
        return nullptr;
    }
    return static_cast<libvlc_media_player_t*>(ptr);
}

static napi_value MakeString(napi_env env, const char* s) {
    napi_value v;
    napi_create_string_utf8(env, s ? s : "", NAPI_AUTO_LENGTH, &v);
    return v;
}

static napi_value MakeNumber(napi_env env, double d) {
    napi_value v;
    napi_create_double(env, d, &v);
    return v;
}

static void SetProp(napi_env env, napi_value obj, const char* name, napi_value value) {
    napi_set_named_property(env, obj, name, value);
}

napi_value MediaPlayerSetRate(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    libvlc_media_player_t* player = argc >= 1 ? UnwrapPlayer(env, args[0]) : nullptr;
    if (!player) return nullptr;
    double rate = 1.0;
    if (argc < 2 || napi_get_value_double(env, args[1], &rate) != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid rate argument");
        return nullptr;
    }
    // libVLC divides by the rate: 0, a negative rate or NaN is undefined there.
    if (!(rate > 0.0) || !std::isfinite(rate)) {
        napi_throw_range_error(env, nullptr, "The rate must be a positive number");
        return nullptr;
    }
    bool ok = libvlc_media_player_set_rate(player, static_cast<float>(rate)) == 0;
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

napi_value MediaPlayerGetRate(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    libvlc_media_player_t* player = argc >= 1 ? UnwrapPlayer(env, args[0]) : nullptr;
    if (!player) return nullptr;
    return MakeNumber(env, libvlc_media_player_get_rate(player));
}

static napi_value DescriptionList(napi_env env, libvlc_track_description_t* head) {
    napi_value arr;
    napi_create_array(env, &arr);
    uint32_t i = 0;
    for (libvlc_track_description_t* t = head; t != nullptr; t = t->p_next) {
        napi_value item;
        napi_create_object(env, &item);
        SetProp(env, item, "id", MakeNumber(env, t->i_id));
        SetProp(env, item, "name", MakeString(env, t->psz_name));
        napi_set_element(env, arr, i++, item);
    }
    if (head) libvlc_track_description_list_release(head);
    return arr;
}

napi_value MediaPlayerGetAudioTracks(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    libvlc_media_player_t* player = argc >= 1 ? UnwrapPlayer(env, args[0]) : nullptr;
    if (!player) return nullptr;
    return DescriptionList(env, libvlc_audio_get_track_description(player));
}

napi_value MediaPlayerGetSpuTracks(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    libvlc_media_player_t* player = argc >= 1 ? UnwrapPlayer(env, args[0]) : nullptr;
    if (!player) return nullptr;
    return DescriptionList(env, libvlc_video_get_spu_description(player));
}

napi_value MediaPlayerGetAudioTrack(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    libvlc_media_player_t* player = argc >= 1 ? UnwrapPlayer(env, args[0]) : nullptr;
    if (!player) return nullptr;
    return MakeNumber(env, libvlc_audio_get_track(player));
}

napi_value MediaPlayerSetAudioTrack(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    libvlc_media_player_t* player = argc >= 1 ? UnwrapPlayer(env, args[0]) : nullptr;
    if (!player) return nullptr;
    int32_t id = -1;
    if (argc < 2 || napi_get_value_int32(env, args[1], &id) != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid track id argument");
        return nullptr;
    }
    napi_value result;
    napi_get_boolean(env, libvlc_audio_set_track(player, id) == 0, &result);
    return result;
}

napi_value MediaPlayerGetSpu(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    libvlc_media_player_t* player = argc >= 1 ? UnwrapPlayer(env, args[0]) : nullptr;
    if (!player) return nullptr;
    return MakeNumber(env, libvlc_video_get_spu(player));
}

napi_value MediaPlayerSetSpu(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    libvlc_media_player_t* player = argc >= 1 ? UnwrapPlayer(env, args[0]) : nullptr;
    if (!player) return nullptr;
    int32_t id = -1;
    if (argc < 2 || napi_get_value_int32(env, args[1], &id) != napi_ok) {
        napi_throw_type_error(env, nullptr, "Invalid track id argument");
        return nullptr;
    }
    int previous = libvlc_video_get_spu(player);
    bool ok = libvlc_video_set_spu(player, id) == 0;
    // The position is kept: at most a seek to the current time, so a cue that
    // already began is read again.
    libvlc_time_t now = libvlc_media_player_get_time(player);
    if (ok && id >= 0 && id != previous && now > 0) {
        libvlc_media_player_set_time(player, now);
    }
    OH_LOG_Print(LOG_APP, LOG_DEBUG, 0x0001, "VlcParse", "set spu %{public}d (was %{public}d) ok %{public}d at %{public}lld ms",
                 id, previous, ok ? 1 : 0, static_cast<long long>(now));
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

napi_value LibvlcVersion(napi_env env, napi_callback_info info) {
    return MakeString(env, libvlc_get_version());
}

// ---- parse without play ----

struct ParseContext {
    napi_env env;
    napi_deferred deferred;
    napi_threadsafe_function tsfn;
    libvlc_media_t* media;  // the media being parsed, owned (one reference)
    int ownedFd;            // dup() behind a /proc/self/fd media, closed at the end
    bool finished;
};

static void ParseDone(ParseContext* ctx) {
    if (ctx->media) libvlc_media_release(ctx->media);
    ctx->media = nullptr;
    if (ctx->ownedFd >= 0) close(ctx->ownedFd);
    ctx->ownedFd = -1;
}

static std::string Fourcc(uint32_t code) {
    std::string s;
    for (int i = 0; i < 4; i++) {
        char c = static_cast<char>((code >> (8 * i)) & 0xff);
        if (c >= 32 && c < 127) s.push_back(c);
    }
    return s;
}

static napi_value BuildInfo(napi_env env, libvlc_media_t* media, int status) {
    napi_value info;
    napi_create_object(env, &info);
    SetProp(env, info, "status", MakeNumber(env, status));
    SetProp(env, info, "durationMs", MakeNumber(env, static_cast<double>(libvlc_media_get_duration(media))));
    char* title = libvlc_media_get_meta(media, libvlc_meta_Title);
    char* mrl = libvlc_media_get_mrl(media);
    std::string t = title ? title : "";
    std::string m = mrl ? mrl : "";
    std::string base = m;
    size_t slash = base.find_last_of('/');
    if (slash != std::string::npos) base = base.substr(slash + 1);
    if (t == m || t == base || t.rfind("fd://", 0) == 0) t.clear();
    SetProp(env, info, "title", MakeString(env, t.c_str()));
    if (title) libvlc_free(title);
    if (mrl) libvlc_free(mrl);

    napi_value tracks;
    napi_create_array(env, &tracks);
    libvlc_media_track_t** list = nullptr;
    unsigned count = libvlc_media_tracks_get(media, &list);
    uint32_t out = 0;
    for (unsigned i = 0; i < count; i++) {
        libvlc_media_track_t* t = list[i];
        const char* type = nullptr;
        if (t->i_type == libvlc_track_audio) type = "audio";
        else if (t->i_type == libvlc_track_video) type = "video";
        else if (t->i_type == libvlc_track_text) type = "text";
        if (!type) continue;
        napi_value item;
        napi_create_object(env, &item);
        uint32_t fcc = t->i_codec ? t->i_codec : t->i_original_fourcc;
        SetProp(env, item, "type", MakeString(env, type));
        SetProp(env, item, "codec", MakeString(env, Fourcc(fcc).c_str()));
        SetProp(env, item, "description", MakeString(env, t->psz_description));
        SetProp(env, item, "language", MakeString(env, t->psz_language));
        double w = 0, h = 0, fn = 0, fd = 0, ch = 0, rate = 0;
        if (t->i_type == libvlc_track_video && t->video) {
            w = t->video->i_width; h = t->video->i_height;
            fn = t->video->i_frame_rate_num; fd = t->video->i_frame_rate_den;
        } else if (t->i_type == libvlc_track_audio && t->audio) {
            ch = t->audio->i_channels; rate = t->audio->i_rate;
        }
        SetProp(env, item, "width", MakeNumber(env, w));
        SetProp(env, item, "height", MakeNumber(env, h));
        SetProp(env, item, "frameRateNum", MakeNumber(env, fn));
        SetProp(env, item, "frameRateDen", MakeNumber(env, fd));
        SetProp(env, item, "channels", MakeNumber(env, ch));
        SetProp(env, item, "rate", MakeNumber(env, rate));
        napi_set_element(env, tracks, out++, item);
    }
    if (list) libvlc_media_tracks_release(list, count);
    SetProp(env, info, "tracks", tracks);
    return info;
}

static void ParseNativeCallback(const struct libvlc_event_t* ev, void* user);

// Runs on the JS thread. The libVLC callback only posts the status here.
static void ParseCallJS(napi_env env, napi_value js_callback, void* context, void* data) {
    ParseContext* ctx = static_cast<ParseContext*>(context);
    int status = static_cast<int>(reinterpret_cast<intptr_t>(data));
    OH_LOG_Print(LOG_APP, LOG_DEBUG, 0x0001, "VlcParse", "parse status %{public}d", status);
    if (env == nullptr || ctx == nullptr || ctx->finished) return;
    ctx->finished = true;

    libvlc_event_manager_t* em = libvlc_media_event_manager(ctx->media);
    libvlc_event_detach(em, libvlc_MediaParsedChanged, ParseNativeCallback, ctx);
    napi_handle_scope scope;
    napi_open_handle_scope(env, &scope);
    napi_value info = BuildInfo(env, ctx->media, status);
    OH_LOG_Print(LOG_APP, LOG_DEBUG, 0x0001, "VlcParse", "parsed duration %{public}lld ms",
                 static_cast<long long>(libvlc_media_get_duration(ctx->media)));
    napi_resolve_deferred(env, ctx->deferred, info);
    napi_close_handle_scope(env, scope);
    ParseDone(ctx);
    napi_release_threadsafe_function(ctx->tsfn, napi_tsfn_release);
}

static void ParseFinalize(napi_env env, void* finalize_data, void* finalize_hint) {
    delete static_cast<ParseContext*>(finalize_data);
}

static void ParseNativeCallback(const struct libvlc_event_t* ev, void* user) {
    ParseContext* ctx = static_cast<ParseContext*>(user);
    intptr_t status = ev->u.media_parsed_changed.new_status;
    napi_call_threadsafe_function(ctx->tsfn, reinterpret_cast<void*>(status), napi_tsfn_nonblocking);
}

napi_value MediaParse(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    void* media_ptr = nullptr;
    if (argc < 1 || napi_unwrap(env, args[0], &media_ptr) != napi_ok || media_ptr == nullptr) {
        napi_throw_type_error(env, nullptr, "Invalid VlcMedia argument");
        return nullptr;
    }
    int32_t timeout = 5000;
    if (argc >= 2) napi_get_value_int32(env, args[1], &timeout);
    libvlc_media_t* media = static_cast<libvlc_media_t*>(media_ptr);

    napi_deferred deferred;
    napi_value promise;
    napi_create_promise(env, &deferred, &promise);

    // The preparser skips an fd:// item (its type is unknown to it), so a media
    // made from a file descriptor is parsed as the file /proc/self/fd/<dup>,
    // which reopens the same file with its own offset.
    libvlc_media_t* target = nullptr;
    int ownedFd = -1;
    char* srcMrl = libvlc_media_get_mrl(media);
    if (srcMrl && strncmp(srcMrl, "fd://", 5) == 0) {
        libvlc_instance_t* inst = MediaFdInstance(media);
        int d = inst ? dup(atoi(srcMrl + 5)) : -1;
        if (d >= 0) {
            char path[64];
            snprintf(path, sizeof(path), "/proc/self/fd/%d", d);
            target = libvlc_media_new_path(inst, path);
            if (target) ownedFd = d; else close(d);
        }
        OH_LOG_Print(LOG_APP, LOG_DEBUG, 0x0001, "VlcParse", "parse %{public}s as fd %{public}d",
                     srcMrl, ownedFd);
    }
    if (srcMrl) libvlc_free(srcMrl);
    if (!target) {
        target = media;
        libvlc_media_retain(media);
    }

    ParseContext* ctx = new ParseContext();
    ctx->env = env;
    ctx->deferred = deferred;
    ctx->media = target;
    ctx->ownedFd = ownedFd;
    ctx->finished = false;

    napi_value name;
    napi_create_string_utf8(env, "VLCParse", NAPI_AUTO_LENGTH, &name);
    napi_value noop;
    napi_get_undefined(env, &noop);
    // No JS callback: the thread-safe function only carries the status to ParseCallJS.
    napi_status st = napi_create_threadsafe_function(env, nullptr, nullptr, name, 0, 1, ctx,
                                                     ParseFinalize, ctx, ParseCallJS, &ctx->tsfn);
    if (st != napi_ok) {
        ParseDone(ctx);
        delete ctx;
        napi_throw_error(env, nullptr, "Failed to create threadsafe function");
        return nullptr;
    }

    libvlc_event_manager_t* em = libvlc_media_event_manager(target);
    libvlc_event_attach(em, libvlc_MediaParsedChanged, ParseNativeCallback, ctx);
    if (timeout < 10000) timeout = 10000;
    int flags = libvlc_media_parse_local | libvlc_media_parse_network;
    if (libvlc_media_parse_with_options(target, static_cast<libvlc_media_parse_flag_t>(flags), timeout) != 0) {
        libvlc_event_detach(em, libvlc_MediaParsedChanged, ParseNativeCallback, ctx);
        ctx->finished = true;
        napi_value failed = BuildInfo(env, target, libvlc_media_parsed_status_failed);
        napi_resolve_deferred(env, deferred, failed);
        ParseDone(ctx);
        napi_release_threadsafe_function(ctx->tsfn, napi_tsfn_release);
    }
    return promise;
}
