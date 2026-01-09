#import "YSSPreferences.h"
#import <Cephei/HBPreferences.h>

NSString *const kYSSEnabledKey = @"Enabled";
NSString *const kYSSDynamicThresholdKey = @"DynamicThreshold";
NSString *const kYSSFixedThresholdKey = @"FixedThreshold";
NSString *const kYSSPlaybackSpeedKey = @"PlaybackSpeed";
NSString *const kYSSSilenceSpeedKey = @"SilenceSpeed";
NSString *const kYSSTotalSavedKey = @"TotalSaved";
NSString *const kYSSLastVideoSavedKey = @"LastVideoSaved";
NSString *const kYSSPrefsIdentifier = @"com.yours.you-skipsilence";

static const float kYSSDefaultFixedThreshold = 0.02f;
static const float kYSSDefaultPlaybackSpeed = 1.1f;
static const float kYSSDefaultSilenceSpeed = 2.0f;

@interface YSSPreferences ()
@property (nonatomic, strong) HBPreferences *preferences;
@end

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
        _preferences = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
        [_preferences registerDefaults:@{
            kYSSEnabledKey: @YES,
            kYSSDynamicThresholdKey: @YES,
            kYSSFixedThresholdKey: @(kYSSDefaultFixedThreshold),
            kYSSPlaybackSpeedKey: @(kYSSDefaultPlaybackSpeed),
            kYSSSilenceSpeedKey: @(kYSSDefaultSilenceSpeed),
            kYSSTotalSavedKey: @0.0,
            kYSSLastVideoSavedKey: @0.0
        }];
        [self reload];
    }
    return self;
}

- (void)reload {
    self.enabled = [self.preferences boolForKey:kYSSEnabledKey];
    self.dynamicThreshold = [self.preferences boolForKey:kYSSDynamicThresholdKey];
    self.fixedThreshold = [[self.preferences objectForKey:kYSSFixedThresholdKey] floatValue];
    self.playbackSpeed = [[self.preferences objectForKey:kYSSPlaybackSpeedKey] floatValue];
    self.silenceSpeed = [[self.preferences objectForKey:kYSSSilenceSpeedKey] floatValue];
    self.totalSaved = [[self.preferences objectForKey:kYSSTotalSavedKey] doubleValue];
    self.lastVideoSaved = [[self.preferences objectForKey:kYSSLastVideoSavedKey] doubleValue];
}

- (void)saveStatistics {
    [self.preferences setObject:@(self.totalSaved) forKey:kYSSTotalSavedKey];
    [self.preferences setObject:@(self.lastVideoSaved) forKey:kYSSLastVideoSavedKey];
}

- (void)resetLastVideoStatistics {
    self.lastVideoSaved = 0.0;
    [self.preferences setObject:@(self.lastVideoSaved) forKey:kYSSLastVideoSavedKey];
}

- (void)resetAllStatistics {
    self.totalSaved = 0.0;
    self.lastVideoSaved = 0.0;
    [self saveStatistics];
}

@end
