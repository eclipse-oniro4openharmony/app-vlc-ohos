#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#define VLC_MODULE_LICENSE VLC_LICENSE_GPL_2_PLUS
#define VLC_MODULE_COPYRIGHT VLC_COPYRIGHT_VIDEOLAN

#include <vlc_common.h>
#include <vlc_plugin.h>
#include <vlc_aout.h>

#include <stdlib.h>
#include <ohaudio/native_audiorenderer.h>
#include <ohaudio/native_audiostreambuilder.h>

struct aout_sys_t
{
    OH_AudioStreamBuilder *builder;
    OH_AudioRenderer *renderer;
};

static int Open(vlc_object_t *obj);
static void Close(vlc_object_t *obj);

vlc_module_begin()
    set_shortname("OHOSAout")
    set_description("OpenHarmony Audio Output")
    set_category(CAT_AUDIO)
    set_subcategory(SUBCAT_AUDIO_AOUT)
    set_capability("audio output", 200)
    set_callbacks(Open, Close)
vlc_module_end()

static int32_t OnWriteData(OH_AudioRenderer* renderer,
                              void* userData,
                              void* buffer,
                              int32_t bufferLen)
{
    audio_output_t *aout = (audio_output_t*)userData;
    VLC_UNUSED(renderer);
    
    // For now, fill with silence to keep it stable
    memset(buffer, 0, bufferLen);
    return 0;
}

static void Play(audio_output_t *aout, block_t *block)
{
    VLC_UNUSED(aout);
    block_Release(block);
}

static void Flush(audio_output_t *aout, bool wait)
{
    VLC_UNUSED(aout);
    VLC_UNUSED(wait);
}

static int Start(audio_output_t *aout, audio_sample_format_t *fmt)
{
    struct aout_sys_t *sys = aout->sys;

    OH_AudioStream_Result res = OH_AudioStreamBuilder_Create(&sys->builder, AUDIOSTREAM_TYPE_RENDERER);
    if (res != AUDIOSTREAM_SUCCESS)
    {
        msg_Err(aout, "Failed to create audio stream builder: %d", res);
        return VLC_EGENERIC;
    }

    // Map VLC audio format -> OHAudio parameters
    OH_AudioStreamBuilder_SetSamplingRate(sys->builder, fmt->i_rate);
    OH_AudioStreamBuilder_SetChannelCount(sys->builder, fmt->i_channels);

    // Map VLC sample format -> OHAudio sample format
    if (fmt->i_format == VLC_CODEC_S16N)
    {
        OH_AudioStreamBuilder_SetSampleFormat(sys->builder, AUDIOSTREAM_SAMPLE_S16LE);
    }
    else if (fmt->i_format == VLC_CODEC_FL32)
    {
        OH_AudioStreamBuilder_SetSampleFormat(sys->builder, AUDIOSTREAM_SAMPLE_F32LE);
    }
    else
    {
        // Default to S16LE and tell VLC to convert
        fmt->i_format = VLC_CODEC_S16N;
        OH_AudioStreamBuilder_SetSampleFormat(sys->builder, AUDIOSTREAM_SAMPLE_S16LE);
    }

    // Set audio usage to MOVIE for proper OS routing
    OH_AudioStreamBuilder_SetRendererInfo(sys->builder, AUDIOSTREAM_USAGE_MOVIE);

    // Registration of callbacks
    OH_AudioRenderer_Callbacks callbacks;
    memset(&callbacks, 0, sizeof(callbacks));
    callbacks.OH_AudioRenderer_OnWriteData = OnWriteData;
    OH_AudioStreamBuilder_SetRendererCallback(sys->builder, callbacks, aout);

    // Generate renderer
    res = OH_AudioStreamBuilder_GenerateRenderer(sys->builder, &sys->renderer);
    if (res != AUDIOSTREAM_SUCCESS)
    {
        msg_Err(aout, "Failed to generate renderer: %d", res);
        OH_AudioStreamBuilder_Destroy(sys->builder);
        sys->builder = NULL;
        return VLC_EGENERIC;
    }

    // Start renderer
    res = OH_AudioRenderer_Start(sys->renderer);
    if (res != AUDIOSTREAM_SUCCESS)
    {
        msg_Err(aout, "Failed to start renderer: %d", res);
        OH_AudioRenderer_Release(sys->renderer);
        sys->renderer = NULL;
        OH_AudioStreamBuilder_Destroy(sys->builder);
        sys->builder = NULL;
        return VLC_EGENERIC;
    }

    msg_Dbg(aout, "OHAudio renderer started: rate=%u, channels=%u, format=%4.4s",
            fmt->i_rate, fmt->i_channels, (char *)&fmt->i_format);

    return VLC_SUCCESS;
}

static void Stop(audio_output_t *aout)
{
    struct aout_sys_t *sys = aout->sys;

    if (sys->renderer)
    {
        OH_AudioRenderer_Stop(sys->renderer);
        OH_AudioRenderer_Release(sys->renderer);
        sys->renderer = NULL;
    }

    if (sys->builder)
    {
        OH_AudioStreamBuilder_Destroy(sys->builder);
        sys->builder = NULL;
    }
}

static int Open(vlc_object_t *obj)
{
    audio_output_t *aout = (audio_output_t *)obj;
    struct aout_sys_t *sys = malloc(sizeof(*sys));
    if (unlikely(sys == NULL))
        return VLC_ENOMEM;

    sys->builder = NULL;
    sys->renderer = NULL;

    aout->sys = sys;
    aout->start = Start;
    aout->stop = Stop;
    aout->play = Play;
    aout->flush = Flush;

    return VLC_SUCCESS;
}

static void Close(vlc_object_t *obj)
{
    audio_output_t *aout = (audio_output_t *)obj;
    struct aout_sys_t *sys = aout->sys;

    free(sys);
    msg_Dbg(aout, "Aout closed");
}
