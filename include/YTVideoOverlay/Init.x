#if __has_include_next(<YTVideoOverlay/Init.x>)
#import_next <YTVideoOverlay/Init.x>
#else
static inline void initYTVideoOverlay(NSString *tweakKey, NSDictionary *options) {
    (void)tweakKey;
    (void)options;
}
#endif
