#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#define VLC_MODULE_LICENSE VLC_LICENSE_GPL_2_PLUS
#define VLC_MODULE_COPYRIGHT VLC_COPYRIGHT_VIDEOLAN

#include <vlc_common.h>
#include <vlc_plugin.h>
#include <vlc_vout_display.h>

#include <native_window/external_window.h>
#include <sys/mman.h>
#include <poll.h>
#include <unistd.h>

static int Open(vlc_object_t *obj);
static void Close(vlc_object_t *obj);

vlc_module_begin()
    set_shortname("OHOSVout")
    set_description("OpenHarmony Video Output")
    set_category(CAT_VIDEO)
    set_subcategory(SUBCAT_VIDEO_VOUT)
    set_capability("vout display", 260)
    add_shortcut("OHOSVout")
    set_callbacks(Open, Close)
vlc_module_end()

struct vout_display_sys_t {
    OHNativeWindow* window;
    picture_pool_t *pool;
    vout_window_t  *embed;
};

static picture_pool_t *Pool(vout_display_t *vd, unsigned count)
{
    VLC_UNUSED(count);
    return vd->sys->pool;
}

static void Display(vout_display_t *vd, picture_t *picture, subpicture_t *subpicture)
{
    VLC_UNUSED(subpicture);
    vout_display_sys_t *sys = vd->sys;
    if (!sys->window) return;

    OHNativeWindowBuffer *buffer = NULL;
    int fenceFd = -1;
    if (OH_NativeWindow_NativeWindowRequestBuffer(sys->window, &buffer, &fenceFd) != 0) {
        return;
    }

    if (fenceFd >= 0) {
        struct pollfd pfd = { .fd = fenceFd, .events = POLLIN };
        poll(&pfd, 1, 1000); 
        close(fenceFd);
    }

    void *vaddr = NULL;
    BufferHandle *handle = OH_NativeWindow_GetBufferHandleFromNative(buffer);
    if (!handle) {
        OH_NativeWindow_NativeWindowAbortBuffer(sys->window, buffer); // Actually OH_NativeWindow_NativeWindowAbortBuffer
        return;
    }

    vaddr = mmap(NULL, handle->size, PROT_READ | PROT_WRITE, MAP_SHARED, handle->fd, 0);
    if (vaddr != MAP_FAILED) {
        const int pitch = handle->stride;
        const int height = handle->height;
        uint8_t *dst = (uint8_t*)vaddr;
        
        for (int i = 0; i < picture->i_planes; i++) {
            const plane_t *p = &picture->p[i];
            for (int y = 0; y < p->i_visible_lines && y < height; y++) {
                memcpy(dst + y * pitch, p->p_pixels + y * p->i_pitch, p->i_visible_pitch);
            }
            dst += pitch * height; 
        }
        munmap(vaddr, handle->size);
    }

    Region region = { .rects = NULL, .rectNumber = 0 }; 
    OH_NativeWindow_NativeWindowFlushBuffer(sys->window, buffer, -1, region);
}

static int Control(vout_display_t *vd, int query, va_list args) {
    VLC_UNUSED(vd);
    VLC_UNUSED(query);
    VLC_UNUSED(args);
    return VLC_SUCCESS;
}

static int Open(vlc_object_t *obj)
{
    vout_display_t *vd = (vout_display_t *)obj;

    /* Get the OHNativeWindow. */
    OHNativeWindow* window = NULL;

    vout_window_t *embed = vout_display_NewWindow(vd, VOUT_WINDOW_TYPE_NSOBJECT);
    if (embed && embed->handle.nsobject) {
        window = (OHNativeWindow*)embed->handle.nsobject;
    } else {
        window = (OHNativeWindow*)var_InheritAddress(vd, "drawable-nsobject");
    }

    if (!window) {
        if (embed) vout_display_DeleteWindow(vd, embed);
        return VLC_EGENERIC;
    }

    vout_display_sys_t *sys = calloc(1, sizeof(*sys));
    if (!sys) {
        if (embed) vout_display_DeleteWindow(vd, embed);
        return VLC_ENOMEM;
    }

    vd->sys = sys;
    sys->window = window;
    sys->embed = embed;
    sys->pool = NULL;
    
    video_format_t fmt;
    video_format_ApplyRotation(&fmt, &vd->source);
    
    // Fallback to RGBA since we don't have exact hardware integration yet
    fmt.i_chroma = VLC_CODEC_RGBA;
    
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_BUFFER_GEOMETRY, fmt.i_width, fmt.i_height);
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_FORMAT, 1 /* GRAPHIC_PIXEL_FMT_RGBA_8888 */);
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_USAGE, 1ULL << 0 /* BUFFER_USAGE_CPU_WRITE */);

    vd->fmt = fmt;

    vd->pool = Pool;
    vd->prepare = NULL;
    vd->display = Display;
    vd->control = Control;

    return VLC_SUCCESS;
}

static void Close(vlc_object_t *obj)
{
    vout_display_t *vd = (vout_display_t *)obj;
    vout_display_sys_t *sys = vd->sys;
    if (sys->pool) {
        picture_pool_Release(sys->pool);
    }
    if (sys->embed) {
        vout_display_DeleteWindow(vd, sys->embed);
    }
    free(sys);
}
