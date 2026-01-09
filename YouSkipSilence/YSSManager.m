#import "YSSManager.h"
#import "YSSPreferences.h"
#import "YSSSilenceDetector.h"

@interface YSSManager () <YSSSilenceDetectorDelegate>
@property (nonatomic, weak) UIViewController *playerViewController;
@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic, weak) AVPlayer *observedPlayer;
@property (nonatomic, strong) YSSSilenceDetector *detector;
@property (nonatomic, assign) BOOL isSilent;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) CFTimeInterval lastSwitchTime;
@property (nonatomic, assign) CFTimeInterval silentStartTime;
@end

@implementation YSSManager

+ (instancetype)sharedManager {
    static YSSManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YSSManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = [YSSPreferences sharedInstance].enabled;
        __weak typeof(self) weakSelf = self;
        [[YSSPreferences sharedInstance] registerPreferenceChangeHandler:^{
            weakSelf.enabled = [YSSPreferences sharedInstance].enabled;
            [weakSelf refreshPlaybackRateForCurrentState];
        }];
    }
    return self;
}

- (void)attachToPlayerViewController:(UIViewController *)controller {
    self.playerViewController = controller;
    AVPlayer *player = [self findPlayerInController:controller];
    if (player != self.player) {
        [self observePlayer:player];
    }
}

- (void)setEnabled:(BOOL)enabled {
    self.enabled = enabled;
    [self refreshPlaybackRateForCurrentState];
}

- (void)handlePlaybackRateChange:(float)rate {
    (void)rate;
}

- (AVPlayer *)findPlayerInController:(UIViewController *)controller {
    NSArray<NSString *> *keys = @[@"player", @"avPlayer", @"_player"];
    for (NSString *key in keys) {
        @try {
            AVPlayer *player = [controller valueForKey:key];
            if ([player isKindOfClass:[AVPlayer class]]) {
                return player;
            }
        } @catch (NSException *exception) {
        }
    }
    return nil;
}

- (void)observePlayer:(AVPlayer *)player {
    [self.detector stop];
    self.detector = nil;
    if (self.observedPlayer) {
        @try {
            [self.observedPlayer removeObserver:self forKeyPath:@"currentItem"];
        } @catch (NSException *exception) {
        }
    }
    self.player = player;
    self.observedPlayer = player;
    if (!player) {
        return;
    }
    [player addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew context:nil];
    [self resetLastVideoSaved];
    [self attachDetectorToItem:player.currentItem];
}

- (void)attachDetectorToItem:(AVPlayerItem *)item {
    if (self.silentStartTime > 0) {
        CFTimeInterval duration = CACurrentMediaTime() - self.silentStartTime;
        [self applySavedTimeForSilenceDuration:duration];
    }
    if (!item) {
        return;
    }
    [self.detector stop];
    self.detector = [[YSSSilenceDetector alloc] initWithPlayerItem:item];
    self.detector.delegate = self;
    [self.detector start];
    self.isSilent = NO;
    self.silentStartTime = 0;
    [self refreshPlaybackRateForCurrentState];
}

- (void)resetLastVideoSaved {
    [[YSSPreferences sharedInstance] setLastSaved:0.0];
}

- (void)refreshPlaybackRateForCurrentState {
    if (!self.player) {
        return;
    }
    YSSPreferences *preferences = [YSSPreferences sharedInstance];
    float targetRate = preferences.playbackSpeed;
    if (self.enabled && self.isSilent) {
        targetRate = preferences.silenceSpeed;
    }
    if (self.player.rate != targetRate) {
        self.player.rate = targetRate;
    }
}

- (void)handleSilenceChange:(BOOL)isSilent {
    if (!self.enabled) {
        return;
    }

    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastSwitchTime < 0.35) {
        return;
    }

    if (isSilent == self.isSilent) {
        return;
    }

    self.isSilent = isSilent;
    self.lastSwitchTime = now;

    if (isSilent) {
        self.silentStartTime = now;
    } else if (self.silentStartTime > 0) {
        CFTimeInterval duration = now - self.silentStartTime;
        [self applySavedTimeForSilenceDuration:duration];
        self.silentStartTime = 0;
    }

    [self refreshPlaybackRateForCurrentState];
}

- (void)applySavedTimeForSilenceDuration:(CFTimeInterval)duration {
    if (duration <= 0) {
        return;
    }
    YSSPreferences *preferences = [YSSPreferences sharedInstance];
    double playbackSpeed = preferences.playbackSpeed;
    double silenceSpeed = preferences.silenceSpeed;
    if (silenceSpeed <= 0 || playbackSpeed <= 0) {
        return;
    }
    double saved = (duration / playbackSpeed) - (duration / silenceSpeed);
    if (saved <= 0) {
        return;
    }
    [preferences addToTotalSaved:saved];
    [preferences setLastSaved:preferences.lastSaved + saved];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"currentItem"]) {
        AVPlayerItem *item = change[NSKeyValueChangeNewKey];
        if ((id)item == [NSNull null]) {
            item = nil;
        }
        [self resetLastVideoSaved];
        [self attachDetectorToItem:item];
    }
}

- (void)silenceDetectorDidDetectSilence:(BOOL)isSilent rms:(float)rms {
    (void)rms;
    [self handleSilenceChange:isSilent];
}

- (void)dealloc {
    if (self.observedPlayer) {
        @try {
            [self.observedPlayer removeObserver:self forKeyPath:@"currentItem"];
        } @catch (NSException *exception) {
        }
    }
}

@end
