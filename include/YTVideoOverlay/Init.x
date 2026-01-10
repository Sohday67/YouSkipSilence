#if __has_include_next(<YTVideoOverlay/Init.x>)
#import_next <YTVideoOverlay/Init.x>
#else
#import <dlfcn.h>
#import <rootless.h>

static inline void initYTVideoOverlay(NSString *tweakKey, NSDictionary *metadata) {
    // Try to load YTVideoOverlay from the app bundle
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *frameworkPath = [NSString stringWithFormat:@"%@/Frameworks/YTVideoOverlay.dylib", bundlePath];
    dlopen([frameworkPath UTF8String], RTLD_LAZY);
    
    // Try to load from substrate
    dlopen(ROOT_PATH_NS(@"/Library/MobileSubstrate/DynamicLibraries/YTVideoOverlay.dylib").UTF8String, RTLD_LAZY);
    
    // Register the tweak with YTVideoOverlay using performSelector
    // The registerTweak:metadata: method is added by YTVideoOverlay at runtime
    Class managerClass = NSClassFromString(@"YTSettingsSectionItemManager");
    if (managerClass) {
        SEL registerSelector = NSSelectorFromString(@"registerTweak:metadata:");
        if ([managerClass respondsToSelector:registerSelector]) {
            NSMethodSignature *sig = [managerClass methodSignatureForSelector:registerSelector];
            if (sig) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
                [invocation setTarget:managerClass];
                [invocation setSelector:registerSelector];
                [invocation setArgument:&tweakKey atIndex:2];
                [invocation setArgument:&metadata atIndex:3];
                [invocation invoke];
            }
        }
    }
}
#endif
