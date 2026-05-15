#ifdef __APPLE__

#import <Foundation/Foundation.h>
#include "cocoaHelpers.hpp"
#include <string.h>

// Storage for the host-supplied resources-path override (set by
// RetroEngine_SetResourcesPath in Library.cpp when the engine is loaded as
// a dylib). Defining the storage here keeps the standalone .app build
// linkable without depending on Library.cpp.
extern "C" {
char gRetroEngineResourcesPathOverride[1024] = {0};
}

const char* getResourcesPath(void)
{
    if (gRetroEngineResourcesPathOverride[0] != 0)
        return gRetroEngineResourcesPathOverride;

    @autoreleasepool
    {
        // If the .app bundle's Resources/ directory contains the game data,
        // run fully self-contained out of the bundle (saves and settings live
        // there too). Otherwise, fall back to ~/Library/Application Support/RSDKv4.
        NSString* res     = NSBundle.mainBundle.resourcePath;
        NSFileManager* fm = NSFileManager.defaultManager;
        if (res
            && ([fm fileExistsAtPath:[res stringByAppendingPathComponent:@"Data.rsdk"]]
                || [fm fileExistsAtPath:[res stringByAppendingPathComponent:@"data.rsdk"]]
                || [fm fileExistsAtPath:[res stringByAppendingPathComponent:@"Data"]]
                || [fm fileExistsAtPath:[res stringByAppendingPathComponent:@"settings.ini"]])) {
            return [res UTF8String];
        }

        NSArray* paths                       = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString* applicationSupportDirectory = [paths firstObject];
        NSString* gameData                   = [applicationSupportDirectory stringByAppendingPathComponent:@"RSDKv4"];
        [fm createDirectoryAtPath:gameData withIntermediateDirectories:YES attributes:nil error:nil];
        return [gameData UTF8String];
    }
}
#endif
