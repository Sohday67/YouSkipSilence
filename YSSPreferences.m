#import "YSSPreferences.h"
NSString *const kYSSEnabledKey = @"Enabled";
NSString *const kYSSDynamicThresholdKey = @"DynamicThreshold";
NSString *const kYSSFixedThresholdKey = @"FixedThreshold";
NSString *const kYSSPlaybackSpeedKey = @"PlaybackSpeed";
NSString *const kYSSSilenceSpeedKey = @"SilenceSpeed";
NSString *const kYSSTotalSavedKey = @"TotalSaved";
NSString *const kYSSLastVideoSavedKey = @"LastVideoSaved";
NSString *const kYSSPrefsIdentifier = @"com.yours.you-skipsilence";
NSString *const kYSSPrefsChangedNotification = @"com.yours.you-skipsilence/changed";

static const float kYSSDefaultFixedThreshold = 0.02f;
static const float kYSSDefaultPlaybackSpeed = 1.1f;
static const float kYSSDefaultSilenceSpeed = 2.0f;

@implementation YSSPreferences

+ (instancetype)shared {
    static YSSPreferences *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
        NSDictionary *registration = @{
            kYSSEnabledKey: @YES,
            kYSSDynamicThresholdKey: @YES,
            kYSSFixedThresholdKey: @(kYSSDefaultFixedThreshold),
            kYSSPlaybackSpeedKey: @(kYSSDefaultPlaybackSpeed),
            kYSSSilenceSpeedKey: @(kYSSDefaultSilenceSpeed),
            kYSSTotalSavedKey: @0.0,
            kYSSLastVideoSavedKey: @0.0
        };
        [defaults registerDefaults:registration];
        [self reload];
    }
    return self;
}

- (void)reload {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
    self.enabled = [defaults boolForKey:kYSSEnabledKey];
    self.dynamicThreshold = [defaults boolForKey:kYSSDynamicThresholdKey];
    self.fixedThreshold = [[defaults objectForKey:kYSSFixedThresholdKey] floatValue];
    self.playbackSpeed = [[defaults objectForKey:kYSSPlaybackSpeedKey] floatValue];
    self.silenceSpeed = [[defaults objectForKey:kYSSSilenceSpeedKey] floatValue];
    self.totalSaved = [[defaults objectForKey:kYSSTotalSavedKey] doubleValue];
    self.lastVideoSaved = [[defaults objectForKey:kYSSLastVideoSavedKey] doubleValue];
}

- (void)saveStatistics {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
    [defaults setObject:@(self.totalSaved) forKey:kYSSTotalSavedKey];
    [defaults setObject:@(self.lastVideoSaved) forKey:kYSSLastVideoSavedKey];
    [defaults synchronize];
}

- (void)resetLastVideoStatistics {
    self.lastVideoSaved = 0.0;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
    [defaults setObject:@(self.lastVideoSaved) forKey:kYSSLastVideoSavedKey];
    [defaults synchronize];
}

- (void)resetAllStatistics {
    self.totalSaved = 0.0;
    self.lastVideoSaved = 0.0;
    [self saveStatistics];
}

@end
