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
    set_capability("vout display", 999)
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
    vout_display_sys_t *sys = vd->sys;
    if (!sys->window) {
        picture_Release(picture);
        if (subpicture) subpicture_Delete(subpicture);
        return;
    }

    OHNativeWindowBuffer *buffer = NULL;
    int fenceFd = -1;
    int32_t ret = OH_NativeWindow_NativeWindowRequestBuffer(sys->window, &buffer, &fenceFd);
    if (ret != 0 || !buffer) {
        msg_Err(vd, "NativeWindowRequestBuffer failed with %d", ret);
        picture_Release(picture);
        if (subpicture) subpicture_Delete(subpicture);
        return;
    }

    if (fenceFd >= 0) {
        struct pollfd pfd = { .fd = fenceFd, .events = POLLIN };
        poll(&pfd, 1, 100); 
        close(fenceFd);
    }

    void *vaddr = NULL;
    BufferHandle *handle = OH_NativeWindow_GetBufferHandleFromNative(buffer);
    if (handle) {
        vaddr = mmap(NULL, handle->size, PROT_READ | PROT_WRITE, MAP_SHARED, handle->fd, 0);
        if (vaddr != MAP_FAILED) {
            const int pitch = handle->stride; 
            const int height = handle->height;
            uint8_t *dst = (uint8_t*)vaddr;
            
            const plane_t *p = &picture->p[0];
            const int line_size = p->i_visible_pitch;

            msg_Dbg(vd, "Display: stride=%d, height=%d, line_size=%d", pitch, height, line_size);
            
            // Assume stride is in bytes for now, if not we'll see a crash or corruption
            for (int y = 0; y < p->i_visible_lines && y < height; y++) {
                memcpy(dst + y * pitch, p->p_pixels + y * p->i_pitch, line_size);
            }
            munmap(vaddr, handle->size);
            
            Region region = { .rects = NULL, .rectNumber = 0 }; 
            OH_NativeWindow_NativeWindowFlushBuffer(sys->window, buffer, -1, region);
        } else {
            msg_Err(vd, "mmap failed");
            OH_NativeWindow_NativeWindowAbortBuffer(sys->window, buffer);
        }
    } else {
        msg_Err(vd, "GetBufferHandleFromNative failed");
        OH_NativeWindow_NativeWindowAbortBuffer(sys->window, buffer);
    }
    
    picture_Release(picture);
    if (subpicture) subpicture_Delete(subpicture);
}

static int Control(vout_display_t *vd, int query, va_list args) {
    switch (query) {
        case VOUT_DISPLAY_CHANGE_DISPLAY_SIZE: {
            const vout_display_cfg_t *cfg = va_arg(args, const vout_display_cfg_t *);
            msg_Dbg(vd, "Control: VOUT_DISPLAY_CHANGE_DISPLAY_SIZE %dx%d", cfg->display.width, cfg->display.height);
            if (cfg->display.width > 0 && cfg->display.height > 0) {
                OH_NativeWindow_NativeWindowHandleOpt(vd->sys->window, SET_BUFFER_GEOMETRY, cfg->display.width, cfg->display.height);
            }
            return VLC_SUCCESS;
        }
        case VOUT_DISPLAY_CHANGE_DISPLAY_FILLED:
        case VOUT_DISPLAY_CHANGE_ZOOM:
        case VOUT_DISPLAY_CHANGE_SOURCE_ASPECT:
        case VOUT_DISPLAY_CHANGE_SOURCE_CROP:
            return VLC_SUCCESS;
    }
    return VLC_SUCCESS;
}

static int Open(vlc_object_t *obj)
{
    vout_display_t *vd = (vout_display_t *)obj;

    /* Get the OHNativeWindow. */
    OHNativeWindow* window = NULL;

    msg_Dbg(vd, "Open called");
    vout_window_t *embed = vout_display_NewWindow(vd, VOUT_WINDOW_TYPE_NSOBJECT);
    if (embed && embed->handle.nsobject) {
        window = (OHNativeWindow*)embed->handle.nsobject;
    } else {
        window = (OHNativeWindow*)var_InheritAddress(vd, "drawable-nsobject");
    }

    if (!window) {
        const char* ptrStr = getenv("VLC_OHOS_WINDOW");
        if (ptrStr) {
            sscanf(ptrStr, "%p", &window);
            if (window) {
                msg_Warn(vd, "Got window from VLC_OHOS_WINDOW env hack: %p", window);
            }
        }
    }

    if (!window) {
        msg_Err(vd, "No window available, failing Open");
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
    
    // Set display format to RGBA
    vd->fmt.i_chroma = VLC_CODEC_RGBA;
    vd->fmt.i_rmask = 0x000000ff;
    vd->fmt.i_gmask = 0x0000ff00;
    vd->fmt.i_bmask = 0x00ff0000;
    video_format_FixRgb(&vd->fmt);

    // Create a picture pool
    sys->pool = picture_pool_NewFromFormat(&vd->fmt, 10); // Increase pool size
    if (!sys->pool) {
        if (embed) vout_display_DeleteWindow(vd, embed);
        free(sys);
        return VLC_ENOMEM;
    }
    
    int32_t opt_ret;
    opt_ret = OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_USAGE, 
        (1ULL << 0) /* CPU_READ */ | (1ULL << 1) /* CPU_WRITE */ | (1ULL << 3) /* MEM_DMA */);
    msg_Dbg(vd, "SET_USAGE ret: %d", opt_ret);

    opt_ret = OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_FORMAT, 12 /* NATIVEBUFFER_PIXEL_FMT_RGBA_8888 */);
    msg_Dbg(vd, "SET_FORMAT(12) ret: %d", opt_ret);

    opt_ret = OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_BUFFER_GEOMETRY, vd->fmt.i_width, vd->fmt.i_height);
    msg_Dbg(vd, "SET_BUFFER_GEOMETRY(%dx%d) ret: %d", vd->fmt.i_width, vd->fmt.i_height, opt_ret);

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
