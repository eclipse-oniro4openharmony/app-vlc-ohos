#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#define VLC_MODULE_LICENSE VLC_LICENSE_GPL_2_PLUS
#define VLC_MODULE_COPYRIGHT VLC_COPYRIGHT_VIDEOLAN

#include <vlc_common.h>
#include <vlc_plugin.h>
#include <vlc_vout_display.h>

#include <native_window/external_window.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
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

typedef struct vout_display_sys_t {
    OHNativeWindow* window;
    picture_pool_t *pool;
    vout_window_t  *embed;

    EGLDisplay display;
    EGLContext context;
    EGLSurface surface;
    GLuint program;
    GLuint texture;
    GLuint sub_texture;
    GLuint vbo;
    GLint  u_texture;
    GLint  u_alpha;
    unsigned width;
    unsigned height;

    // GLES2 function pointers
    PFNGLCREATESHADERPROC CreateShader;
    PFNGLSHADERSOURCEPROC ShaderSource;
    PFNGLCOMPILESHADERPROC CompileShader;
    PFNGLGETSHADERIVPROC GetShaderiv;
    PFNGLGETSHADERINFOLOGPROC GetShaderInfoLog;
    PFNGLDELETESHADERPROC DeleteShader;
    PFNGLCREATEPROGRAMPROC CreateProgram;
    PFNGLATTACHSHADERPROC AttachShader;
    PFNGLGETPROGRAMIVPROC GetProgramiv;
    PFNGLGETPROGRAMINFOLOGPROC GetProgramInfoLog;
    PFNGLLINKPROGRAMPROC LinkProgram;
    PFNGLDELETEPROGRAMPROC DeleteProgram;
    PFNGLGETUNIFORMLOCATIONPROC GetUniformLocation;
    PFNGLGENTEXTURESPROC GenTextures;
    PFNGLBINDTEXTUREPROC BindTexture;
    PFNGLTEXPARAMETERIPROC TexParameteri;
    PFNGLDELETETEXTURESPROC DeleteTextures;
    PFNGLGENBUFFERSPROC GenBuffers;
    PFNGLBINDBUFFERPROC BindBuffer;
    PFNGLBUFFERDATAPROC BufferData;
    PFNGLDELETEBUFFERSPROC DeleteBuffers;
    PFNGLUSEPROGRAMPROC UseProgram;
    PFNGLVIEWPORTPROC Viewport;
    PFNGLCLEARCOLORPROC ClearColor;
    PFNGLCLEARPROC Clear;
    PFNGLACTIVETEXTUREPROC ActiveTexture;
    PFNGLTEXIMAGE2DPROC TexImage2D;
    PFNGLUNIFORM1IPROC Uniform1i;
    PFNGLGETATTRIBLOCATIONPROC GetAttribLocation;
    PFNGLENABLEVERTEXATTRIBARRAYPROC EnableVertexAttribArray;
    PFNGLVERTEXATTRIBPOINTERPROC VertexAttribPointer;
    PFNGLDRAWARRAYSPROC DrawArrays;
    PFNGLGETERRORPROC GetError;
    PFNGLENABLEPROC Enable;
    PFNGLDISABLEPROC Disable;
    PFNGLBLENDFUNCPROC BlendFunc;
    PFNGLUNIFORM1FPROC Uniform1f;
} vout_display_sys_t;

/* Subtitles and OSD come to Display() as RGBA regions, drawn over the frame. */
static const vlc_fourcc_t subpicture_chromas[] = { VLC_CODEC_RGBA, 0 };

static const char *vertex_shader_source =
    "attribute vec4 a_position;\n"
    "attribute vec2 a_texCoord;\n"
    "varying vec2 v_texCoord;\n"
    "void main() {\n"
    "  gl_Position = a_position;\n"
    "  v_texCoord = a_texCoord;\n"
    "}\n";

static const char *fragment_shader_source =
    "precision mediump float;\n"
    "varying vec2 v_texCoord;\n"
    "uniform sampler2D u_texture;\n"
    "uniform float u_alpha;\n"
    "void main() {\n"
    "  vec4 c = texture2D(u_texture, v_texCoord);\n"
    "  gl_FragColor = vec4(c.rgb, c.a * u_alpha);\n"
    "}\n";

static GLuint LoadShader(vout_display_t *vd, GLenum type, const char *shader_source) {
    vout_display_sys_t *sys = vd->sys;
    GLuint shader = sys->CreateShader(type);
    if (shader == 0) {
        msg_Err(vd, "glCreateShader(%d) failed, glError: 0x%x", type, sys->GetError());
        return 0;
    }
    sys->ShaderSource(shader, 1, &shader_source, NULL);
    sys->CompileShader(shader);
    GLint compiled;
    sys->GetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        char info[512];
        sys->GetShaderInfoLog(shader, 512, NULL, info);
        msg_Err(vd, "Shader compile failed: %s", info);
        sys->DeleteShader(shader);
        return 0;
    }
    return shader;
}

static int InitGL(vout_display_t *vd) {
    vout_display_sys_t *sys = vd->sys;

#define LOAD_GL(name) do { \
    sys->name = (void*)eglGetProcAddress("gl" #name); \
    if (!sys->name) { \
        msg_Err(vd, "Failed to load gl" #name); \
        return VLC_EGENERIC; \
    } \
} while(0)

    LOAD_GL(CreateShader);
    LOAD_GL(ShaderSource);
    LOAD_GL(CompileShader);
    LOAD_GL(GetShaderiv);
    LOAD_GL(GetShaderInfoLog);
    LOAD_GL(DeleteShader);
    LOAD_GL(CreateProgram);
    LOAD_GL(AttachShader);
    LOAD_GL(GetProgramiv);
    LOAD_GL(GetProgramInfoLog);
    LOAD_GL(LinkProgram);
    LOAD_GL(DeleteProgram);
    LOAD_GL(GetUniformLocation);
    LOAD_GL(GenTextures);
    LOAD_GL(BindTexture);
    LOAD_GL(TexParameteri);
    LOAD_GL(DeleteTextures);
    LOAD_GL(GenBuffers);
    LOAD_GL(BindBuffer);
    LOAD_GL(BufferData);
    LOAD_GL(DeleteBuffers);
    LOAD_GL(UseProgram);
    LOAD_GL(Viewport);
    LOAD_GL(ClearColor);
    LOAD_GL(Clear);
    LOAD_GL(ActiveTexture);
    LOAD_GL(TexImage2D);
    LOAD_GL(Uniform1i);
    LOAD_GL(GetAttribLocation);
    LOAD_GL(EnableVertexAttribArray);
    LOAD_GL(VertexAttribPointer);
    LOAD_GL(DrawArrays);
    LOAD_GL(GetError);
    LOAD_GL(Enable);
    LOAD_GL(Disable);
    LOAD_GL(BlendFunc);
    LOAD_GL(Uniform1f);
#undef LOAD_GL

    GLuint vertex_shader = LoadShader(vd, GL_VERTEX_SHADER, vertex_shader_source);
    GLuint fragment_shader = LoadShader(vd, GL_FRAGMENT_SHADER, fragment_shader_source);
    if (!vertex_shader || !fragment_shader) return VLC_EGENERIC;

    sys->program = sys->CreateProgram();
    if (sys->program == 0) {
        msg_Err(vd, "glCreateProgram failed, glError: 0x%x", sys->GetError());
        return VLC_EGENERIC;
    }
    sys->AttachShader(sys->program, vertex_shader);
    sys->AttachShader(sys->program, fragment_shader);
    sys->LinkProgram(sys->program);
    GLint linked;
    sys->GetProgramiv(sys->program, GL_LINK_STATUS, &linked);
    if (!linked) {
        char info[512];
        sys->GetProgramInfoLog(sys->program, 512, NULL, info);
        msg_Err(vd, "Program link failed: %s", info);
        sys->DeleteProgram(sys->program);
        return VLC_EGENERIC;
    }

    sys->u_texture = sys->GetUniformLocation(sys->program, "u_texture");
    sys->u_alpha = sys->GetUniformLocation(sys->program, "u_alpha");

    GLuint textures[2];
    sys->GenTextures(2, textures);
    sys->texture = textures[0];
    sys->sub_texture = textures[1];
    for (int i = 0; i < 2; i++) {
        sys->BindTexture(GL_TEXTURE_2D, textures[i]);
        sys->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        sys->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        sys->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        sys->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }

    float vertices[] = {
        -1.0f,  1.0f, 0.0f, 0.0f, 0.0f,
        -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,
         1.0f,  1.0f, 0.0f, 1.0f, 0.0f,
         1.0f, -1.0f, 0.0f, 1.0f, 1.0f,
    };

    sys->GenBuffers(1, &sys->vbo);
    sys->BindBuffer(GL_ARRAY_BUFFER, sys->vbo);
    sys->BufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    return VLC_SUCCESS;
}

static int InitEGL(vout_display_t *vd) {
    vout_display_sys_t *sys = vd->sys;

    sys->display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (sys->display == EGL_NO_DISPLAY) {
        msg_Err(vd, "eglGetDisplay failed, eglError: 0x%x", eglGetError());
        return VLC_EGENERIC;
    }

    if (!eglInitialize(sys->display, NULL, NULL)) {
        msg_Err(vd, "eglInitialize failed, eglError: 0x%x", eglGetError());
        return VLC_EGENERIC;
    }

    if (!eglBindAPI(EGL_OPENGL_ES_API)) {
        msg_Err(vd, "eglBindAPI failed, eglError: 0x%x", eglGetError());
        return VLC_EGENERIC;
    }

    EGLint config_attribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_RED_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };

    EGLConfig config;
    EGLint num_configs;
    if (!eglChooseConfig(sys->display, config_attribs, &config, 1, &num_configs)) {
        msg_Err(vd, "eglChooseConfig failed, eglError: 0x%x", eglGetError());
        return VLC_EGENERIC;
    }

    EGLint context_attribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE
    };

    sys->context = eglCreateContext(sys->display, config, EGL_NO_CONTEXT, context_attribs);
    if (sys->context == EGL_NO_CONTEXT) {
        msg_Err(vd, "eglCreateContext failed, eglError: 0x%x", eglGetError());
        return VLC_EGENERIC;
    }

    sys->surface = eglCreateWindowSurface(sys->display, config, (EGLNativeWindowType)sys->window, NULL);
    if (sys->surface == EGL_NO_SURFACE) {
        msg_Err(vd, "eglCreateWindowSurface failed, eglError: 0x%x", eglGetError());
        return VLC_EGENERIC;
    }

    if (!eglMakeCurrent(sys->display, sys->surface, sys->surface, sys->context)) {
        msg_Err(vd, "eglMakeCurrent failed, eglError: 0x%x", eglGetError());
        return VLC_EGENERIC;
    }

    return VLC_SUCCESS;
}

static void CleanupGL(vout_display_t *vd) {
    vout_display_sys_t *sys = vd->sys;
    if (sys->display != EGL_NO_DISPLAY) {
        eglMakeCurrent(sys->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (sys->context != EGL_NO_CONTEXT) eglDestroyContext(sys->display, sys->context);
        if (sys->surface != EGL_NO_SURFACE) eglDestroySurface(sys->display, sys->surface);
        eglTerminate(sys->display);
    }
    if (sys->program && sys->DeleteProgram) sys->DeleteProgram(sys->program);
    if (sys->texture && sys->DeleteTextures) sys->DeleteTextures(1, &sys->texture);
    if (sys->sub_texture && sys->DeleteTextures) sys->DeleteTextures(1, &sys->sub_texture);
    if (sys->vbo && sys->DeleteBuffers) sys->DeleteBuffers(1, &sys->vbo);
}

static picture_pool_t *Pool(vout_display_t *vd, unsigned count)
{
    VLC_UNUSED(count);
    return vd->sys->pool;
}

/* Draws each RGBA region of the subpicture as a blended quad over the frame.
 * Region positions are in the subpicture's reference picture size, which the
 * frame quad stretches over the whole surface. Called with the program, the
 * vbo and the attribute pointers of the frame draw still bound. */
static void DrawSubpicture(vout_display_t *vd, subpicture_t *subpicture)
{
    vout_display_sys_t *sys = vd->sys;
    float ref_w = subpicture->i_original_picture_width > 0
                ? (float)subpicture->i_original_picture_width : (float)vd->source.i_visible_width;
    float ref_h = subpicture->i_original_picture_height > 0
                ? (float)subpicture->i_original_picture_height : (float)vd->source.i_visible_height;
    if (ref_w <= 0 || ref_h <= 0) return;

    sys->Enable(GL_BLEND);
    sys->BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    sys->ActiveTexture(GL_TEXTURE0);
    sys->BindTexture(GL_TEXTURE_2D, sys->sub_texture);

    for (subpicture_region_t *r = subpicture->p_region; r != NULL; r = r->p_next) {
        picture_t *pic = r->p_picture;
        if (pic == NULL || r->fmt.i_chroma != VLC_CODEC_RGBA) continue;
        const plane_t *sp = &pic->p[0];
        if (sp->i_pixel_pitch <= 0 || sp->i_lines <= 0) continue;
        unsigned tex_w = sp->i_pitch / sp->i_pixel_pitch;
        unsigned tex_h = sp->i_lines;
        unsigned w = r->fmt.i_visible_width;
        unsigned h = r->fmt.i_visible_height;
        if (w == 0 || h == 0 || tex_w == 0) continue;

        sys->TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, tex_w, tex_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, sp->p_pixels);

        float u0 = (float)r->fmt.i_x_offset / tex_w;
        float v0 = (float)r->fmt.i_y_offset / tex_h;
        float u1 = (float)(r->fmt.i_x_offset + w) / tex_w;
        float v1 = (float)(r->fmt.i_y_offset + h) / tex_h;
        float x0 = (float)r->i_x / ref_w * 2.0f - 1.0f;
        float x1 = (float)(r->i_x + (int)w) / ref_w * 2.0f - 1.0f;
        float y0 = 1.0f - (float)r->i_y / ref_h * 2.0f;
        float y1 = 1.0f - (float)(r->i_y + (int)h) / ref_h * 2.0f;
        float vertices[] = {
            x0, y0, 0.0f, u0, v0,
            x0, y1, 0.0f, u0, v1,
            x1, y0, 0.0f, u1, v0,
            x1, y1, 0.0f, u1, v1,
        };
        sys->BufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW);
        if (sys->u_alpha >= 0)
            sys->Uniform1f(sys->u_alpha, (r->i_alpha / 255.0f) * (subpicture->i_alpha / 255.0f));
        sys->DrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    sys->Disable(GL_BLEND);
}

static void Display(vout_display_t *vd, picture_t *picture, subpicture_t *subpicture)
{
    vout_display_sys_t *sys = vd->sys;

    if (!sys->window || !sys->surface) {
        picture_Release(picture);
        if (subpicture) subpicture_Delete(subpicture);
        return;
    }

    /* The size of the buffers being drawn, from the window itself: on some
     * devices eglQuerySurface() reports EGL_WIDTH and EGL_HEIGHT swapped. */
    int32_t surface_height = 0, surface_width = 0;
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, GET_BUFFER_GEOMETRY, &surface_height, &surface_width);
    if (surface_width <= 0 || surface_height <= 0) {
        EGLint w = 0, h = 0;
        eglQuerySurface(sys->display, sys->surface, EGL_WIDTH, &w);
        eglQuerySurface(sys->display, sys->surface, EGL_HEIGHT, &h);
        surface_width = w;
        surface_height = h;
    }

    /* The buffer follows the XComponent (sized from the ArkTS side): the core
     * only learns the new size, the pictures keep the source size. */
    if (surface_width > 0 && surface_height > 0 &&
        (surface_width != (int)sys->width || surface_height != (int)sys->height)) {
        msg_Dbg(vd, "Surface resize detected: %dx%d (was %ux%u)",
                surface_width, surface_height, sys->width, sys->height);
        sys->width = surface_width;
        sys->height = surface_height;
        vout_display_SendEventDisplaySize(vd, surface_width, surface_height);
    }

    if (!eglMakeCurrent(sys->display, sys->surface, sys->surface, sys->context)) {
        msg_Err(vd, "eglMakeCurrent failing in Display, eglError: 0x%x", eglGetError());
    }

    sys->ClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    sys->Clear(GL_COLOR_BUFFER_BIT);

    /* Where the picture goes in the surface: fit, zoom, aspect ratio and crop
     * all come from the core's configuration, laid out at the surface's
     * current size (the core's own copy of it may lag one change behind). */
    vout_display_cfg_t cfg = *vd->cfg;
    cfg.display.width = surface_width;
    cfg.display.height = surface_height;
    vout_display_place_t place;
    vout_display_PlacePicture(&place, &vd->source, &cfg, false);
    if (place.width <= 0 || place.height <= 0) {
        place.x = place.y = 0;
        place.width = surface_width;
        place.height = surface_height;
    }
    /* GL's origin is the bottom left corner. */
    sys->Viewport(place.x, surface_height - place.y - place.height, place.width, place.height);

    sys->UseProgram(sys->program);

    sys->ActiveTexture(GL_TEXTURE0);
    sys->BindTexture(GL_TEXTURE_2D, sys->texture);

    const plane_t *p = &picture->p[0];
    const float buf_w = (float)(p->i_pitch / p->i_pixel_pitch);
    const float buf_h = (float)p->i_lines;

    /* The visible (possibly cropped) part of the picture, in the buffer. */
    float u0 = (float)vd->source.i_x_offset / buf_w;
    float v0 = (float)vd->source.i_y_offset / buf_h;
    float u1 = (float)(vd->source.i_x_offset + vd->source.i_visible_width) / buf_w;
    float v1 = (float)(vd->source.i_y_offset + vd->source.i_visible_height) / buf_h;

    sys->TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, p->i_pitch / p->i_pixel_pitch, p->i_lines, 0, GL_RGBA, GL_UNSIGNED_BYTE, p->p_pixels);

    GLenum err = sys->GetError();
    if (err != GL_NO_ERROR) {
        msg_Err(vd, "glTexImage2D failed, glError: 0x%x", err);
    }

    sys->Uniform1i(sys->u_texture, 0);

    float vertices[] = {
        -1.0f,  1.0f, 0.0f, u0, v0,
        -1.0f, -1.0f, 0.0f, u0, v1,
         1.0f,  1.0f, 0.0f, u1, v0,
         1.0f, -1.0f, 0.0f, u1, v1,
    };

    sys->BindBuffer(GL_ARRAY_BUFFER, sys->vbo);
    sys->BufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW);

    GLint posAttrib = sys->GetAttribLocation(sys->program, "a_position");
    sys->EnableVertexAttribArray(posAttrib);
    sys->VertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), 0);

    GLint texAttrib = sys->GetAttribLocation(sys->program, "a_texCoord");
    sys->EnableVertexAttribArray(texAttrib);
    sys->VertexAttribPointer(texAttrib, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));

    if (sys->u_alpha >= 0) sys->Uniform1f(sys->u_alpha, 1.0f);
    sys->DrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (subpicture) DrawSubpicture(vd, subpicture);

    if (!eglSwapBuffers(sys->display, sys->surface)) {
        msg_Err(vd, "eglSwapBuffers failed, eglError: 0x%x", eglGetError());
    }
    
    picture_Release(picture);
    if (subpicture) subpicture_Delete(subpicture);
}

static int Control(vout_display_t *vd, int query, va_list args) {
    switch (query) {
        /* Display() places the picture from vd->cfg and vd->source on each
         * frame: these only have to be accepted. The pictures keep the
         * source size whatever the display, so none of them invalidate the
         * pool. */
        case VOUT_DISPLAY_CHANGE_DISPLAY_SIZE:
        case VOUT_DISPLAY_CHANGE_DISPLAY_FILLED:
        case VOUT_DISPLAY_CHANGE_ZOOM:
        case VOUT_DISPLAY_CHANGE_SOURCE_ASPECT:
        case VOUT_DISPLAY_CHANGE_SOURCE_CROP:
            return VLC_SUCCESS;

        case VOUT_DISPLAY_RESET_PICTURES:
            /* Never requested: the vout does not send PicturesInvalid. */
            return VLC_SUCCESS;
    }
    VLC_UNUSED(vd);
    VLC_UNUSED(args);
    return VLC_SUCCESS;
}

static int Open(vlc_object_t *obj)
{
    vout_display_t *vd = (vout_display_t *)obj;
    vout_display_sys_t *sys = calloc(1, sizeof(*sys));
    if (!sys) return VLC_ENOMEM;
    vd->sys = sys;

    vout_window_t *embed = vout_display_NewWindow(vd, VOUT_WINDOW_TYPE_NSOBJECT);
    if (embed && embed->handle.nsobject) {
        sys->window = (OHNativeWindow*)embed->handle.nsobject;
    } else {
        /* Per-player window, set through libvlc_media_player_set_nsobject().
         * Never fall back to a process-global handle: it would outlive the
         * surface it came from and make the next playback render into a dead
         * window. */
        sys->window = (OHNativeWindow*)var_InheritAddress(vd, "drawable-nsobject");
    }

    if (!sys->window) {
        msg_Warn(vd, "no native window attached to the player yet");
        if (embed) vout_display_DeleteWindow(vd, embed);
        free(sys);
        return VLC_EGENERIC;
    }

    /* Keep the window alive for as long as this display uses it: the ArkTS
     * side may drop its own handle while we are still rendering. */
    OH_NativeWindow_NativeObjectReference(sys->window);

    sys->embed = embed;
    vd->fmt.i_chroma = VLC_CODEC_RGBA;
    vd->fmt.i_rmask = 0x000000ff;
    vd->fmt.i_gmask = 0x0000ff00;
    vd->fmt.i_bmask = 0x00ff0000;
    video_format_FixRgb(&vd->fmt);

    /* The pictures keep the source size: the core only converts the chroma,
     * the GPU scales them into the surface (see Display()). */

    sys->pool = picture_pool_NewFromFormat(&vd->fmt, 10);
    if (!sys->pool) {
        OH_NativeWindow_NativeObjectUnreference(sys->window);
        if (embed) vout_display_DeleteWindow(vd, embed);
        free(sys);
        return VLC_ENOMEM;
    }
    
    // For EGL, we need GLES usage flags
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_USAGE, (1ULL << 8) /* native window usage for gles */ | (1ULL << 9) | (1ULL << 3));
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_FORMAT, 12);
    /* The buffer size is the XComponent's, set from the ArkTS side when the
     * surface changes. Before that, start with the video's own size. */
    int32_t buf_h = 0, buf_w = 0;
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, GET_BUFFER_GEOMETRY, &buf_h, &buf_w);
    if (buf_w <= 0 || buf_h <= 0)
        OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_BUFFER_GEOMETRY,
                                              (int)vd->fmt.i_visible_width, (int)vd->fmt.i_visible_height);

    if (InitEGL(vd) != VLC_SUCCESS || InitGL(vd) != VLC_SUCCESS) {
        CleanupGL(vd);
        picture_pool_Release(sys->pool);
        OH_NativeWindow_NativeObjectUnreference(sys->window);
        if (embed) vout_display_DeleteWindow(vd, embed);
        free(sys);
        return VLC_EGENERIC;
    }

    vd->info.subpicture_chromas = subpicture_chromas;
    vd->pool = Pool;
    vd->display = Display;
    vd->control = Control;

    return VLC_SUCCESS;
}

static void Close(vlc_object_t *obj)
{
    vout_display_t *vd = (vout_display_t *)obj;
    vout_display_sys_t *sys = vd->sys;
    CleanupGL(vd);
    if (sys->pool) picture_pool_Release(sys->pool);
    if (sys->window) OH_NativeWindow_NativeObjectUnreference(sys->window);
    if (sys->embed) vout_display_DeleteWindow(vd, sys->embed);
    free(sys);
}
