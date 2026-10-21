# Fontes oficiais das dependências compartilhadas do SnesRecompProject.
#
# Inclua este arquivo no CMakeLists.txt do jogo. As dependências são
# fontes compartilhadas fornecidas pelo workspace ou pelo diretório local dependences/;
# este repositório não as versiona diretamente.
#
# Estrutura esperada:
#   dependences/SDL3/                 SDL 3.4.10
#   dependences/lua-5.4.9/src/        Lua 5.4.9
#   dependences/libjuice-1.7.2/       libjuice 1.7.2

include_guard(GLOBAL)

get_filename_component(SNESRECOMP_DEPENDENCES_ROOT
    "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)

# Se não estiverem no diretório local, busca nos diretórios pai do workspace (até 3 níveis acima)
if(NOT EXISTS "${SNESRECOMP_DEPENDENCES_ROOT}/SDL3/CMakeLists.txt")
    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../dependences/SDL3/CMakeLists.txt")
        get_filename_component(SNESRECOMP_DEPENDENCES_ROOT
            "${CMAKE_CURRENT_LIST_DIR}/../dependences" ABSOLUTE)
    elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../dependences/SDL3/CMakeLists.txt")
        get_filename_component(SNESRECOMP_DEPENDENCES_ROOT
            "${CMAKE_CURRENT_LIST_DIR}/../../dependences" ABSOLUTE)
    elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../../dependences/SDL3/CMakeLists.txt")
        get_filename_component(SNESRECOMP_DEPENDENCES_ROOT
            "${CMAKE_CURRENT_LIST_DIR}/../../../dependences" ABSOLUTE)
    endif()
endif()

set(SNESRECOMP_SDL3_SOURCE_DIR
    "${SNESRECOMP_DEPENDENCES_ROOT}/SDL3" CACHE PATH
    "SDL3 source tree shared by projects in this workspace" FORCE)
set(FETCHCONTENT_SOURCE_DIR_SDL3
    "${SNESRECOMP_SDL3_SOURCE_DIR}" CACHE PATH
    "Use the workspace's SDL3 source tree" FORCE)

set(SNESRECOMP_LUA_SOURCE_DIR
    "${SNESRECOMP_DEPENDENCES_ROOT}/lua-5.4.9" CACHE PATH
    "Lua 5.4.9 source tree shared by projects in this workspace" FORCE)
set(FETCHCONTENT_SOURCE_DIR_SNES_LUA
    "${SNESRECOMP_LUA_SOURCE_DIR}" CACHE PATH
    "Use the workspace's Lua source tree" FORCE)

set(RNET_LIBJUICE_ROOT
    "${SNESRECOMP_DEPENDENCES_ROOT}/libjuice-1.7.2" CACHE PATH
    "libjuice 1.7.2 source tree shared by projects in this workspace" FORCE)

set(_SNESRECOMP_DEPENDENCY_CHECKS
    "SDL3|${SNESRECOMP_SDL3_SOURCE_DIR}/CMakeLists.txt"
    "Lua 5.4.9|${SNESRECOMP_LUA_SOURCE_DIR}/src/lua.h"
    "libjuice 1.7.2|${RNET_LIBJUICE_ROOT}/CMakeLists.txt")
foreach(_dependency IN LISTS _SNESRECOMP_DEPENDENCY_CHECKS)
    string(REPLACE "|" ";" _dependency_parts "${_dependency}")
    list(GET _dependency_parts 0 _dependency_name)
    list(GET _dependency_parts 1 _dependency_marker)
    if(NOT EXISTS "${_dependency_marker}")
        message(FATAL_ERROR
            "Fonte compartilhada de ${_dependency_name} ausente: "
            "${_dependency_marker}. Este projeto não versiona essas fontes; "
            "disponibilize-as no diretório dependences/ ou no workspace pai.")
    endif()
endforeach()

message(STATUS
    "Dependências compartilhadas prontas: SDL3 3.4.10, Lua 5.4.9 e libjuice 1.7.2.")
