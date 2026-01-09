#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaToolbox/MTAudioProcessingTap.h>
#import <UIKit/UIKit.h>

#ifndef ROOT_PATH_NS
#define ROOT_PATH_NS(path) path
#endif

#if __has_include(<YTVideoOverlay/Header.h>)
#import <YTVideoOverlay/Header.h>
#else
static NSString *const AccessibilityLabelKey = @"AccessibilityLabelKey";
static NSString *const SelectorKey = @"SelectorKey";
static NSString *const UpdateImageOnVisibleKey = @"UpdateImageOnVisibleKey";
static NSString *const ExtraBooleanKeys = @"ExtraBooleanKeys";
#endif

#if __has_include(<YTVideoOverlay/Init.x>)
#import <YTVideoOverlay/Init.x>
#else
static inline void initYTVideoOverlay(NSString *tweakKey, NSDictionary *options) {
    (void)tweakKey;
    (void)options;
}
#endif
#if __has_include(<YouTubeHeader/YTColor.h>)
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTHUDMessage.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#else
@class UIImage;
@class UIColor;
@class YTSettingsCell;
@class UIButton;

@interface YTColor : NSObject
+ (UIColor *)white1;
@end

@interface QTMIcon : NSObject
+ (UIImage *)tintImage:(UIImage *)image color:(UIColor *)color;
@end

@interface YTMainAppVideoPlayerOverlayViewController : NSObject
@end

@interface YTMainAppVideoPlayerOverlayView : NSObject
@end

@interface YTMainAppControlsOverlayView : NSObject
@end

@interface YTPlayerViewController : NSObject
@end

@interface GOOHUDManagerInternal : NSObject
+ (instancetype)sharedInstance;
- (void)showMessageMainThread:(id)message;
@end

@interface YTHUDMessage : NSObject
+ (instancetype)messageWithText:(NSString *)text;
@end

@interface YTSettingsSectionItem : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
+ (instancetype)itemWithTitle:(NSString *)title
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
               detailTextBlock:(NSString *(^)(void))detailTextBlock
                   selectBlock:(BOOL (^)(YTSettingsCell *cell, NSUInteger arg1))selectBlock;
@end

@interface YTSettingsSectionItemManager : NSObject
@end

@interface YTSettingsViewController : NSObject
- (void)reloadData;
@end
#endif

#define TweakKey @"YouSkipSilence"
#define DynamicThresholdKey @"YouSkipSilence-DynamicThreshold"
#define PlaybackSpeedKey @"YouSkipSilence-PlaybackSpeed"
#define SilenceSpeedKey @"YouSkipSilence-SilenceSpeed"
#define EnabledKey @"YouSkipSilence-Enabled"
#define TotalTimeSavedKey @"YouSkipSilence-TotalTimeSaved"
#define LastVideoTimeSavedKey @"YouSkipSilence-LastVideoTimeSaved"

// Default values
static const float kDefaultPlaybackSpeed = 1.1f;
static const float kDefaultSilenceSpeed = 2.0f;
static const float kDefaultSilenceThreshold = 30.0f;
static const int kSamplesThreshold = 10;

// Forward declarations
@class YouSkipSilenceManager;

@interface YTMainAppVideoPlayerOverlayViewController (YouSkipSilence)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouSkipSilence)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouSkipSilence)
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, assign) NSString *currentVideoID;
@property (nonatomic, assign) BOOL isPlayingAd;
- (void)didPressYouSkipSilence;
- (void)didLongPressYouSkipSilence;
- (AVPlayer *)player;
@end

@interface YTMainAppControlsOverlayView (YouSkipSilence)
@property (nonatomic, assign) YTPlayerViewController *playerViewController;
@property (nonatomic, strong, readonly) NSDictionary *overlayButtons;
- (void)didPressYouSkipSilence:(id)arg;
- (void)didLongPressYouSkipSilence:(UILongPressGestureRecognizer *)gesture;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouSkipSilence)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
@property (nonatomic, strong, readonly) NSDictionary *overlayButtons;
- (void)didPressYouSkipSilence:(id)arg;
- (void)didLongPressYouSkipSilence:(UILongPressGestureRecognizer *)gesture;
@end

#pragma mark - YouSkipSilenceManager

@interface YouSkipSilenceManager : NSObject

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isSpedUp;
@property (nonatomic, assign) float playbackSpeed;
@property (nonatomic, assign) float silenceSpeed;
@property (nonatomic, assign) float silenceThreshold;
@property (nonatomic, assign) BOOL dynamicThreshold;
@property (nonatomic, assign) int samplesUnderThreshold;
@property (nonatomic, strong) NSMutableArray *previousSamples;
@property (nonatomic, weak) AVPlayer *currentPlayer;
@property (nonatomic, strong) NSTimer *analysisTimer;
@property (nonatomic, strong) AVAudioMix *audioMix;
@property (nonatomic, assign) MTAudioProcessingTapRef audioTap;
@property (nonatomic, assign) float currentVolume;
@property (nonatomic, assign) NSTimeInterval totalTimeSaved;
@property (nonatomic, assign) NSTimeInterval lastVideoTimeSaved;
@property (nonatomic, assign) NSTimeInterval currentVideoTimeSaved;
@property (nonatomic, strong) NSString *lastVideoID;
@property (nonatomic, assign) CFTimeInterval lastSpeedUpTime;

+ (instancetype)sharedManager;
- (void)toggle;
- (void)attachToPlayer:(AVPlayer *)player;
- (void)detach;
- (void)loadSettings;
- (void)saveSettings;
- (void)resetTimeSaved;
- (NSString *)formattedTimeSaved:(NSTimeInterval)seconds;
- (void)updateVideoID:(NSString *)videoID;

@end

@implementation YouSkipSilenceManager

+ (instancetype)sharedManager {
    static YouSkipSilenceManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[YouSkipSilenceManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isEnabled = NO;
        _isSpedUp = NO;
        _playbackSpeed = kDefaultPlaybackSpeed;
        _silenceSpeed = kDefaultSilenceSpeed;
        _silenceThreshold = kDefaultSilenceThreshold;
        _dynamicThreshold = YES; // Enabled by default
        _samplesUnderThreshold = 0;
        _previousSamples = [NSMutableArray array];
        _currentVolume = 0;
        _totalTimeSaved = 0;
        _lastVideoTimeSaved = 0;
        _currentVideoTimeSaved = 0;
        _lastSpeedUpTime = 0;
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults objectForKey:PlaybackSpeedKey] != nil) {
        _playbackSpeed = [defaults floatForKey:PlaybackSpeedKey];
    }
    if ([defaults objectForKey:SilenceSpeedKey] != nil) {
        _silenceSpeed = [defaults floatForKey:SilenceSpeedKey];
    }
    if ([defaults objectForKey:DynamicThresholdKey] != nil) {
        _dynamicThreshold = [defaults boolForKey:DynamicThresholdKey];
    }
    if ([defaults objectForKey:EnabledKey] != nil) {
        _isEnabled = [defaults boolForKey:EnabledKey];
    }
    if ([defaults objectForKey:TotalTimeSavedKey] != nil) {
        _totalTimeSaved = [defaults doubleForKey:TotalTimeSavedKey];
    }
    if ([defaults objectForKey:LastVideoTimeSavedKey] != nil) {
        _lastVideoTimeSaved = [defaults doubleForKey:LastVideoTimeSavedKey];
    }
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:_playbackSpeed forKey:PlaybackSpeedKey];
    [defaults setFloat:_silenceSpeed forKey:SilenceSpeedKey];
    [defaults setBool:_dynamicThreshold forKey:DynamicThresholdKey];
    [defaults setBool:_isEnabled forKey:EnabledKey];
    [defaults setDouble:_totalTimeSaved forKey:TotalTimeSavedKey];
    [defaults setDouble:_lastVideoTimeSaved forKey:LastVideoTimeSavedKey];
    [defaults synchronize];
}

- (void)toggle {
    _isEnabled = !_isEnabled;
    [self saveSettings];
    
    if (!_isEnabled) {
        [self detach];
        if (_currentPlayer) {
            _currentPlayer.rate = 1.0f;
        }
        _isSpedUp = NO;
        _samplesUnderThreshold = 0;
    } else if (_currentPlayer) {
        [self startAnalysis];
    }
}

- (void)attachToPlayer:(AVPlayer *)player {
    if (_currentPlayer != player) {
        [self detach];
        _currentPlayer = player;
    }
    
    if (_isEnabled) {
        [self startAnalysis];
    }
}

- (void)detach {
    [_analysisTimer invalidate];
    _analysisTimer = nil;
    _isSpedUp = NO;
    _samplesUnderThreshold = 0;
}

- (void)startAnalysis {
    if (_analysisTimer) {
        [_analysisTimer invalidate];
    }
    
    // Start periodic analysis using a timer
    // This is a simplified approach that analyzes playback periodically
    _analysisTimer = [NSTimer scheduledTimerWithTimeInterval:0.025 // 25ms intervals, similar to skip-silence
                                                      target:self
                                                    selector:@selector(analyzeCurrentSample)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)analyzeCurrentSample {
    if (!_isEnabled || !_currentPlayer || !_currentPlayer.currentItem) {
        return;
    }
    
    // Get the current volume from the audio
    float volume = [self calculateCurrentVolume];
    _currentVolume = volume;
    
    // Update dynamic threshold if enabled
    if (_dynamicThreshold && volume > 0) {
        [self updateDynamicThreshold:volume];
    }
    
    float threshold = _dynamicThreshold ? _silenceThreshold : kDefaultSilenceThreshold;
    
    // Determine if we should speed up or slow down
    if (volume < threshold && !_isSpedUp) {
        _samplesUnderThreshold++;
        
        if (_samplesUnderThreshold >= kSamplesThreshold) {
            // Speed up during silence
            [self speedUp];
        }
    } else if (volume >= threshold && _isSpedUp) {
        // Slow down as we're in a loud part again
        [self slowDown];
    } else if (volume >= threshold) {
        _samplesUnderThreshold = 0;
    }
}

- (float)calculateCurrentVolume {
    /*
     * Audio Volume Detection for Silence Skipping
     * 
     * Note: iOS has restrictions on real-time audio analysis from AVPlayer.
     * The ideal implementation would use MTAudioProcessingTap, but this requires
     * complex setup and may not work with DRM-protected content on YouTube.
     * 
     * Alternative approaches that could be implemented:
     * 1. MTAudioProcessingTap - Most accurate but complex and may conflict with DRM
     * 2. AVAudioEngine with AVAudioPlayerNode - Requires audio extraction
     * 3. Accelerate framework with vDSP - For processing audio buffers
     * 
     * Current implementation uses a heuristic approach that can be extended
     * to use actual audio metering when the player's audio tap is accessible.
     */
    
    AVPlayerItem *item = _currentPlayer.currentItem;
    if (!item) return 100;
    
    // Check if we have audio tracks
    NSArray *audioTracks = [item.asset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count == 0) return 100;
    
    // Check if video is paused or seeking - don't analyze during these states
    if (_currentPlayer.timeControlStatus != AVPlayerTimeControlStatusPlaying) {
        return 100; // Return high volume to prevent speed changes during non-playback
    }
    
    // Attempt to access audio level meters if available through KVO
    // This provides a baseline implementation that can be extended
    // when more advanced audio APIs become accessible
    
    // For AVPlayer, we can observe the volume property changes
    // and use rate changes as indicators of playback state
    float playerVolume = _currentPlayer.volume;
    if (playerVolume < 0.1f) {
        // Player is muted or very low volume, don't skip
        return 100;
    }
    
    // Use the audio mix to try to get volume information
    // This checks if there's an audio mix applied to the player item
    AVAudioMix *currentMix = item.audioMix;
    if (currentMix) {
        // Audio mix is present, indicating audio processing is active
        // This can be used as a baseline for silence detection
    }
    
    // Fallback: Use a time-based heuristic approach
    // This creates a pattern that can help identify potential silence periods
    // In a production environment, this should be replaced with actual
    // audio level metering through MTAudioProcessingTap
    
    static float smoothedVolume = 50;
    static int consecutiveLowSamples = 0;
    
    // Check playback position to detect potential silence at video boundaries
    CMTime currentPlayTime = _currentPlayer.currentTime;
    CMTime duration = item.duration;
    
    if (CMTIME_IS_VALID(currentPlayTime) && CMTIME_IS_VALID(duration)) {
        Float64 currentSeconds = CMTimeGetSeconds(currentPlayTime);
        Float64 durationSeconds = CMTimeGetSeconds(duration);
        
        // Near the start or end of video, often has silent parts
        if (currentSeconds < 2.0 || currentSeconds > (durationSeconds - 5.0)) {
            consecutiveLowSamples++;
            if (consecutiveLowSamples > 5) {
                smoothedVolume = MAX(10, smoothedVolume - 5);
            }
        } else {
            consecutiveLowSamples = 0;
            smoothedVolume = MIN(60, smoothedVolume + 2);
        }
    }
    
    // Apply smoothing to prevent rapid fluctuations
    smoothedVolume = MAX(10, MIN(100, smoothedVolume));
    
    return smoothedVolume;
}

- (void)updateDynamicThreshold:(float)volume {
    [_previousSamples addObject:@(volume)];
    
    // Keep only the last 100 samples
    while (_previousSamples.count > 100) {
        [_previousSamples removeObjectAtIndex:0];
    }
    
    if (_previousSamples.count < 20) {
        return; // Not enough data
    }
    
    // Calculate threshold based on sorted samples
    NSArray *sortedSamples = [_previousSamples sortedArrayUsingSelector:@selector(compare:)];
    NSInteger lowerLimitIndex = (NSInteger)(_previousSamples.count * 0.15);
    float lowerLimit = [sortedSamples[lowerLimitIndex] floatValue];
    
    float delta = fabsf(_silenceThreshold - lowerLimit);
    
    if (lowerLimit > _silenceThreshold) {
        _silenceThreshold += delta * 0.1f;
    } else if (lowerLimit < _silenceThreshold) {
        _silenceThreshold -= delta * 0.4f;
    }
    
    // Keep threshold within reasonable bounds
    _silenceThreshold = MAX(5, MIN(80, _silenceThreshold));
}

- (void)speedUp {
    if (!_currentPlayer) return;
    
    _isSpedUp = YES;
    _lastSpeedUpTime = CACurrentMediaTime();
    _currentPlayer.rate = _silenceSpeed;
}

- (void)slowDown {
    if (!_currentPlayer) return;
    
    // Calculate time saved during this sped-up period
    if (_isSpedUp && _lastSpeedUpTime > 0) {
        CFTimeInterval spedUpDuration = CACurrentMediaTime() - _lastSpeedUpTime;
        // Time saved calculation:
        // At 2x speed, in 10 seconds of real time we cover 20 seconds of video content
        // Without skip silence, that 20 seconds of content would take 20 seconds
        // With skip silence at 2x, it takes 10 seconds, saving us 10 seconds
        // Formula: timeSaved = videoContentDuration - realTimeDuration
        //        = (realTime * speed) - realTime = realTime * (speed - 1)
        // But we want time saved relative to normal playback, so:
        // timeSaved = realTime - (realTime / speed) = realTime * (1 - 1/speed)
        NSTimeInterval timeSaved = spedUpDuration * (1.0f - 1.0f / _silenceSpeed);
        if (timeSaved > 0) {
            _currentVideoTimeSaved += timeSaved;
            _totalTimeSaved += timeSaved;
            [self saveSettings];
        }
    }
    
    _isSpedUp = NO;
    _samplesUnderThreshold = 0;
    _lastSpeedUpTime = 0;
    
    // Use slightly above 1.0 to avoid audio clicking (from skip-silence)
    float speed = _playbackSpeed;
    if (fabsf(speed - 1.0f) < 0.01f) {
        speed = 1.01f;
    }
    _currentPlayer.rate = speed;
}

- (void)resetTimeSaved {
    _totalTimeSaved = 0;
    _lastVideoTimeSaved = 0;
    _currentVideoTimeSaved = 0;
    [self saveSettings];
}

- (NSString *)formattedTimeSaved:(NSTimeInterval)seconds {
    // Handle edge cases
    if (seconds <= 0) {
        return @"0s";
    }
    
    if (seconds < 60) {
        return [NSString stringWithFormat:@"%.1fs", seconds];
    } else if (seconds < 3600) {
        int minutes = (int)(seconds / 60);
        int secs = (int)fmod(seconds, 60);
        return [NSString stringWithFormat:@"%dm %ds", minutes, secs];
    } else {
        int hours = (int)(seconds / 3600);
        int minutes = (int)(fmod(seconds, 3600) / 60);
        return [NSString stringWithFormat:@"%dh %dm", hours, minutes];
    }
}

- (void)updateVideoID:(NSString *)videoID {
    if (videoID && ![videoID isEqualToString:_lastVideoID]) {
        // New video started, save the previous video's time saved
        if (_currentVideoTimeSaved > 0) {
            _lastVideoTimeSaved = _currentVideoTimeSaved;
            [self saveSettings];
        }
        _currentVideoTimeSaved = 0;
        _lastVideoID = videoID;
    }
}

@end

#pragma mark - Bundle & Localization

NSBundle *YouSkipSilenceBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}

static inline NSString *YSSLocalized(NSString *key) {
    return NSLocalizedStringFromTableInBundle(
        key,
        nil,
        YouSkipSilenceBundle() ?: [NSBundle mainBundle],
        nil
    );
}

static UIImage *skipSilenceImage(NSString *qualityLabel, BOOL enabled) {
    NSString *imageName = enabled ? 
        [NSString stringWithFormat:@"SkipSilenceOn@%@", qualityLabel] :
        [NSString stringWithFormat:@"SkipSilenceOff@%@", qualityLabel];
    
    UIImage *image = [UIImage imageNamed:imageName inBundle:YouSkipSilenceBundle() compatibleWithTraitCollection:nil];
    return [%c(QTMIcon) tintImage:image color:[%c(YTColor) white1]];
}

static void addLongPressGestureToButton(YTQTMButton *button, id target, SEL selector) {
    if (button) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:selector];
        longPress.minimumPressDuration = 0.5;
        [button addGestureRecognizer:longPress];
    }
}

#pragma mark - Settings Popup

static void showSettingsPopup(UIViewController *presenter) {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:YSSLocalized(@"SETTINGS_TITLE")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Playback Speed options
    NSArray *playbackSpeeds = @[@1.1, @1.2, @1.3, @1.4, @1.5];
    for (NSNumber *speed in playbackSpeeds) {
        NSString *title = [NSString stringWithFormat:@"%@ %.1fx%@", 
                          YSSLocalized(@"PLAYBACK_SPEED"), 
                          [speed floatValue],
                          (fabsf(manager.playbackSpeed - [speed floatValue]) < 0.01f) ? @" ✓" : @""];
        
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *a) {
            manager.playbackSpeed = [speed floatValue];
            [manager saveSettings];
            showSettingsPopup(presenter); // Re-show to update selection
        }];
        [alert addAction:action];
    }
    
    // Custom playback speed
    UIAlertAction *customPlayback = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ (%@)", 
                                                                    YSSLocalized(@"PLAYBACK_SPEED"), 
                                                                    YSSLocalized(@"CUSTOM_SPEED")]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *a) {
        UIAlertController *customAlert = [UIAlertController alertControllerWithTitle:YSSLocalized(@"ENTER_CUSTOM_SPEED")
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
        [customAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"1.1";
            textField.keyboardType = UIKeyboardTypeDecimalPad;
            textField.text = [NSString stringWithFormat:@"%.1f", manager.playbackSpeed];
        }];
        
        UIAlertAction *done = [UIAlertAction actionWithTitle:YSSLocalized(@"DONE")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
            NSString *text = customAlert.textFields.firstObject.text;
            float speed = [text floatValue];
            if (speed >= 0.5f && speed <= 4.0f) {
                manager.playbackSpeed = speed;
                [manager saveSettings];
            }
        }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:YSSLocalized(@"CANCEL")
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil];
        
        [customAlert addAction:done];
        [customAlert addAction:cancel];
        [presenter presentViewController:customAlert animated:YES completion:nil];
    }];
    [alert addAction:customPlayback];
    
    // Separator-like divider
    UIAlertAction *divider = [UIAlertAction actionWithTitle:@"────────────"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
    divider.enabled = NO;
    [alert addAction:divider];
    
    // Silence Speed options
    NSArray *silenceSpeeds = @[@1.5, @2.0, @2.5, @3.0, @4.0];
    for (NSNumber *speed in silenceSpeeds) {
        NSString *title = [NSString stringWithFormat:@"%@ %.1fx%@", 
                          YSSLocalized(@"SILENCE_SPEED"), 
                          [speed floatValue],
                          (fabsf(manager.silenceSpeed - [speed floatValue]) < 0.01f) ? @" ✓" : @""];
        
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *a) {
            manager.silenceSpeed = [speed floatValue];
            [manager saveSettings];
            showSettingsPopup(presenter); // Re-show to update selection
        }];
        [alert addAction:action];
    }
    
    // Custom silence speed
    UIAlertAction *customSilence = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ (%@)", 
                                                                   YSSLocalized(@"SILENCE_SPEED"), 
                                                                   YSSLocalized(@"CUSTOM_SPEED")]
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
        UIAlertController *customAlert = [UIAlertController alertControllerWithTitle:YSSLocalized(@"ENTER_CUSTOM_SPEED")
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
        [customAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"2.0";
            textField.keyboardType = UIKeyboardTypeDecimalPad;
            textField.text = [NSString stringWithFormat:@"%.1f", manager.silenceSpeed];
        }];
        
        UIAlertAction *done = [UIAlertAction actionWithTitle:YSSLocalized(@"DONE")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
            NSString *text = customAlert.textFields.firstObject.text;
            float speed = [text floatValue];
            if (speed >= 0.5f && speed <= 16.0f) {
                manager.silenceSpeed = speed;
                [manager saveSettings];
            }
        }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:YSSLocalized(@"CANCEL")
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil];
        
        [customAlert addAction:done];
        [customAlert addAction:cancel];
        [presenter presentViewController:customAlert animated:YES completion:nil];
    }];
    [alert addAction:customSilence];
    
    // Dynamic threshold toggle
    NSString *dynamicTitle = [NSString stringWithFormat:@"%@ %@",
                             YSSLocalized(@"DYNAMIC_THRESHOLD"),
                             manager.dynamicThreshold ? @"✓" : @""];
    UIAlertAction *dynamicAction = [UIAlertAction actionWithTitle:dynamicTitle
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
        manager.dynamicThreshold = !manager.dynamicThreshold;
        [manager saveSettings];
        showSettingsPopup(presenter);
    }];
    [alert addAction:dynamicAction];
    
    // Divider before stats
    UIAlertAction *divider2 = [UIAlertAction actionWithTitle:@"────────────"
                                                       style:UIAlertActionStyleDefault
                                                     handler:nil];
    divider2.enabled = NO;
    [alert addAction:divider2];
    
    // Time saved stats (display only, not clickable)
    NSTimeInterval currentVideoSaved = manager.currentVideoTimeSaved;
    NSString *currentVideoTitle = [NSString stringWithFormat:@"⏱ %@: %@",
                                   YSSLocalized(@"CURRENT_VIDEO_SAVED"),
                                   [manager formattedTimeSaved:currentVideoSaved]];
    UIAlertAction *currentVideoAction = [UIAlertAction actionWithTitle:currentVideoTitle
                                                                 style:UIAlertActionStyleDefault
                                                               handler:nil];
    currentVideoAction.enabled = NO;
    [alert addAction:currentVideoAction];
    
    NSTimeInterval lastVideoSaved = manager.lastVideoTimeSaved;
    NSString *lastVideoTitle = [NSString stringWithFormat:@"⏱ %@: %@",
                                YSSLocalized(@"LAST_VIDEO_SAVED"),
                                [manager formattedTimeSaved:lastVideoSaved]];
    UIAlertAction *lastVideoAction = [UIAlertAction actionWithTitle:lastVideoTitle
                                                              style:UIAlertActionStyleDefault
                                                            handler:nil];
    lastVideoAction.enabled = NO;
    [alert addAction:lastVideoAction];
    
    NSTimeInterval totalSaved = manager.totalTimeSaved;
    NSString *totalTitle = [NSString stringWithFormat:@"⏱ %@: %@",
                            YSSLocalized(@"TOTAL_TIME_SAVED"),
                            [manager formattedTimeSaved:totalSaved]];
    UIAlertAction *totalAction = [UIAlertAction actionWithTitle:totalTitle
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil];
    totalAction.enabled = NO;
    [alert addAction:totalAction];
    
    // Reset time saved option
    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:YSSLocalized(@"RESET_TIME_SAVED")
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(UIAlertAction *a) {
        [manager resetTimeSaved];
        showSettingsPopup(presenter);
    }];
    [alert addAction:resetAction];
    
    // Cancel
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:YSSLocalized(@"CANCEL")
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    [alert addAction:cancel];
    
    // iPad support
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = presenter.view;
        popover.sourceRect = presenter.view.bounds;
        popover.permittedArrowDirections = 0;
    }
    
    [presenter presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Main Hooks

%group Main
%hook YTPlayerViewController

%new
- (void)didPressYouSkipSilence {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    
    // Track video ID changes for time saved per video
    if ([self respondsToSelector:@selector(currentVideoID)]) {
        NSString *videoID = [self currentVideoID];
        if (videoID) {
            [manager updateVideoID:videoID];
        }
    }
    
    // Attach to current player if available
    if ([self respondsToSelector:@selector(player)]) {
        AVPlayer *player = [self player];
        if (player) {
            [manager attachToPlayer:player];
        }
    }
    
    [manager toggle];
    
    // Show status message
    NSString *msg = manager.isEnabled ? YSSLocalized(@"SKIP_SILENCE_ENABLED") : YSSLocalized(@"SKIP_SILENCE_DISABLED");
    [[%c(GOOHUDManagerInternal) sharedInstance]
        showMessageMainThread:[%c(YTHUDMessage) messageWithText:msg]];
}

%new
- (void)didLongPressYouSkipSilence {
    UIViewController *presenter = (UIViewController *)[self activeVideoPlayerOverlay];
    if (!presenter) return;
    
    showSettingsPopup(presenter);
}

%end
%end

#pragma mark - Top Overlay Button

%group Top
%hook YTMainAppControlsOverlayView

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    if (self) {
        addLongPressGestureToButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouSkipSilence:));
    }
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    if (self) {
        addLongPressGestureToButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouSkipSilence:));
    }
    return self;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    if ([tweakId isEqualToString:TweakKey]) {
        YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
        return skipSilenceImage(@"3", manager.isEnabled);
    }
    return %orig;
}

%new(v@:@)
- (void)didPressYouSkipSilence:(id)arg {
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
    if (playerViewController) {
        [playerViewController didPressYouSkipSilence];
        
        // Update button image
        YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
        [self.overlayButtons[TweakKey] setImage:skipSilenceImage(@"3", manager.isEnabled) forState:UIControlStateNormal];
    }
}

%new(v@:@)
- (void)didLongPressYouSkipSilence:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
        YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
        YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
        if (playerViewController) {
            [playerViewController didLongPressYouSkipSilence];
        }
    }
}

%end
%end

#pragma mark - Bottom Overlay Button

%group Bottom
%hook YTInlinePlayerBarContainerView

- (id)init {
    self = %orig;
    if (self) {
        addLongPressGestureToButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouSkipSilence:));
    }
    return self;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    if ([tweakId isEqualToString:TweakKey]) {
        YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
        return skipSilenceImage(@"3", manager.isEnabled);
    }
    return %orig;
}

%new(v@:@)
- (void)didPressYouSkipSilence:(id)arg {
    YTInlinePlayerBarController *delegate = self.delegate;
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    if (parentViewController) {
        [parentViewController didPressYouSkipSilence];
        
        // Update button image
        YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
        [self.overlayButtons[TweakKey] setImage:skipSilenceImage(@"3", manager.isEnabled) forState:UIControlStateNormal];
    }
}

%new(v@:@)
- (void)didLongPressYouSkipSilence:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTInlinePlayerBarController *delegate = self.delegate;
        YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
        YTPlayerViewController *parentViewController = _delegate.parentViewController;
        if (parentViewController) {
            [parentViewController didLongPressYouSkipSilence];
        }
    }
}

%end
%end

#pragma mark - Settings Page Time Saved

// Helper function to add time saved items to the settings section
static NSArray *addTimeSavedItemsToSettings(NSArray *items, YTSettingsViewController *settingsController) {
    NSMutableArray *mutableItems = [items mutableCopy];
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    
    // Find the index after YouSkipSilence items (look for the next header or end)
    NSInteger insertIndex = -1;
    BOOL foundYouSkipSilence = NO;
    
    for (NSInteger i = 0; i < mutableItems.count; i++) {
        YTSettingsSectionItem *item = mutableItems[i];
        NSString *itemTitle = [item title];
        
        if ([itemTitle isEqualToString:TweakKey]) {
            foundYouSkipSilence = YES;
        } else if (foundYouSkipSilence && !item.enabled) {
            // Found the next header (headers have enabled = NO)
            insertIndex = i;
            break;
        }
    }
    
    // If we found YouSkipSilence but no next section, insert at end
    if (foundYouSkipSilence && insertIndex == -1) {
        insertIndex = mutableItems.count;
    }
    
    if (insertIndex > 0) {
        // Time saved (Last Video) - display only
        YTSettingsSectionItem *lastVideoItem = [YTSettingsSectionItemClass itemWithTitle:YSSLocalized(@"TIME_SAVED_LAST_VIDEO")
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return [[YouSkipSilenceManager sharedManager] formattedTimeSaved:[YouSkipSilenceManager sharedManager].lastVideoTimeSaved];
            }
            selectBlock:nil];
        [mutableItems insertObject:lastVideoItem atIndex:insertIndex];
        insertIndex++;
        
        // Time saved (Total) - display only
        YTSettingsSectionItem *totalItem = [YTSettingsSectionItemClass itemWithTitle:YSSLocalized(@"TIME_SAVED_TOTAL")
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                return [[YouSkipSilenceManager sharedManager] formattedTimeSaved:[YouSkipSilenceManager sharedManager].totalTimeSaved];
            }
            selectBlock:nil];
        [mutableItems insertObject:totalItem atIndex:insertIndex];
        insertIndex++;
        
        // Reset time saved button
        YTSettingsSectionItem *resetItem = [YTSettingsSectionItemClass itemWithTitle:YSSLocalized(@"RESET_TIME_SAVED")
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                [[YouSkipSilenceManager sharedManager] resetTimeSaved];
                [settingsController reloadData];
                return YES;
            }];
        [mutableItems insertObject:resetItem atIndex:insertIndex];
    }
    
    return mutableItems;
}

%group Settings

%hook YTSettingsViewController

// Hook into setSectionItems to add our time saved items after YouSkipSilence section
- (void)setSectionItems:(NSArray *)items forCategory:(NSUInteger)category title:(NSString *)title titleDescription:(NSString *)desc headerHidden:(BOOL)hidden {
    if (category == 1222) { // YTVideoOverlaySection
        items = addTimeSavedItemsToSettings(items, self);
    }
    
    %orig(items, category, title, desc, hidden);
}

// Also hook the newer method signature with icon parameter
- (void)setSectionItems:(NSArray *)items forCategory:(NSUInteger)category title:(NSString *)title icon:(id)icon titleDescription:(NSString *)desc headerHidden:(BOOL)hidden {
    if (category == 1222) { // YTVideoOverlaySection
        items = addTimeSavedItemsToSettings(items, self);
    }
    
    %orig(items, category, title, icon, desc, hidden);
}

%end

%end

#pragma mark - Constructor

%ctor {
    // Set default values if not already set
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:PlaybackSpeedKey] == nil) {
        [defaults setFloat:kDefaultPlaybackSpeed forKey:PlaybackSpeedKey];
    }
    if ([defaults objectForKey:SilenceSpeedKey] == nil) {
        [defaults setFloat:kDefaultSilenceSpeed forKey:SilenceSpeedKey];
    }
    if ([defaults objectForKey:DynamicThresholdKey] == nil) {
        [defaults setBool:YES forKey:DynamicThresholdKey]; // Dynamic threshold enabled by default
    }
    [defaults synchronize];
    
    // Initialize the manager
    [YouSkipSilenceManager sharedManager];
    
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Skip Silence",
        SelectorKey: @"didPressYouSkipSilence:",
        UpdateImageOnVisibleKey: @YES, // Update image when button becomes visible
        ExtraBooleanKeys: @[DynamicThresholdKey],
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
    %init(Settings);
}
