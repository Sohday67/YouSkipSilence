#import "YSSPreferences.h"
#import "YSSConstants.h"
#import <Cephei/HBPreferences.h>

@interface YSSPreferences ()
@property (nonatomic, strong) HBPreferences *preferences;
@property (nonatomic, copy) dispatch_block_t changeHandler;
@end

@implementation YSSPreferences

+ (instancetype)sharedInstance {
    static YSSPreferences *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YSSPreferences alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _preferences = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
        NSDictionary *defaults = @{
            kYSSPrefEnabled: @(kYSSDefaultEnabled),
            kYSSPrefDynamicThreshold: @(kYSSDefaultDynamicThreshold),
            kYSSPrefFixedThreshold: @(kYSSDefaultFixedThreshold),
            kYSSPrefPlaybackSpeed: @(kYSSDefaultPlaybackSpeed),
            kYSSPrefSilenceSpeed: @(kYSSDefaultSilenceSpeed),
            kYSSPrefTotalSaved: @(0.0),
            kYSSPrefLastSaved: @(0.0)
        };
        [_preferences registerDefaults:defaults];
    }
    return self;
}

- (void)registerPreferenceChangeHandler:(dispatch_block_t)handler {
    self.changeHandler = handler;
    __weak typeof(self) weakSelf = self;
    [self.preferences registerPreferenceChangeBlock:^{
        if (weakSelf.changeHandler) {
            weakSelf.changeHandler();
        }
    }];
}

- (BOOL)enabled {
    return [self.preferences boolForKey:kYSSPrefEnabled];
}

- (BOOL)dynamicThreshold {
    return [self.preferences boolForKey:kYSSPrefDynamicThreshold];
}

- (double)fixedThreshold {
    return [self.preferences doubleForKey:kYSSPrefFixedThreshold];
}

- (double)playbackSpeed {
    return [self.preferences doubleForKey:kYSSPrefPlaybackSpeed];
}

- (double)silenceSpeed {
    return [self.preferences doubleForKey:kYSSPrefSilenceSpeed];
}

- (double)totalSaved {
    return [self.preferences doubleForKey:kYSSPrefTotalSaved];
}

- (double)lastSaved {
    return [self.preferences doubleForKey:kYSSPrefLastSaved];
}

- (void)setEnabled:(BOOL)enabled {
    [self.preferences setBool:enabled forKey:kYSSPrefEnabled];
}

- (void)setDynamicThreshold:(BOOL)dynamicThreshold {
    [self.preferences setBool:dynamicThreshold forKey:kYSSPrefDynamicThreshold];
}

- (void)setFixedThreshold:(double)fixedThreshold {
    [self.preferences setDouble:fixedThreshold forKey:kYSSPrefFixedThreshold];
}

- (void)setPlaybackSpeed:(double)playbackSpeed {
    [self.preferences setDouble:playbackSpeed forKey:kYSSPrefPlaybackSpeed];
}

- (void)setSilenceSpeed:(double)silenceSpeed {
    [self.preferences setDouble:silenceSpeed forKey:kYSSPrefSilenceSpeed];
}

- (void)addToTotalSaved:(double)value {
    double updated = self.totalSaved + value;
    [self.preferences setDouble:updated forKey:kYSSPrefTotalSaved];
}

- (void)setLastSaved:(double)value {
    [self.preferences setDouble:value forKey:kYSSPrefLastSaved];
}

- (void)resetStatistics {
    [self.preferences setDouble:0.0 forKey:kYSSPrefTotalSaved];
    [self.preferences setDouble:0.0 forKey:kYSSPrefLastSaved];
}

@end
