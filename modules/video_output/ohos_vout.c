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
    GLuint vbo;
    GLint  u_texture;
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
} vout_display_sys_t;

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
    "void main() {\n"
    "  gl_FragColor = texture2D(u_texture, v_texCoord);\n"
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
    
    sys->GenTextures(1, &sys->texture);
    sys->BindTexture(GL_TEXTURE_2D, sys->texture);
    sys->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    sys->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    sys->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    sys->TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

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
    if (sys->vbo && sys->DeleteBuffers) sys->DeleteBuffers(1, &sys->vbo);
}

static picture_pool_t *Pool(vout_display_t *vd, unsigned count)
{
    VLC_UNUSED(count);
    return vd->sys->pool;
}

static void Display(vout_display_t *vd, picture_t *picture, subpicture_t *subpicture)
{
    vout_display_sys_t *sys = vd->sys;

    if (!sys->window || !sys->surface) {
        picture_Release(picture);
        if (subpicture) subpicture_Delete(subpicture);
        return;
    }

    if (!sys->window || !sys->surface) {
        picture_Release(picture);
        if (subpicture) subpicture_Delete(subpicture);
        return;
    }

    EGLint surface_width = 0, surface_height = 0;
    eglQuerySurface(sys->display, sys->surface, EGL_WIDTH, &surface_width);
    eglQuerySurface(sys->display, sys->surface, EGL_HEIGHT, &surface_height);
    
    if (surface_width > 0 && surface_height > 0 && 
        (surface_width != (int)sys->width || surface_height != (int)sys->height)) {
        msg_Dbg(vd, "Surface resize detected: %dx%d (was %ux%u)", 
                surface_width, surface_height, sys->width, sys->height);
        sys->width = surface_width;
        sys->height = surface_height;
        vout_display_SendEventDisplaySize(vd, surface_width, surface_height);
        // Do NOT send PicturesInvalid here, let the core handle the DisplaySize change
    }

    if (!eglMakeCurrent(sys->display, sys->surface, sys->surface, sys->context)) {
        msg_Err(vd, "eglMakeCurrent failing in Display, eglError: 0x%x", eglGetError());
    }

    sys->Viewport(0, 0, surface_width, surface_height);
    sys->ClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    sys->Clear(GL_COLOR_BUFFER_BIT);

    sys->UseProgram(sys->program);

    sys->ActiveTexture(GL_TEXTURE0);
    sys->BindTexture(GL_TEXTURE_2D, sys->texture);
    
    const plane_t *p = &picture->p[0];
    
    // Calculate visible texture coordinates using vd->fmt for visibility
    float tex_w = (float)vd->fmt.i_visible_width / (p->i_pitch / p->i_pixel_pitch);
    float tex_h = (float)vd->fmt.i_visible_height / p->i_lines;

    sys->TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, p->i_pitch / p->i_pixel_pitch, p->i_lines, 0, GL_RGBA, GL_UNSIGNED_BYTE, p->p_pixels);
    
    GLenum err = sys->GetError();
    if (err != GL_NO_ERROR) {
        msg_Err(vd, "glTexImage2D failed, glError: 0x%x", err);
    }

    sys->Uniform1i(sys->u_texture, 0);

    // Update vertices with correct texture coordinates
    float vertices[] = {
        -1.0f,  1.0f, 0.0f, 0.0f,  0.0f,
        -1.0f, -1.0f, 0.0f, 0.0f,  tex_h,
         1.0f,  1.0f, 0.0f, tex_w, 0.0f,
         1.0f, -1.0f, 0.0f, tex_w, tex_h,
    };

    sys->BindBuffer(GL_ARRAY_BUFFER, sys->vbo);
    sys->BufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW);

    GLint posAttrib = sys->GetAttribLocation(sys->program, "a_position");
    sys->EnableVertexAttribArray(posAttrib);
    sys->VertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), 0);

    GLint texAttrib = sys->GetAttribLocation(sys->program, "a_texCoord");
    sys->EnableVertexAttribArray(texAttrib);
    sys->VertexAttribPointer(texAttrib, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));

    sys->DrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    if (!eglSwapBuffers(sys->display, sys->surface)) {
        msg_Err(vd, "eglSwapBuffers failed, eglError: 0x%x", eglGetError());
    }
    
    picture_Release(picture);
    if (subpicture) subpicture_Delete(subpicture);
}

static int Control(vout_display_t *vd, int query, va_list args) {
    switch (query) {
        case VOUT_DISPLAY_CHANGE_DISPLAY_SIZE: {
            const vout_display_cfg_t *cfg = va_arg(args, const vout_display_cfg_t *);
            if (cfg->display.width > 0 && cfg->display.height > 0) {
                if (cfg->display.width != vd->fmt.i_width || cfg->display.height != vd->fmt.i_height) {
                    vout_display_SendEventPicturesInvalid(vd);
                }
            }
            return VLC_SUCCESS;
        }

        case VOUT_DISPLAY_CHANGE_DISPLAY_FILLED: {
            bool is_filled = va_arg(args, int);
            msg_Dbg(vd, "Control: VOUT_DISPLAY_CHANGE_DISPLAY_FILLED %d", is_filled);
            OH_NativeWindow_NativeWindowHandleOpt(vd->sys->window, 11 /* SET_SCALING_MODE */, 
                is_filled ? OH_SCALING_MODE_SCALE_CROP_V2 : OH_SCALING_MODE_SCALE_FIT_V2);
            return VLC_SUCCESS;
        }

        case VOUT_DISPLAY_CHANGE_ZOOM:
        case VOUT_DISPLAY_CHANGE_SOURCE_ASPECT:
        case VOUT_DISPLAY_CHANGE_SOURCE_CROP:
            return VLC_SUCCESS;

        case VOUT_DISPLAY_RESET_PICTURES: {
            msg_Dbg(vd, "Control: VOUT_DISPLAY_RESET_PICTURES to %dx%d", 
                    vd->cfg->display.width, vd->cfg->display.height);
            
            vd->fmt.i_width = vd->fmt.i_visible_width = vd->cfg->display.width;
            vd->fmt.i_height = vd->fmt.i_visible_height = vd->cfg->display.height;
            
            if (vd->sys->window) {
                OH_NativeWindow_NativeWindowHandleOpt(vd->sys->window, SET_BUFFER_GEOMETRY, vd->fmt.i_width, vd->fmt.i_height);
            }

            if (vd->sys->pool) {
                picture_pool_Release(vd->sys->pool);
            }
            vd->sys->pool = picture_pool_NewFromFormat(&vd->fmt, 10);
            if (!vd->sys->pool) {
                msg_Err(vd, "Failed to recreate picture pool");
                return VLC_ENOMEM;
            }
            
            return VLC_SUCCESS;
        }
    }
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
        sys->window = (OHNativeWindow*)var_InheritAddress(vd, "drawable-nsobject");
    }

    if (!sys->window) {
        const char* ptrStr = getenv("VLC_OHOS_WINDOW");
        if (ptrStr) sscanf(ptrStr, "%p", &sys->window);
    }

    if (!sys->window) {
        if (embed) vout_display_DeleteWindow(vd, embed);
        free(sys);
        return VLC_EGENERIC;
    }

    sys->embed = embed;
    vd->fmt.i_chroma = VLC_CODEC_RGBA;
    vd->fmt.i_rmask = 0x000000ff;
    vd->fmt.i_gmask = 0x0000ff00;
    vd->fmt.i_bmask = 0x00ff0000;
    video_format_FixRgb(&vd->fmt);

    if (vd->cfg->display.width > 0 && vd->cfg->display.height > 0) {
        vd->fmt.i_width = vd->fmt.i_visible_width = vd->cfg->display.width;
        vd->fmt.i_height = vd->fmt.i_visible_height = vd->cfg->display.height;
    }

    sys->pool = picture_pool_NewFromFormat(&vd->fmt, 10);
    if (!sys->pool) {
        if (embed) vout_display_DeleteWindow(vd, embed);
        free(sys);
        return VLC_ENOMEM;
    }
    
    // For EGL, we need GLES usage flags
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_USAGE, (1ULL << 8) /* native window usage for gles */ | (1ULL << 9) | (1ULL << 3));
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_FORMAT, 12);
    OH_NativeWindow_NativeWindowHandleOpt(sys->window, SET_BUFFER_GEOMETRY, vd->fmt.i_width, vd->fmt.i_height);

    if (InitEGL(vd) != VLC_SUCCESS || InitGL(vd) != VLC_SUCCESS) {
        CleanupGL(vd);
        if (embed) vout_display_DeleteWindow(vd, embed);
        free(sys);
        return VLC_EGENERIC;
    }

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
    if (sys->embed) vout_display_DeleteWindow(vd, sys->embed);
    free(sys);
}
