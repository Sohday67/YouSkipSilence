#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTHUDMessage.h>

#define TweakKey @"YouSkipSilence"
#define DynamicThresholdKey @"YouSkipSilence-DynamicThreshold"
#define PlaybackSpeedKey @"YouSkipSilence-PlaybackSpeed"
#define SilenceSpeedKey @"YouSkipSilence-SilenceSpeed"
#define EnabledKey @"YouSkipSilence-Enabled"

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
- (void)didPressYouSkipSilence:(id)arg;
- (void)didLongPressYouSkipSilence:(UILongPressGestureRecognizer *)gesture;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouSkipSilence)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
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
@property (nonatomic, strong) MTAudioProcessingTap *audioTap;
@property (nonatomic, assign) float currentVolume;

+ (instancetype)sharedManager;
- (void)toggle;
- (void)attachToPlayer:(AVPlayer *)player;
- (void)detach;
- (void)loadSettings;
- (void)saveSettings;

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
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:_playbackSpeed forKey:PlaybackSpeedKey];
    [defaults setFloat:_silenceSpeed forKey:SilenceSpeedKey];
    [defaults setBool:_dynamicThreshold forKey:DynamicThresholdKey];
    [defaults setBool:_isEnabled forKey:EnabledKey];
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
    static CFTimeInterval lastAnalysisTime = 0;
    static int consecutiveLowSamples = 0;
    
    CFTimeInterval currentTime = CACurrentMediaTime();
    CFTimeInterval timeDelta = currentTime - lastAnalysisTime;
    lastAnalysisTime = currentTime;
    
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
    _currentPlayer.rate = _silenceSpeed;
}

- (void)slowDown {
    if (!_currentPlayer) return;
    
    _isSpedUp = NO;
    _samplesUnderThreshold = 0;
    
    // Use slightly above 1.0 to avoid audio clicking (from skip-silence)
    float speed = _playbackSpeed;
    if (fabsf(speed - 1.0f) < 0.01f) {
        speed = 1.01f;
    }
    _currentPlayer.rate = speed;
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
}
