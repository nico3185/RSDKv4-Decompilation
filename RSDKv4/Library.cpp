// C-callable entry point for embedding RSDKv4 inside another macOS process
// (the Sonic Genesis launcher). Lets the launcher dlopen libRSDKv4 and run
// a game in-process instead of fork/exec'ing the .app.
//
// The existing main.cpp main() is preserved; this file simply adds a
// parallel entry point. Both link against the same engine sources.
//
// Phase 1a: wire one game end-to-end. Re-run cleanup (SDL_Quit, GL teardown,
// global state reset) is intentionally NOT here yet — second-run safety is
// Phase 1b/c work.

#include "RetroEngine.hpp"

#if !RETRO_USE_ORIGINAL_CODE && RETRO_PLATFORM == RETRO_OSX

#include <string.h>
#include <SDL_syswm.h>

// Optional callback the host (the launcher) registers to receive the
// engine's NSWindow* once it's created — used to addChildWindow it onto
// the launcher's own window for "single-window" UX.
typedef void (*RetroEngineWindowReadyFn)(void *nsWindowPtr);
extern "C" RetroEngineWindowReadyFn gRetroEngineWindowReadyCallback = nullptr;

// Storage for the override lives in cocoaHelpers.mm so the standalone
// .app build (which doesn't include Library.cpp) still links. Just
// declare it here.
extern "C" char gRetroEngineResourcesPathOverride[1024];

// Host NSWindow* (opaque to C) the engine should render into instead of
// creating its own. Set by RetroEngine_SetHostWindow before RetroEngine_Run;
// consulted by InitRenderDevice in Drawing.cpp (RETRO_OSX only).
extern "C" void *gRetroEngineHostWindow = nullptr;

extern "C" {

/// Set the directory the engine should treat as its asset / writable root.
/// Pass the directory containing Data.rsdk, settings.ini, SData.bin, etc.
void RetroEngine_SetResourcesPath(const char *path)
{
    if (!path) {
        gRetroEngineResourcesPathOverride[0] = 0;
        return;
    }
    strncpy(gRetroEngineResourcesPathOverride, path,
            sizeof(gRetroEngineResourcesPathOverride) - 1);
    gRetroEngineResourcesPathOverride[sizeof(gRetroEngineResourcesPathOverride) - 1] = 0;
}

/// Run the engine to completion. Returns when the game exits normally.
/// `dataDir` is the directory containing Data.rsdk (and settings.ini,
/// save files, etc). Pass NULL to fall back to bundle / ~/Library auto-
/// detection (same as launching the .app standalone).
int RetroEngine_Run(const char *dataDir)
{
    if (dataDir && *dataDir)
        RetroEngine_SetResourcesPath(dataDir);
    SDL_SetHint(SDL_HINT_WINRT_HANDLE_BACK_BUTTON, "1");
    Engine.Init();
    Engine.Run();
    // Clear host-window override on exit so a subsequent run without one
    // doesn't accidentally pick up a dangling pointer.
    gRetroEngineHostWindow = nullptr;
    return 0;
}

/// Set the host NSWindow* the engine should render into (Phase 2). Call
/// this BEFORE RetroEngine_Run. Pass NULL to clear and let the engine
/// create its own window as before.
void RetroEngine_SetHostWindow(void *nsWindowPtr)
{
    gRetroEngineHostWindow = nsWindowPtr;
}

/// Convenience: set both, then run.
int RetroEngine_RunInWindow(const char *dataDir, void *hostNSWindow)
{
    RetroEngine_SetHostWindow(hostNSWindow);
    return RetroEngine_Run(dataDir);
}

/// Register a callback invoked once the engine has created its SDL window.
/// The argument is the underlying NSWindow* (opaque to C). Lets the host
/// reparent that window (e.g. addChildWindow) for single-window UX.
void RetroEngine_SetWindowReadyCallback(RetroEngineWindowReadyFn cb)
{
    gRetroEngineWindowReadyCallback = cb;
}

/// Toggle the engine's fullscreen state. The launcher uses this to
/// implement in-game fullscreen safely: it detaches the SDL child
/// window from the launcher first (AppKit refuses to fullscreen a
/// child window cleanly), then calls here so the engine flips the SDL
/// window via SDL_SetWindowFullscreen and re-binds the GL viewport.
void RetroEngine_ToggleFullscreen()
{
    Engine.isFullScreen ^= 1;
    SetFullScreen(Engine.isFullScreen);
}

/// Called by Drawing.cpp after SDL_CreateWindow succeeds. Resolves the
/// NSWindow* via SDL_GetWindowWMInfo and forwards it to the host
/// callback, if any.
void RetroEngine_NotifyWindowReady(SDL_Window *window)
{
    if (!gRetroEngineWindowReadyCallback || !window) return;
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (SDL_GetWindowWMInfo(window, &info) && info.subsystem == SDL_SYSWM_COCOA) {
        gRetroEngineWindowReadyCallback((void *)info.info.cocoa.window);
    }
}

} // extern "C"

#endif
