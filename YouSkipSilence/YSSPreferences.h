#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YSSPreferences : NSObject

@property (nonatomic, assign, readonly) BOOL enabled;
@property (nonatomic, assign, readonly) BOOL dynamicThreshold;
@property (nonatomic, assign, readonly) double fixedThreshold;
@property (nonatomic, assign, readonly) double playbackSpeed;
@property (nonatomic, assign, readonly) double silenceSpeed;
@property (nonatomic, assign, readonly) double totalSaved;
@property (nonatomic, assign, readonly) double lastSaved;

+ (instancetype)sharedInstance;
- (void)registerPreferenceChangeHandler:(dispatch_block_t)handler;

- (void)setEnabled:(BOOL)enabled;
- (void)setDynamicThreshold:(BOOL)dynamicThreshold;
- (void)setFixedThreshold:(double)fixedThreshold;
- (void)setPlaybackSpeed:(double)playbackSpeed;
- (void)setSilenceSpeed:(double)silenceSpeed;

- (void)addToTotalSaved:(double)value;
- (void)setLastSaved:(double)value;
- (void)resetStatistics;

@end

NS_ASSUME_NONNULL_END
