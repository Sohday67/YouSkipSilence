#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kYSSEnabledKey;
extern NSString *const kYSSDynamicThresholdKey;
extern NSString *const kYSSFixedThresholdKey;
extern NSString *const kYSSPlaybackSpeedKey;
extern NSString *const kYSSSilenceSpeedKey;
extern NSString *const kYSSTotalSavedKey;
extern NSString *const kYSSLastVideoSavedKey;
extern NSString *const kYSSPrefsIdentifier;

@interface YSSPreferences : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL dynamicThreshold;
@property (nonatomic, assign) float fixedThreshold;
@property (nonatomic, assign) float playbackSpeed;
@property (nonatomic, assign) float silenceSpeed;
@property (nonatomic, assign) double totalSaved;
@property (nonatomic, assign) double lastVideoSaved;

+ (instancetype)shared;
- (void)reload;
- (void)saveStatistics;
- (void)resetLastVideoStatistics;
- (void)resetAllStatistics;

@end

NS_ASSUME_NONNULL_END
