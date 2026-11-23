#include "vlc_napi.h"
#include <vlc/vlc.h>
#include <vector>
#include <string>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <cstdarg>
#include <hilog/log.h>
#include <native_drawing/drawing_text_typography.h>
#include <native_drawing/drawing_text_font_descriptor.h>
#undef LOG_DOMAIN

static const char* kFilesDir = "/data/storage/el2/base/haps/entry/files";
static const char* kCacheDir = "/data/storage/el2/base/haps/entry/cache";

// libVLC's log, on its own threads: warnings and errors go to hilog (tag
// VlcCore) and to stderr, which VlcNew points at files/vlc_init.log. Debug and
// info messages are dropped here: libVLC hands every one of them to the
// callback whatever --verbose says. Nothing here calls into libVLC.
static void VlcLogCallback(void* data, int level, const libvlc_log_t* ctx, const char* fmt, va_list args) {
    if (level < LIBVLC_WARNING) return;
    char msg[768];
    vsnprintf(msg, sizeof(msg), fmt, args);
    const char* module = nullptr;
    const char* file = nullptr;
    unsigned line = 0;
    libvlc_log_get_context(ctx, &module, &file, &line);
    fprintf(stderr, "[%s] %d: %s\n", module ? module : "?", level, msg);
    OH_LOG_Print(LOG_APP, level >= LIBVLC_ERROR ? LOG_ERROR : LOG_WARN, 0x0001, "VlcCore",
                 "%{public}s %{public}s", module ? module : "", msg);
}

struct SystemFont {
    std::string path;
    std::string family;
};

static bool EndsWith(const std::string& s, const char* tail) {
    size_t n = strlen(tail);
    return s.size() > n && s.compare(s.size() - n, n, tail) == 0;
}

// The system's font manager knows where its fonts are (the app renders its own
// text with them, so they are readable here). Prefer a regular, upright,
// normal-width Latin sans font; else any readable .ttf/.otf.
static SystemFont FindSystemFont() {
    SystemFont best;
    int bestScore = -1;
    OH_Drawing_FontDescriptor* query = OH_Drawing_CreateFontDescriptor();
    if (query == nullptr) return best;
    size_t num = 0;
    OH_Drawing_FontDescriptor* list = OH_Drawing_MatchFontDescriptors(query, &num);
    for (size_t i = 0; list != nullptr && i < num; i++) {
        const OH_Drawing_FontDescriptor& d = list[i];
        if (d.path == nullptr || d.fontFamily == nullptr || d.symbolic) continue;
        std::string path = d.path;
        if (!(EndsWith(path, ".ttf") || EndsWith(path, ".otf")) || access(d.path, R_OK) != 0) continue;
        std::string family = d.fontFamily;
        int score = 0;
        // Families known to cover Latin text in full come first.
        if (family == "HarmonyOS Sans" || family == "Roboto" || family == "Noto Sans") score += 32;
        if (family.find("Sans") != std::string::npos) score += 8;
        static const char* partial[] = {
            "Mono", "Emoji", "Condensed", "Digit", "Symbol", "Naskh", "Arabic", "SC", "TC", "CJK",
            "Hebrew", "Thai", "Devanagari", "Bengali", "Tamil", "Myanmar", "Khmer", "Lao", "Tibetan"
        };
        bool whole = true;
        for (const char* p : partial) {
            if (family.find(p) != std::string::npos || path.find(p) != std::string::npos) whole = false;
        }
        if (whole) score += 16;
        if (d.italic == 0 && d.weight == 400) score += 2;
        if (d.width == 5) score += 1;
        if (score > bestScore) {
            bestScore = score;
            best.path = path;
            best.family = family;
        }
    }
    if (list != nullptr) OH_Drawing_DestroyFontDescriptors(list, num);
    OH_Drawing_DestroyFontDescriptor(query);
    return best;
}

static bool CopyFile(const std::string& from, const std::string& to) {
    int in = open(from.c_str(), O_RDONLY);
    if (in < 0) return false;
    int out = open(to.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out < 0) { close(in); return false; }
    char buf[65536];
    ssize_t n;
    bool ok = true;
    while ((n = read(in, buf, sizeof(buf))) > 0) {
        if (write(out, buf, n) != n) { ok = false; break; }
    }
    close(in);
    close(out);
    return ok && n == 0;
}

// The freetype plugin selects fonts through its built-in fontconfig, which has
// no configuration on this platform and so finds no font at all (it then falls
// back to a Linux path that does not exist and subtitles go to "tdummy").
// Give it one: a fonts.conf whose only directory holds a link to a system font,
// and name that font's family in --freetype-font.
static std::string PrepareSubtitleFont() {
    SystemFont font = FindSystemFont();
    if (font.path.empty()) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0x0001, "VlcCore", "no system font for subtitles");
        return "";
    }
    std::string dir = std::string(kFilesDir) + "/fonts";
    mkdir(dir.c_str(), 0755);
    std::string name = font.path.substr(font.path.find_last_of('/') + 1);
    std::string link = dir + "/" + name;
    struct stat st;
    if (stat(link.c_str(), &st) != 0) {
        unlink(link.c_str());
        if (symlink(font.path.c_str(), link.c_str()) != 0 || stat(link.c_str(), &st) != 0) {
            unlink(link.c_str());
            CopyFile(font.path, link);
        }
    }
    std::string conf = std::string(kFilesDir) + "/fonts.conf";
    FILE* f = fopen(conf.c_str(), "w");
    if (f != nullptr) {
        fprintf(f,
                "<?xml version=\"1.0\"?>\n<!DOCTYPE fontconfig SYSTEM \"fonts.dtd\">\n<fontconfig>\n"
                "  <dir>%s</dir>\n  <cachedir>%s/fontconfig</cachedir>\n</fontconfig>\n",
                dir.c_str(), kCacheDir);
        fclose(f);
        setenv("FONTCONFIG_FILE", conf.c_str(), 1);
        setenv("FONTCONFIG_PATH", kFilesDir, 1);
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, 0x0001, "VlcCore", "subtitle font %{public}s (%{public}s)",
                 font.family.c_str(), font.path.c_str());
    return font.family;
}

static void VlcInstanceFinalizer(napi_env env, void* finalize_data, void* finalize_hint) {
    libvlc_instance_t* instance = static_cast<libvlc_instance_t*>(finalize_data);
    if (instance != nullptr) {
        libvlc_release(instance);
    }
}

napi_value VlcNew(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    std::vector<std::string> arg_strs;
    std::vector<const char*> c_args;

    if (argc > 0 && args[0] != nullptr) {
        bool is_array = false;
        napi_is_array(env, args[0], &is_array);
        if (is_array) {
            uint32_t length = 0;
            napi_get_array_length(env, args[0], &length);
            for (uint32_t i = 0; i < length; ++i) {
                napi_value elem;
                napi_get_element(env, args[0], i, &elem);

                size_t str_len;
                status = napi_get_value_string_utf8(env, elem, nullptr, 0, &str_len);
                if (status == napi_ok) {
                    std::string str(str_len + 1, '\0');
                    napi_get_value_string_utf8(env, elem, &str[0], str_len + 1, &str_len);
                    str.resize(str_len);
                    arg_strs.push_back(std::move(str));
                }
            }
        }
    }

    // Subtitles: fontconfig is set up here whatever the caller passed; the
    // family is added unless the caller named one in --freetype-font.
    bool has_font = false;
    for (const auto& s : arg_strs) {
        if (s == "--freetype-font" || s.rfind("--freetype-font=", 0) == 0) has_font = true;
    }
    std::string family = PrepareSubtitleFont();
    if (!has_font && !family.empty()) {
        arg_strs.push_back("--freetype-font=" + family);
    }

    // No program name: libvlc_new() adds its own, and a leading word that is
    // not an option would be queued as a playlist item.
    for (const auto& s : arg_strs) {
        c_args.push_back(s.c_str());
    }

    setenv("VLC_PLUGIN_PATH", "/data/storage/el1/bundle/libs/arm64", 1);

    // Redirect stderr to file for debugging. freopen() makes the stream fully
    // buffered (it now points at a regular file), which loses the tail of the
    // log whenever the process dies; keep it unbuffered like the real stderr.
    freopen("/data/storage/el2/base/haps/entry/files/vlc_init.log", "w", stderr);
    setvbuf(stderr, nullptr, _IONBF, 0);
    freopen("/data/storage/el2/base/haps/entry/files/vlc_init.log", "a", stdout);
    setvbuf(stdout, nullptr, _IONBF, 0);

    libvlc_instance_t* instance = libvlc_new(c_args.size(), c_args.data());
    if (!instance) {
        napi_throw_error(env, nullptr, "Failed to create libvlc instance");
        return nullptr;
    }
    libvlc_log_set(instance, VlcLogCallback, nullptr);

    napi_value obj;
    napi_create_object(env, &obj);

    status = napi_wrap(env, obj, instance, VlcInstanceFinalizer, nullptr, nullptr);
    if (status != napi_ok) {
        libvlc_release(instance);
        napi_throw_error(env, nullptr, "Failed to wrap libvlc instance");
        return nullptr;
    }

    return obj;
}

napi_value VlcRelease(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok) return nullptr;

    if (argc < 1 || args[0] == nullptr) {
        napi_throw_type_error(env, nullptr, "Expected 1 argument (VlcInstance wrapper)");
        return nullptr;
    }

    // On ArkTS napi_remove_wrap runs VlcInstanceFinalizer synchronously, which is
    // what releases the instance. Releasing again here would be a double free.
    void* native_ptr = nullptr;
    napi_remove_wrap(env, args[0], &native_ptr);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}
