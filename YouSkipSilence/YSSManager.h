#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YSSManager : NSObject

+ (instancetype)sharedManager;
- (void)attachToPlayerViewController:(UIViewController *)controller;
- (void)setEnabled:(BOOL)enabled;
- (void)handlePlaybackRateChange:(float)rate;

@end

NS_ASSUME_NONNULL_END
