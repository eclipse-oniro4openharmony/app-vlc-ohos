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
