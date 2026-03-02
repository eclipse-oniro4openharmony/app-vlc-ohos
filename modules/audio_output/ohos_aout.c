#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#define VLC_MODULE_LICENSE VLC_LICENSE_GPL_2_PLUS
#define VLC_MODULE_COPYRIGHT VLC_COPYRIGHT_VIDEOLAN

#include <vlc_common.h>
#include <vlc_plugin.h>
#include <vlc_aout.h>

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

static int Open(vlc_object_t *obj)
{
    audio_output_t *aout = (audio_output_t *)obj;
    msg_Dbg(aout, "Open called");
    
    // Return EGENERIC for now as it's a boilerplate
    // We will implement the actual OHAudio initialization in next steps
    return VLC_EGENERIC;
}

static void Close(vlc_object_t *obj)
{
    audio_output_t *aout = (audio_output_t *)obj;
    msg_Dbg(aout, "Close called");
}
