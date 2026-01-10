#if __has_include_next(<YTVideoOverlay/Init.x>)
#import_next <YTVideoOverlay/Init.x>
#else
#import <dlfcn.h>
#import <rootless.h>

@interface YTSettingsSectionItemManager : NSObject
+ (void)registerTweak:(NSString *)tweakId metadata:(NSDictionary *)metadata;
@end

static inline void initYTVideoOverlay(NSString *tweakKey, NSDictionary *metadata) {
    // Try to load YTVideoOverlay from the app bundle
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *frameworkPath = [NSString stringWithFormat:@"%@/Frameworks/YTVideoOverlay.dylib", bundlePath];
    dlopen([frameworkPath UTF8String], RTLD_LAZY);
    
    // Try to load from substrate
    dlopen(ROOT_PATH_NS(@"/Library/MobileSubstrate/DynamicLibraries/YTVideoOverlay.dylib").UTF8String, RTLD_LAZY);
    
    // Register the tweak with YTVideoOverlay
    Class managerClass = NSClassFromString(@"YTSettingsSectionItemManager");
    if (managerClass && [managerClass respondsToSelector:@selector(registerTweak:metadata:)]) {
        [managerClass registerTweak:tweakKey metadata:metadata];
    }
}
#endif
