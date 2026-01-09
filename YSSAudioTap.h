#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YSSAudioTap : NSObject

@property (nonatomic, weak, nullable) AVPlayer *player;

+ (instancetype)shared;
- (void)attachToPlayerItem:(AVPlayerItem *)item;
- (void)detach;
- (void)updatePlaybackRateIfNeeded;
- (void)resetForNewVideo;

@end

NS_ASSUME_NONNULL_END
