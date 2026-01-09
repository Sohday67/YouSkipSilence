#import "YSSManager.h"
#import "YSSAudioTap.h"
#import "YSSPreferences.h"

@interface YSSManager ()
@property (nonatomic, weak) AVPlayer *currentPlayer;
@end

@implementation YSSManager

+ (instancetype)shared {
    static YSSManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)attachToPlayer:(AVPlayer *)player item:(AVPlayerItem *)item {
    if (!player || !item) {
        return;
    }
    self.currentPlayer = player;
    YSSAudioTap *tap = [YSSAudioTap shared];
    tap.player = player;
    [tap attachToPlayerItem:item];
    [tap resetForNewVideo];
    [[YSSPreferences shared] resetLastVideoStatistics];
}

- (void)playerDidStartPlayback:(AVPlayer *)player {
    if (!player) {
        return;
    }
    YSSAudioTap *tap = [YSSAudioTap shared];
    tap.player = player;
    [tap updatePlaybackRateIfNeeded];
}

@end
