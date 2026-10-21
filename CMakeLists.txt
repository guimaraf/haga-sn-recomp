cmake_minimum_required(VERSION 3.20)
project(HaganeTheFinalConflictSNESRecomp C CXX)

set(CMAKE_C_STANDARD 11)

# Release pin for lobby matching. Release builds stamp the VERSION file so two
# peers can prove they are the same build; everything else stamps "dev".
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" _GAME_VER_RAW)
string(STRIP "${_GAME_VER_RAW}" GAME_RELEASE_VERSION)
set(SNESRECOMP_BUILD_VERSION "" CACHE STRING
    "Lobby release pin (empty = Release uses VERSION, else dev)")
if(SNESRECOMP_BUILD_VERSION STREQUAL "")
    get_property(_is_multi GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(_is_multi)
        set(SNESRECOMP_BUILD_VERSION "$<IF:$<CONFIG:Release>,${GAME_RELEASE_VERSION},dev>")
    elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
        set(SNESRECOMP_BUILD_VERSION "${GAME_RELEASE_VERSION}")
    else()
        set(SNESRECOMP_BUILD_VERSION "dev")
    endif()
endif()

# Conecta ao helper de dependências compartilhadas do repositório
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/dependences/CMakeLists.txt")
    include("${CMAKE_CURRENT_SOURCE_DIR}/dependences/CMakeLists.txt")
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../dependences/CMakeLists.txt")
    include("${CMAKE_CURRENT_SOURCE_DIR}/../dependences/CMakeLists.txt")
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../dependences/CMakeLists.txt")
    include("${CMAKE_CURRENT_SOURCE_DIR}/../../dependences/CMakeLists.txt")
else()
    message(FATAL_ERROR "dependences/CMakeLists.txt não encontrado")
endif()
set(FETCHCONTENT_FULLY_DISCONNECTED ON CACHE BOOL
    "Forbid network fallback for all FetchContent dependencies" FORCE)

set(_SNESRECOMP_DEFAULT_ROOT "${CMAKE_SOURCE_DIR}/modules/snesrecomp")
if(NOT EXISTS "${_SNESRECOMP_DEFAULT_ROOT}/runner/runner.cmake"
   AND EXISTS "${CMAKE_SOURCE_DIR}/snesrecomp/runner/runner.cmake")
    set(_SNESRECOMP_DEFAULT_ROOT "${CMAKE_SOURCE_DIR}/snesrecomp")
endif()
set(SNESRECOMP_ROOT "${_SNESRECOMP_DEFAULT_ROOT}" CACHE PATH
    "Path to the snesrecomp checkout used by this game")
if(NOT EXISTS "${SNESRECOMP_ROOT}/runner/runner.cmake")
    message(FATAL_ERROR
        "snesrecomp submodule missing at ${SNESRECOMP_ROOT}.\n"
        "Run: git submodule update --init --recursive")
endif()

# Mod packages are part of every project, not an option.
set(SNESRECOMP_ENABLE_MODS ON CACHE BOOL
    "Mod package loader + trusted plugins (required for every title)" FORCE)
set(SNESRECOMP_NET_ICE ON CACHE BOOL "Internet netplay" FORCE)

include(${SNESRECOMP_ROOT}/runner/runner.cmake)

add_executable(HaganeTheFinalConflictSNESRecomp
    ${SNESRECOMP_RUNNER_SOURCES}
    src/main.c
    src/host_contract.c
    src/game_rtl.c
    src/gen_stubs.c
)
set_target_properties(HaganeTheFinalConflictSNESRecomp PROPERTIES
    OUTPUT_NAME "Hagane recomp"
)

# ROM identity. rom_identity.txt is the one place the digests live: the build
# turns it into snesrecomp_rom_identity.h for src/main.c.
snesrecomp_rom_identity(HaganeTheFinalConflictSNESRecomp ${CMAKE_SOURCE_DIR}/rom_identity.txt)

# Generated recompiler output.
snesrecomp_target_generated_code(HaganeTheFinalConflictSNESRecomp ${CMAKE_SOURCE_DIR}/src/gen)

# Mod catalog.
snesrecomp_target_mod_catalog(HaganeTheFinalConflictSNESRecomp ${CMAKE_SOURCE_DIR}/mods/preloaded)

target_include_directories(HaganeTheFinalConflictSNESRecomp PRIVATE
    ${SNESRECOMP_RUNNER_INCLUDE_DIRS}
    ${SNESRECOMP_ROOT}/runner/src/desktop
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/recomp
)
target_link_libraries(HaganeTheFinalConflictSNESRecomp PRIVATE ${SNESRECOMP_RUNNER_LIBRARIES})
target_compile_definitions(HaganeTheFinalConflictSNESRecomp PRIVATE
    SNESRECOMP_DISABLE_RUNAHEAD=1
    SNES_GAME_VERSION="${SNESRECOMP_BUILD_VERSION}"
    SNES_GAME_TITLE="Hagane recomp"
)
snesrecomp_target_sdl(HaganeTheFinalConflictSNESRecomp)

# Desktop host: launcher flow, ROM resolution, config.ini, window, etc.
snesrecomp_target_desktop_host(HaganeTheFinalConflictSNESRecomp)
snesrecomp_target_rom_cache(HaganeTheFinalConflictSNESRecomp)

# Shared Dear ImGui pre-boot launcher.
set(_RECOMP_UI_DEFAULT_ROOT "${CMAKE_SOURCE_DIR}/modules/recomp-ui")
if(NOT EXISTS "${_RECOMP_UI_DEFAULT_ROOT}/recomp_ui.cmake"
   AND EXISTS "${CMAKE_SOURCE_DIR}/recomp-ui/recomp_ui.cmake")
    set(_RECOMP_UI_DEFAULT_ROOT "${CMAKE_SOURCE_DIR}/recomp-ui")
endif()
set(RECOMP_UI_ROOT "${_RECOMP_UI_DEFAULT_ROOT}" CACHE PATH
    "Root directory of the shared recomp-ui launcher" FORCE)
if(NOT EXISTS "${RECOMP_UI_ROOT}/recomp_ui.cmake")
    message(FATAL_ERROR
        "recomp-ui missing at ${RECOMP_UI_ROOT}.\n"
        "Run: git submodule update --init --recursive recomp-ui")
endif()
include(${RECOMP_UI_ROOT}/recomp_ui.cmake)
if(EXISTS "${CMAKE_SOURCE_DIR}/launcher_assets/img/boxart.tga")
    recomp_target_launcher_ui(HaganeTheFinalConflictSNESRecomp CONSOLE snes
        BOXART "${CMAKE_SOURCE_DIR}/launcher_assets/img/boxart.tga")
else()
    recomp_target_launcher_ui(HaganeTheFinalConflictSNESRecomp CONSOLE snes)
endif()

target_sources(HaganeTheFinalConflictSNESRecomp PRIVATE
    ${SNESRECOMP_ROOT}/host/snesrecomp_codegen_host.c)
target_include_directories(HaganeTheFinalConflictSNESRecomp PRIVATE
    ${SNESRECOMP_ROOT}/host
    ${RECOMP_UI_ROOT}/src)
