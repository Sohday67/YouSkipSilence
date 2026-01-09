#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YSSManager : NSObject

+ (instancetype)shared;
- (void)attachToPlayer:(AVPlayer *)player item:(AVPlayerItem *)item;
- (void)playerDidStartPlayback:(AVPlayer *)player;

@end

NS_ASSUME_NONNULL_END
