#!/bin/bash
# Build libRSDKv4.dylib — same engine sources as the standalone .app, but
# without main.cpp and with Library.cpp's C entry points. The launcher
# dlopens this and calls RetroEngine_Run(dataDir) to embed the game.
set -euo pipefail
cd "$(dirname "$0")"

OUT_DIR="build/dylib"
OUT="${OUT_DIR}/libRSDKv4.dylib"
mkdir -p "${OUT_DIR}"

DEFINES=(
    "-DRSDK_REVISION=3"
    "-DRETRO_USE_NETWORKING=1"
    "-DRETRO_USE_MOD_LOADER=1"
)

INCLUDES=(
    "-Idependencies/all/asio/include"
    "-Idependencies/all/tinyxml2"
    "-Idependencies/all/stb-image"
    # Engine source layout includes "NativeObjects.hpp" via a flat search
    "-IRSDKv4/NativeObjects"
    "-IRSDKv4"
    # SDL2 framework header path (so #include <SDL2/SDL.h> resolves)
    "-Idependencies/mac/SDL2.framework/Headers"
    "-Idependencies/mac"
    # Also offer the canonical include layout in case sources do
    # #include <SDL2/SDL.h> with an explicit subdir (use -isystem so the
    # extra search path doesn't conflict with the framework bundle).
    "-isystem" "/opt/homebrew/include"
)

FRAMEWORKS=(
    "-Fdependencies/mac"
    "-Fdependencies/mac/ogg/macosx"
    "-Fdependencies/mac/libvorbis-1.3.7/macosx"
    "-framework" "SDL2"
    "-framework" "Vorbis"
    "-framework" "Ogg"
    "-framework" "OpenGL"
    "-framework" "Cocoa"
    "-framework" "Foundation"
)

# All RSDKv4 sources except main.cpp (the dylib has no entry point).
SRCS_CPP=(
    RSDKv4/Animation.cpp RSDKv4/Audio.cpp RSDKv4/Collision.cpp
    RSDKv4/Debug.cpp RSDKv4/Drawing.cpp RSDKv4/Ini.cpp RSDKv4/Input.cpp
    RSDKv4/Library.cpp RSDKv4/Math.cpp RSDKv4/ModAPI.cpp
    RSDKv4/Networking.cpp RSDKv4/Object.cpp RSDKv4/Palette.cpp
    RSDKv4/Reader.cpp RSDKv4/Renderer.cpp RSDKv4/RetroEngine.cpp
    RSDKv4/Scene.cpp RSDKv4/Scene3D.cpp RSDKv4/Script.cpp
    RSDKv4/Sprite.cpp RSDKv4/String.cpp RSDKv4/Text.cpp
    RSDKv4/Userdata.cpp
    dependencies/all/tinyxml2/tinyxml2.cpp
)
# RSDKv4/NativeObjects/All.cpp is an amalgamation header — including it
# alongside the individual files causes duplicate symbols. Pick one source
# scheme; here we compile each NativeObject independently like the Xcode
# project does.
for f in RSDKv4/NativeObjects/*.cpp; do
    case "$(basename "$f")" in
        All.cpp) ;;
        *) SRCS_CPP+=("$f") ;;
    esac
done
SRCS_C=(RSDKv4/fcaseopen.c)
SRCS_MM=(dependencies/mac/cocoaHelpers.mm)

CXXFLAGS=(-std=gnu++17 -O2 -fPIC -Wno-deprecated-declarations -Wno-non-c-typedef-for-linkage)
CFLAGS=(-std=gnu11 -O2 -fPIC)
MMFLAGS=(-fobjc-arc -O2 -fPIC)

echo "==> compiling $((${#SRCS_CPP[@]} + ${#SRCS_C[@]} + ${#SRCS_MM[@]})) sources"

# Compile each source to an object file, then link.
OBJS=()
for src in "${SRCS_CPP[@]}"; do
    obj="${OUT_DIR}/$(basename "${src%.*}").o"
    OBJS+=("$obj")
    clang++ "${CXXFLAGS[@]}" "${DEFINES[@]}" "${INCLUDES[@]}" \
        -target arm64-apple-macos10.15 \
        -c "$src" -o "$obj"
done
for src in "${SRCS_C[@]}"; do
    obj="${OUT_DIR}/$(basename "${src%.*}").o"
    OBJS+=("$obj")
    clang "${CFLAGS[@]}" "${DEFINES[@]}" "${INCLUDES[@]}" \
        -target arm64-apple-macos10.15 \
        -c "$src" -o "$obj"
done
for src in "${SRCS_MM[@]}"; do
    obj="${OUT_DIR}/$(basename "${src%.*}").o"
    OBJS+=("$obj")
    clang "${MMFLAGS[@]}" "${DEFINES[@]}" "${INCLUDES[@]}" \
        -target arm64-apple-macos10.15 \
        -c "$src" -o "$obj"
done

echo "==> linking ${OUT}"
clang++ -dynamiclib -target arm64-apple-macos10.15 \
    -install_name "@rpath/libRSDKv4.dylib" \
    -o "${OUT}" \
    "${OBJS[@]}" \
    "${FRAMEWORKS[@]}"

ls -la "${OUT}"
nm -gU "${OUT}" 2>/dev/null | grep -E "RetroEngine_(Run|SetResourcesPath)" || true
echo "Built: ${OUT}"
