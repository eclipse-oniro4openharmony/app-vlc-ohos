#ifndef VLC_NAPI_H
#define VLC_NAPI_H

#include <napi/native_api.h>
#include <vlc/vlc.h>

#ifdef __cplusplus
extern "C" {
#endif

// Core lifecycle
napi_value VlcNew(napi_env env, napi_callback_info info);
napi_value VlcRelease(napi_env env, napi_callback_info info);

// Media
napi_value MediaNewPath(napi_env env, napi_callback_info info);
napi_value MediaNewLocation(napi_env env, napi_callback_info info);
napi_value MediaNewFd(napi_env env, napi_callback_info info);
napi_value MediaRelease(napi_env env, napi_callback_info info);
// The instance a media from mediaNewFd was made with (retained), or NULL.
libvlc_instance_t* MediaFdInstance(libvlc_media_t* media);

// Media Player
napi_value MediaPlayerNew(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetMedia(napi_env env, napi_callback_info info);
napi_value MediaPlayerPlay(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetPause(napi_env env, napi_callback_info info);
napi_value MediaPlayerPause(napi_env env, napi_callback_info info);
napi_value MediaPlayerIsPlaying(napi_env env, napi_callback_info info);
napi_value MediaPlayerStop(napi_env env, napi_callback_info info);
napi_value MediaPlayerCleanup(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetTime(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetTime(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetLength(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetPosition(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetPosition(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetVideoSize(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetDisplaySize(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetAspectRatio(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetScale(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetCrop(napi_env env, napi_callback_info info);

// Rate, tracks, parse, version
napi_value MediaPlayerSetRate(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetRate(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetAudioTracks(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetSpuTracks(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetAudioTrack(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetAudioTrack(napi_env env, napi_callback_info info);
napi_value MediaPlayerGetSpu(napi_env env, napi_callback_info info);
napi_value MediaPlayerSetSpu(napi_env env, napi_callback_info info);
napi_value MediaParse(napi_env env, napi_callback_info info);
napi_value LibvlcVersion(napi_env env, napi_callback_info info);

// Video output binding
napi_value MediaPlayerSetNativeWindow(napi_env env, napi_callback_info info);

// Events
napi_value MediaPlayerAttachEvent(napi_env env, napi_callback_info info);
napi_value MediaPlayerDetachEvent(napi_env env, napi_callback_info info);
void MediaPlayerDetachAllEvents(void* player);


#ifdef __cplusplus
}
#endif

#endif // VLC_NAPI_H
