cmake_minimum_required(VERSION 3.16)
project(vlcnative)

set(VLC_INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../vlc_install")
set(CONTRIB_PREFIX  "${CMAKE_CURRENT_SOURCE_DIR}/../../../../libvlc/contrib/aarch64-linux-ohos")

add_library(vlcnative SHARED
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../napi/vlc_napi_module.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../napi/vlc_instance_wrap.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../napi/vlc_media_wrap.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../napi/vlc_mediaplayer_wrap.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../napi/vlc_events.cpp
)

target_include_directories(vlcnative PRIVATE
    ${VLC_INSTALL_DIR}/include
    ${CONTRIB_PREFIX}/include
)

target_link_directories(vlcnative PRIVATE
    ${VLC_INSTALL_DIR}/lib
    ${CONTRIB_PREFIX}/lib
)

target_link_libraries(vlcnative
    vlc
    vlccore
    libace_napi.z.so
    libhilog_ndk.z.so
    libnative_window.so
)

add_library(ohos_vout_plugin SHARED
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../modules/video_output/ohos_vout.c
)

target_compile_definitions(ohos_vout_plugin PRIVATE __PLUGIN__ MODULE_STRING="ohos_vout_plugin")

target_include_directories(ohos_vout_plugin PRIVATE
    ${VLC_INSTALL_DIR}/include
    ${VLC_INSTALL_DIR}/include/vlc/plugins
    ${CONTRIB_PREFIX}/include
)

target_link_directories(ohos_vout_plugin PRIVATE
    ${VLC_INSTALL_DIR}/lib
    ${CONTRIB_PREFIX}/lib
)

target_link_libraries(ohos_vout_plugin
    vlccore
    libnative_window.so
)

add_library(ohos_aout_plugin SHARED
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../modules/audio_output/ohos_aout.c
)

target_compile_definitions(ohos_aout_plugin PRIVATE __PLUGIN__ MODULE_STRING="ohos_aout_plugin")

target_include_directories(ohos_aout_plugin PRIVATE
    ${VLC_INSTALL_DIR}/include
    ${VLC_INSTALL_DIR}/include/vlc/plugins
    ${CONTRIB_PREFIX}/include
)

target_link_directories(ohos_aout_plugin PRIVATE
    ${VLC_INSTALL_DIR}/lib
    ${CONTRIB_PREFIX}/lib
)

target_link_libraries(ohos_aout_plugin
    vlccore
    libohaudio.so
)
