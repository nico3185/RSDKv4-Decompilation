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

// Storage for the override lives in cocoaHelpers.mm so the standalone
// .app build (which doesn't include Library.cpp) still links. Just
// declare it here.
extern "C" char gRetroEngineResourcesPathOverride[1024];

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
    return 0;
}

} // extern "C"

#endif
