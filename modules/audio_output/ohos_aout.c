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

    vlc_mutex_t lock;
    block_t *p_out_chain;
    block_t **pp_out_last;
    size_t i_out_size;
    size_t i_out_max_size;
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
    struct aout_sys_t *sys = aout->sys;
    VLC_UNUSED(renderer);
    
    uint8_t *p_dst = buffer;
    size_t i_to_copy = bufferLen;

    vlc_mutex_lock(&sys->lock);

    while (i_to_copy > 0 && sys->p_out_chain != NULL)
    {
        block_t *p_block = sys->p_out_chain;
        size_t i_copy = __MIN(i_to_copy, p_block->i_buffer);

        memcpy(p_dst, p_block->p_buffer, i_copy);

        i_to_copy -= i_copy;
        p_dst += i_copy;
        sys->i_out_size -= i_copy;

        if (i_copy == p_block->i_buffer)
        {
            sys->p_out_chain = p_block->p_next;
            if (sys->p_out_chain == NULL)
                sys->pp_out_last = &sys->p_out_chain;
            block_Release(p_block);
        }
        else
        {
            p_block->p_buffer += i_copy;
            p_block->i_buffer -= i_copy;
        }
    }

    vlc_mutex_unlock(&sys->lock);

    if (i_to_copy > 0)
    {
        // msg_Dbg(aout, "audio underrun: %zu bytes", i_to_copy);
        memset(p_dst, 0, i_to_copy);
    }

    return 0;
}

static void Play(audio_output_t *aout, block_t *block)
{
    struct aout_sys_t *sys = aout->sys;

    vlc_mutex_lock(&sys->lock);

    if (sys->i_out_size >= sys->i_out_max_size)
    {
        msg_Warn(aout, "audio buffer overflow, dropping block");
        vlc_mutex_unlock(&sys->lock);
        block_Release(block);
        return;
    }

    block_ChainLastAppend(&sys->pp_out_last, block);
    sys->i_out_size += block->i_buffer;

    vlc_mutex_unlock(&sys->lock);
}

static void Flush(audio_output_t *aout, bool wait)
{
    struct aout_sys_t *sys = aout->sys;
    VLC_UNUSED(wait);

    vlc_mutex_lock(&sys->lock);
    block_ChainRelease(sys->p_out_chain);
    sys->p_out_chain = NULL;
    sys->pp_out_last = &sys->p_out_chain;
    sys->i_out_size = 0;
    vlc_mutex_unlock(&sys->lock);
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

    Flush(aout, false);
}

static int Open(vlc_object_t *obj)
{
    audio_output_t *aout = (audio_output_t *)obj;
    struct aout_sys_t *sys = malloc(sizeof(*sys));
    if (unlikely(sys == NULL))
        return VLC_ENOMEM;

    vlc_mutex_init(&sys->lock);
    sys->builder = NULL;
    sys->renderer = NULL;
    sys->p_out_chain = NULL;
    sys->pp_out_last = &sys->p_out_chain;
    sys->i_out_size = 0;
    sys->i_out_max_size = 2 * 1024 * 1024; // 2MB default limit

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

    vlc_mutex_destroy(&sys->lock);
    free(sys);
    msg_Dbg(aout, "Aout closed");
}
