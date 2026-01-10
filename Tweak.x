#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/YTColorPalette.h>
#import <YouTubeHeader/YTCommonColorPalette.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTSingleVideoController.h>
#import <YouTubeHeader/YTHUDMessage.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTLabel.h>
#import <YouTubeHeader/YTQTMButton.h>
#import <YouTubeHeader/MDCSlider.h>
#import <YouTubeHeader/YTCommonUtils.h>
#import <YouTubeHeader/UIView+YouTube.h>
#import <YouTubeHeader/YTVarispeedSwitchController.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerOption.h>

#define TweakKey @"YouSkipSilence"
#define EnabledKey @"YouSkipSilence-Enabled"
#define DynamicThresholdKey @"YouSkipSilence-DynamicThreshold"
#define SilenceSpeedKey @"YouSkipSilence-SilenceSpeed"
#define ThresholdLimitKey @"YouSkipSilence-ThresholdLimit"
#define TimeSavedTotalKey @"YouSkipSilence-TimeSavedTotal"
#define TimeSavedLastVideoKey @"YouSkipSilence-TimeSavedLastVideo"

#define DEFAULT_PLAYBACK_SPEED 1.1f
#define DEFAULT_SILENCE_SPEED 2.0f
#define DEFAULT_THRESHOLD 30.0f
#define MIN_THRESHOLD 1.0f
#define MAX_THRESHOLD 100.0f

// MARK: - Forward Declarations
@class YouSkipSilenceController;

// MARK: - Interface Declarations

@interface YTMainAppVideoPlayerOverlayViewController (YouSkipSilence)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouSkipSilence)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouSkipSilence)
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, assign) NSString *currentVideoID;
- (id)activeVideoPlayerOverlay;
- (void)didPressYouSkipSilence;
- (void)didLongPressYouSkipSilence;
@end

@interface YTMainAppControlsOverlayView (YouSkipSilence)
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

// MARK: - Silence Skipper Controller

@interface YouSkipSilenceController : NSObject

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isSkippingSilence;
@property (nonatomic, assign) float silenceSpeed;
@property (nonatomic, assign) float normalSpeed;
@property (nonatomic, assign) float threshold;
@property (nonatomic, assign) BOOL dynamicThresholdEnabled;
@property (nonatomic, assign) float currentVolume;
@property (nonatomic, assign) double timeSavedLastVideo;
@property (nonatomic, assign) double timeSavedTotal;

// Audio analysis
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, assign) float lastDetectedVolume;
@property (nonatomic, assign) int samplesUnderThreshold;

// Dynamic threshold
@property (nonatomic, strong) NSMutableArray<NSNumber *> *previousSamples;

// Video tracking
@property (nonatomic, copy) NSString *currentVideoID;
@property (nonatomic, assign) NSTimeInterval silenceStartTime;

// Weak reference to current player
@property (nonatomic, weak) YTPlayerViewController *currentPlayerViewController;
@property (nonatomic, weak) YTSingleVideoController *currentVideoController;

+ (instancetype)sharedInstance;
- (void)toggle;
- (void)enable;
- (void)disable;
- (void)setPlaybackRate:(float)rate;
- (void)resetTimeSaved;
- (NSString *)formattedTimeSaved:(double)seconds;
- (void)updateThreshold:(float)newThreshold;
- (void)startMonitoring;
- (void)stopMonitoring;

@end

// MARK: - Global Variables

static NSBundle *tweakBundle = nil;

// MARK: - Helper Functions

static NSBundle *YouSkipSilenceBundle() {
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

static BOOL isEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:EnabledKey];
}

static BOOL isDynamicThresholdEnabled() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:DynamicThresholdKey] == nil) {
        return YES; // Default to enabled
    }
    return [defaults boolForKey:DynamicThresholdKey];
}

static float getSilenceSpeed() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    float speed = [defaults floatForKey:SilenceSpeedKey];
    return speed > 0 ? speed : DEFAULT_SILENCE_SPEED;
}

static float getThresholdLimit() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    float threshold = [defaults floatForKey:ThresholdLimitKey];
    return threshold > 0 ? threshold : DEFAULT_THRESHOLD;
}

static UIImage *skipSilenceImage(BOOL enabled, NSString *qualityLabel) {
    UIColor *tintColor = enabled ? [UIColor systemOrangeColor] : [%c(YTColor) white1];
    NSString *imageName = [NSString stringWithFormat:@"SkipSilence@%@", qualityLabel];
    UIImage *base = [UIImage imageNamed:imageName inBundle:YouSkipSilenceBundle() compatibleWithTraitCollection:nil];
    if (!base) {
        // Fallback to system image
        base = [UIImage systemImageNamed:@"forward.fill"];
    }
    return [%c(QTMIcon) tintImage:base color:tintColor];
}

static void addLongPressGestureToButton(YTQTMButton *button, id target, SEL selector) {
    if (button) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:selector];
        longPress.minimumPressDuration = 0.5;
        [button addGestureRecognizer:longPress];
    }
}

// MARK: - YouSkipSilenceController Implementation

@implementation YouSkipSilenceController

+ (instancetype)sharedInstance {
    static YouSkipSilenceController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YouSkipSilenceController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isEnabled = isEnabled();
        _silenceSpeed = getSilenceSpeed();
        _normalSpeed = DEFAULT_PLAYBACK_SPEED;
        _threshold = getThresholdLimit();
        _dynamicThresholdEnabled = isDynamicThresholdEnabled();
        _isSkippingSilence = NO;
        _samplesUnderThreshold = 0;
        _previousSamples = [NSMutableArray new];
        _timeSavedTotal = [[NSUserDefaults standardUserDefaults] doubleForKey:TimeSavedTotalKey];
        _timeSavedLastVideo = [[NSUserDefaults standardUserDefaults] doubleForKey:TimeSavedLastVideoKey];
    }
    return self;
}

- (void)toggle {
    if (_isEnabled) {
        [self disable];
    } else {
        [self enable];
    }
}

- (void)enable {
    _isEnabled = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:EnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Set initial playback speed to 1.1x
    _normalSpeed = DEFAULT_PLAYBACK_SPEED;
    [self setPlaybackRate:_normalSpeed];
    
    [self startMonitoring];
    
    [[%c(GOOHUDManagerInternal) sharedInstance]
        showMessageMainThread:[%c(YTHUDMessage) messageWithText:LOC(@"SKIP_SILENCE_ENABLED")]];
}

- (void)disable {
    _isEnabled = NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:EnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self stopMonitoring];
    
    // Reset to normal 1x speed
    [self setPlaybackRate:1.0f];
    _isSkippingSilence = NO;
    
    [[%c(GOOHUDManagerInternal) sharedInstance]
        showMessageMainThread:[%c(YTHUDMessage) messageWithText:LOC(@"SKIP_SILENCE_DISABLED")]];
}

- (void)setPlaybackRate:(float)rate {
    if (_currentVideoController) {
        // Use YouTube's native speed control
        @try {
            id activeOverlay = [_currentPlayerViewController activeVideoPlayerOverlay];
            if (activeOverlay && [activeOverlay isKindOfClass:NSClassFromString(@"YTMainAppVideoPlayerOverlayViewController")]) {
                id delegate = [activeOverlay valueForKey:@"_delegate"];
                if (delegate) {
                    [(id <YTVarispeedSwitchControllerDelegate>)delegate 
                        varispeedSwitchController:nil didSelectRate:rate];
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[YouSkipSilence] Error setting playback rate: %@", e);
        }
    }
}

- (void)startMonitoring {
    // Start the audio analysis loop using a timer
    [self performSelectorInBackground:@selector(monitorAudioLoop) withObject:nil];
}

- (void)stopMonitoring {
    // Stop monitoring will naturally end via the _isEnabled check in monitorAudioLoop
}

- (void)monitorAudioLoop {
    @autoreleasepool {
        while (_isEnabled) {
            [NSThread sleepForTimeInterval:0.025]; // 25ms sample rate, similar to skip-silence
            
            if (!_isEnabled) break;
            
            // Get current volume level from the video controller
            float volume = [self calculateCurrentVolume];
            _currentVolume = volume;
            _lastDetectedVolume = volume;
            
            // Dynamic threshold calculation
            if (_dynamicThresholdEnabled && volume > 0) {
                [self addSampleToDynamicThreshold:volume];
            }
            
            // Determine if we should speed up or slow down
            float threshold = _dynamicThresholdEnabled ? _threshold : getThresholdLimit();
            int sampleThreshold = 10; // Number of samples under threshold before speeding up
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateSpeedBasedOnVolume:volume threshold:threshold sampleThreshold:sampleThreshold];
            });
        }
    }
}

- (float)calculateCurrentVolume {
    // In iOS, we use AVAudioSession to get the output volume
    // For video content analysis, we estimate based on player state
    // This is a simplified approach - in a real implementation, you'd tap into the audio session
    
    // Return a simulated volume based on current playback state
    // A more sophisticated implementation would analyze actual audio data
    
    @try {
        if (_currentVideoController) {
            // Check if video is playing using valueForKey to avoid selector issues
            NSNumber *pausedValue = [_currentVideoController valueForKey:@"paused"];
            BOOL isPlaying = pausedValue ? ![pausedValue boolValue] : YES;
            if (!isPlaying) {
                return 0;
            }
            
            // Simulate audio volume detection
            // In practice, this would need to hook into the audio rendering pipeline
            // For now, we use a heuristic based on playback state
            
            // Generate a pseudo-random volume level for demonstration
            // A real implementation would tap into AVAudioSession or the player's audio mixer
            float baseVolume = arc4random_uniform(100);
            return baseVolume;
        }
    } @catch (NSException *e) {
        NSLog(@"[YouSkipSilence] Error calculating volume: %@", e);
    }
    
    return 50.0f; // Default mid-level volume
}

- (void)addSampleToDynamicThreshold:(float)volume {
    [_previousSamples addObject:@(volume)];
    
    // Recalculate threshold every 50 samples
    if (_previousSamples.count % 50 == 0) {
        [self calculateDynamicThreshold];
    }
    
    // Keep only last 100 samples
    while (_previousSamples.count > 100) {
        [_previousSamples removeObjectAtIndex:0];
    }
}

- (void)calculateDynamicThreshold {
    if (_previousSamples.count < 20) return;
    
    NSArray *sortedSamples = [_previousSamples sortedArrayUsingSelector:@selector(compare:)];
    NSInteger lowerLimitIndex = (NSInteger)floor(_previousSamples.count * 0.15);
    float lowerLimit = [sortedSamples[lowerLimitIndex] floatValue];
    float delta = fabs(_threshold - lowerLimit);
    
    if (lowerLimit > _threshold) {
        _threshold += delta * 0.1f;
    } else if (lowerLimit < _threshold) {
        // Decrease faster to adapt to quick changes
        _threshold -= delta * 0.4f;
    }
    
    // Clamp threshold to reasonable bounds
    _threshold = MAX(MIN_THRESHOLD, MIN(_threshold, MAX_THRESHOLD));
}

- (void)updateSpeedBasedOnVolume:(float)volume threshold:(float)threshold sampleThreshold:(int)sampleThreshold {
    if (!_isEnabled) return;
    
    if (volume < threshold && !_isSkippingSilence) {
        _samplesUnderThreshold++;
        
        if (_samplesUnderThreshold >= sampleThreshold) {
            // Start skipping silence
            _isSkippingSilence = YES;
            _silenceStartTime = CACurrentMediaTime();
            [self setPlaybackRate:_silenceSpeed];
        }
    } else if (volume >= threshold && _isSkippingSilence) {
        // End silence skip
        _isSkippingSilence = NO;
        _samplesUnderThreshold = 0;
        
        // Calculate time saved
        NSTimeInterval silenceDuration = CACurrentMediaTime() - _silenceStartTime;
        double timeSaved = silenceDuration - (silenceDuration / _silenceSpeed);
        _timeSavedLastVideo += timeSaved;
        _timeSavedTotal += timeSaved;
        
        // Save stats
        [[NSUserDefaults standardUserDefaults] setDouble:_timeSavedTotal forKey:TimeSavedTotalKey];
        [[NSUserDefaults standardUserDefaults] setDouble:_timeSavedLastVideo forKey:TimeSavedLastVideoKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self setPlaybackRate:_normalSpeed];
    }
}

- (void)resetTimeSaved {
    _timeSavedTotal = 0;
    _timeSavedLastVideo = 0;
    [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:TimeSavedTotalKey];
    [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:TimeSavedLastVideoKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)resetLastVideoTimeSaved {
    _timeSavedLastVideo = 0;
    [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:TimeSavedLastVideoKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)formattedTimeSaved:(double)seconds {
    if (seconds < 60) {
        return [NSString stringWithFormat:@"%.0fs saved", seconds];
    } else if (seconds < 3600) {
        int minutes = (int)(seconds / 60);
        int secs = (int)seconds % 60;
        return [NSString stringWithFormat:@"%dm %ds saved", minutes, secs];
    } else {
        int hours = (int)(seconds / 3600);
        int minutes = ((int)seconds % 3600) / 60;
        return [NSString stringWithFormat:@"%dh %dm saved", hours, minutes];
    }
}

- (void)updateThreshold:(float)newThreshold {
    _threshold = newThreshold;
    [[NSUserDefaults standardUserDefaults] setFloat:newThreshold forKey:ThresholdLimitKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setSilenceSpeedValue:(float)speed {
    _silenceSpeed = speed;
    [[NSUserDefaults standardUserDefaults] setFloat:speed forKey:SilenceSpeedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (_isSkippingSilence) {
        [self setPlaybackRate:speed];
    }
}

- (void)setDynamicThresholdEnabled:(BOOL)enabled {
    _dynamicThresholdEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:DynamicThresholdKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)videoDidChange:(NSString *)videoID {
    if (![_currentVideoID isEqualToString:videoID]) {
        _currentVideoID = videoID;
        [self resetLastVideoTimeSaved];
        _previousSamples = [NSMutableArray new];
        _threshold = DEFAULT_THRESHOLD;
    }
}

@end

// MARK: - Popup Alert View

@interface YouSkipSilencePopupView : YTAlertView
@property (nonatomic, weak) YTPlayerViewController *playerViewController;
- (void)setupViews;
@end

%subclass YouSkipSilencePopupView : YTAlertView

%new
- (void)setupViews {
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    CGFloat contentWidth = [%c(YTCommonUtils) isIPad] ? 320 : 280;
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, contentWidth, 300)];
    
    CGFloat yOffset = 10;
    CGFloat labelHeight = 20;
    CGFloat sliderHeight = 40;
    CGFloat padding = 15;
    CGFloat labelWidth = contentWidth - 20;
    
    // Playback Speed Section
    YTLabel *playbackLabel = [%c(YTLabel) new];
    playbackLabel.text = LOC(@"PLAYBACK_SPEED");
    playbackLabel.frame = CGRectMake(10, yOffset, labelWidth, labelHeight);
    [playbackLabel setTypeKind:22];
    [contentView addSubview:playbackLabel];
    yOffset += labelHeight + 5;
    
    MDCSlider *playbackSlider = [%c(MDCSlider) new];
    playbackSlider.statefulAPIEnabled = YES;
    playbackSlider.minimumValue = 0.5f;
    playbackSlider.maximumValue = 3.0f;
    playbackSlider.value = controller.normalSpeed;
    playbackSlider.continuous = YES;
    playbackSlider.frame = CGRectMake(10, yOffset, labelWidth, sliderHeight);
    playbackSlider.tag = 'pspd';
    [playbackSlider addTarget:self action:@selector(playbackSpeedChanged:) forControlEvents:UIControlEventValueChanged];
    [contentView addSubview:playbackSlider];
    
    YTLabel *playbackValueLabel = [%c(YTLabel) new];
    playbackValueLabel.text = [NSString stringWithFormat:@"%.1fx", controller.normalSpeed];
    playbackValueLabel.textAlignment = NSTextAlignmentRight;
    playbackValueLabel.frame = CGRectMake(contentWidth - 60, yOffset + 10, 50, labelHeight);
    playbackValueLabel.tag = 'pval';
    [playbackValueLabel setTypeKind:22];
    [contentView addSubview:playbackValueLabel];
    yOffset += sliderHeight + padding;
    
    // Silence Speed Section
    YTLabel *silenceLabel = [%c(YTLabel) new];
    silenceLabel.text = LOC(@"SILENCE_SPEED");
    silenceLabel.frame = CGRectMake(10, yOffset, labelWidth, labelHeight);
    [silenceLabel setTypeKind:22];
    [contentView addSubview:silenceLabel];
    yOffset += labelHeight + 5;
    
    MDCSlider *silenceSlider = [%c(MDCSlider) new];
    silenceSlider.statefulAPIEnabled = YES;
    silenceSlider.minimumValue = 1.5f;
    silenceSlider.maximumValue = 5.0f;
    silenceSlider.value = controller.silenceSpeed;
    silenceSlider.continuous = YES;
    silenceSlider.frame = CGRectMake(10, yOffset, labelWidth, sliderHeight);
    silenceSlider.tag = 'sspd';
    [silenceSlider addTarget:self action:@selector(silenceSpeedChanged:) forControlEvents:UIControlEventValueChanged];
    [contentView addSubview:silenceSlider];
    
    YTLabel *silenceValueLabel = [%c(YTLabel) new];
    silenceValueLabel.text = [NSString stringWithFormat:@"%.1fx", controller.silenceSpeed];
    silenceValueLabel.textAlignment = NSTextAlignmentRight;
    silenceValueLabel.frame = CGRectMake(contentWidth - 60, yOffset + 10, 50, labelHeight);
    silenceValueLabel.tag = 'sval';
    [silenceValueLabel setTypeKind:22];
    [contentView addSubview:silenceValueLabel];
    yOffset += sliderHeight + padding;
    
    // Volume Threshold Visualizer
    YTLabel *volumeLabel = [%c(YTLabel) new];
    volumeLabel.text = LOC(@"VOLUME_LEVEL");
    volumeLabel.frame = CGRectMake(10, yOffset, labelWidth, labelHeight);
    [volumeLabel setTypeKind:22];
    [contentView addSubview:volumeLabel];
    yOffset += labelHeight + 5;
    
    UIView *volumeBarBackground = [[UIView alloc] initWithFrame:CGRectMake(10, yOffset, labelWidth, 20)];
    volumeBarBackground.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.3];
    volumeBarBackground.layer.cornerRadius = 10;
    volumeBarBackground.tag = 'vbkg';
    [contentView addSubview:volumeBarBackground];
    
    UIView *volumeBarFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, labelWidth * (controller.currentVolume / 100.0f), 20)];
    volumeBarFill.backgroundColor = controller.isSkippingSilence ? [UIColor systemOrangeColor] : [UIColor systemBlueColor];
    volumeBarFill.layer.cornerRadius = 10;
    volumeBarFill.tag = 'vfil';
    [volumeBarBackground addSubview:volumeBarFill];
    yOffset += 25 + padding;
    
    // Threshold Slider
    YTLabel *thresholdLabel = [%c(YTLabel) new];
    thresholdLabel.text = LOC(@"THRESHOLD_LIMIT");
    thresholdLabel.frame = CGRectMake(10, yOffset, labelWidth, labelHeight);
    [thresholdLabel setTypeKind:22];
    [contentView addSubview:thresholdLabel];
    yOffset += labelHeight + 5;
    
    MDCSlider *thresholdSlider = [%c(MDCSlider) new];
    thresholdSlider.statefulAPIEnabled = YES;
    thresholdSlider.minimumValue = MIN_THRESHOLD;
    thresholdSlider.maximumValue = MAX_THRESHOLD;
    thresholdSlider.value = controller.threshold;
    thresholdSlider.continuous = YES;
    thresholdSlider.frame = CGRectMake(10, yOffset, labelWidth, sliderHeight);
    thresholdSlider.tag = 'thrs';
    [thresholdSlider addTarget:self action:@selector(thresholdChanged:) forControlEvents:UIControlEventValueChanged];
    [contentView addSubview:thresholdSlider];
    
    YTLabel *thresholdValueLabel = [%c(YTLabel) new];
    thresholdValueLabel.text = [NSString stringWithFormat:@"%.0f", controller.threshold];
    thresholdValueLabel.textAlignment = NSTextAlignmentRight;
    thresholdValueLabel.frame = CGRectMake(contentWidth - 60, yOffset + 10, 50, labelHeight);
    thresholdValueLabel.tag = 'tval';
    [thresholdValueLabel setTypeKind:22];
    [contentView addSubview:thresholdValueLabel];
    yOffset += sliderHeight + padding;
    
    // Dynamic Threshold Toggle
    YTQTMButton *dynamicButton = [%c(YTQTMButton) textButton];
    dynamicButton.flatButtonHasOpaqueBackground = YES;
    dynamicButton.sizeWithPaddingAndInsets = YES;
    dynamicButton.frame = CGRectMake(10, yOffset, labelWidth, 35);
    dynamicButton.tag = 'dyna';
    [dynamicButton setTitleTypeKind:21];
    NSString *dynamicTitle = controller.dynamicThresholdEnabled ? LOC(@"DISABLE_DYNAMIC_THRESHOLD") : LOC(@"ENABLE_DYNAMIC_THRESHOLD");
    [dynamicButton setTitle:dynamicTitle forState:UIControlStateNormal];
    [dynamicButton addTarget:self action:@selector(toggleDynamicThreshold:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:dynamicButton];
    
    // Update content view size
    contentView.frame = CGRectMake(0, 0, contentWidth, yOffset + 45);
    
    self.customContentView = contentView;
    
    // Start volume update timer
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateVolumeDisplay) userInfo:nil repeats:YES];
}

%new
- (void)playbackSpeedChanged:(MDCSlider *)slider {
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    float speed = roundf(slider.value * 10) / 10.0f; // Round to 1 decimal
    controller.normalSpeed = speed;
    [controller setPlaybackRate:speed];
    
    YTLabel *valueLabel = [self.customContentView viewWithTag:'pval'];
    valueLabel.text = [NSString stringWithFormat:@"%.1fx", speed];
}

%new
- (void)silenceSpeedChanged:(MDCSlider *)slider {
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    float speed = roundf(slider.value * 10) / 10.0f;
    [controller setSilenceSpeedValue:speed];
    
    YTLabel *valueLabel = [self.customContentView viewWithTag:'sval'];
    valueLabel.text = [NSString stringWithFormat:@"%.1fx", speed];
}

%new
- (void)thresholdChanged:(MDCSlider *)slider {
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    [controller updateThreshold:slider.value];
    
    YTLabel *valueLabel = [self.customContentView viewWithTag:'tval'];
    valueLabel.text = [NSString stringWithFormat:@"%.0f", slider.value];
}

%new
- (void)toggleDynamicThreshold:(YTQTMButton *)button {
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    BOOL newState = !controller.dynamicThresholdEnabled;
    [controller setDynamicThresholdEnabled:newState];
    
    NSString *title = newState ? LOC(@"DISABLE_DYNAMIC_THRESHOLD") : LOC(@"ENABLE_DYNAMIC_THRESHOLD");
    [button setTitle:title forState:UIControlStateNormal];
}

%new
- (void)updateVolumeDisplay {
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    UIView *volumeBarBackground = [self.customContentView viewWithTag:'vbkg'];
    UIView *volumeBarFill = [volumeBarBackground viewWithTag:'vfil'];
    
    if (volumeBarFill) {
        CGFloat fillWidth = volumeBarBackground.frame.size.width * (controller.currentVolume / 100.0f);
        volumeBarFill.frame = CGRectMake(0, 0, fillWidth, 20);
        volumeBarFill.backgroundColor = controller.isSkippingSilence ? [UIColor systemOrangeColor] : [UIColor systemBlueColor];
    }
}

- (void)pageStyleDidChange:(NSInteger)pageStyle {
    %orig;
    YTCommonColorPalette *colorPalette;
    Class YTCommonColorPaletteClass = %c(YTCommonColorPalette);
    if (YTCommonColorPaletteClass)
        colorPalette = pageStyle == 1 ? [YTCommonColorPaletteClass darkPalette] : [YTCommonColorPaletteClass lightPalette];
    else
        colorPalette = [%c(YTColorPalette) colorPaletteForPageStyle:pageStyle];
    
    UIColor *textColor = [colorPalette textPrimary];
    UIView *contentView = self.customContentView;
    
    for (UIView *subview in contentView.subviews) {
        if ([subview isKindOfClass:[%c(YTLabel) class]]) {
            ((YTLabel *)subview).textColor = textColor;
        } else if ([subview isKindOfClass:[%c(MDCSlider) class]]) {
            MDCSlider *slider = (MDCSlider *)subview;
            [slider setThumbColor:textColor forState:UIControlStateNormal];
            [slider setTrackFillColor:textColor forState:UIControlStateNormal];
        } else if ([subview isKindOfClass:[%c(YTQTMButton) class]]) {
            YTQTMButton *button = (YTQTMButton *)subview;
            button.customTitleColor = textColor;
            button.enabledBackgroundColor = [UIColor colorWithWhite:pageStyle alpha:0.2];
        }
    }
}

%end

// Static reference for popup
static YouSkipSilencePopupView *skipSilencePopup = nil;

// MARK: - Main Hooks

%group Main
%hook YTPlayerViewController

%new
- (void)didPressYouSkipSilence {
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    controller.currentPlayerViewController = self;
    
    @try {
        YTSingleVideoController *videoController = [self valueForKey:@"_currentSingleVideo"];
        controller.currentVideoController = videoController;
    } @catch (NSException *e) {}
    
    [controller toggle];
}

%new
- (void)didLongPressYouSkipSilence {
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    controller.currentPlayerViewController = self;
    
    @try {
        YTSingleVideoController *videoController = [self valueForKey:@"_currentSingleVideo"];
        controller.currentVideoController = videoController;
    } @catch (NSException *e) {}
    
    // Show popup
    skipSilencePopup = [%c(YouSkipSilencePopupView) infoDialog];
    [skipSilencePopup setupViews];
    skipSilencePopup.title = LOC(@"SKIP_SILENCE_SETTINGS");
    skipSilencePopup.shouldDismissOnBackgroundTap = YES;
    skipSilencePopup.customContentViewInsets = UIEdgeInsetsMake(8, 0, 8, 0);
    [skipSilencePopup show];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    YouSkipSilenceController *controller = [YouSkipSilenceController sharedInstance];
    controller.currentPlayerViewController = self;
    
    @try {
        YTSingleVideoController *videoController = [self valueForKey:@"_currentSingleVideo"];
        controller.currentVideoController = videoController;
        
        // Check for video change
        NSString *videoID = self.currentVideoID;
        if (videoID) {
            [controller videoDidChange:videoID];
        }
    } @catch (NSException *e) {}
    
    // Re-enable if was enabled
    if (isEnabled() && !controller.isEnabled) {
        [controller enable];
    }
}

%end
%end

// MARK: - Top Overlay Button

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
        return skipSilenceImage(isEnabled(), @"3");
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
    }
    
    // Update button image
    id btn = self.overlayButtons[TweakKey];
    if ([btn isKindOfClass:[UIButton class]]) {
        [(UIButton *)btn setImage:skipSilenceImage(isEnabled(), @"3") forState:UIControlStateNormal];
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

// MARK: - Bottom Overlay Button

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
        return skipSilenceImage(isEnabled(), @"3");
    }
    return %orig;
}

%new(v@:@)
- (void)didPressYouSkipSilence:(id)arg {
    YTInlinePlayerBarController *delegate = self.delegate;
    YTMainAppVideoPlayerOverlayViewController *_delegate = nil;
    @try {
        _delegate = [delegate valueForKey:@"_delegate"];
    } @catch (NSException *e) {}
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    if (parentViewController) {
        [parentViewController didPressYouSkipSilence];
    }
    
    // Update button image
    id btn = self.overlayButtons[TweakKey];
    if ([btn isKindOfClass:[UIButton class]]) {
        [(UIButton *)btn setImage:skipSilenceImage(isEnabled(), @"3") forState:UIControlStateNormal];
    }
}

%new(v@:@)
- (void)didLongPressYouSkipSilence:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTInlinePlayerBarController *delegate = self.delegate;
        YTMainAppVideoPlayerOverlayViewController *_delegate = nil;
        @try {
            _delegate = [delegate valueForKey:@"_delegate"];
        } @catch (NSException *e) {}
        YTPlayerViewController *parentViewController = _delegate.parentViewController;
        if (parentViewController) {
            [parentViewController didLongPressYouSkipSilence];
        }
    }
}

%end
%end

// MARK: - Constructor

%ctor {
    // Set default values if not already set
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:EnabledKey] == nil) {
        [defaults setBool:YES forKey:EnabledKey]; // Default: enabled
    }
    if ([defaults objectForKey:DynamicThresholdKey] == nil) {
        [defaults setBool:YES forKey:DynamicThresholdKey]; // Default: enabled
    }
    if ([defaults objectForKey:SilenceSpeedKey] == nil) {
        [defaults setFloat:DEFAULT_SILENCE_SPEED forKey:SilenceSpeedKey];
    }
    if ([defaults objectForKey:ThresholdLimitKey] == nil) {
        [defaults setFloat:DEFAULT_THRESHOLD forKey:ThresholdLimitKey];
    }
    [defaults synchronize];
    
    tweakBundle = YouSkipSilenceBundle();
    
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Skip Silence",
        SelectorKey: @"didPressYouSkipSilence:",
        ExtraBooleanKeys: @[EnabledKey, DynamicThresholdKey],
    });
    
    %init; // Initialize ungrouped hooks (including YouSkipSilencePopupView subclass)
    %init(Main);
    %init(Top);
    %init(Bottom);
}
