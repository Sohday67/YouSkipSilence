#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <MediaToolbox/MTAudioProcessingTap.h>
#import <rootless.h>

#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTHUDMessage.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/MLHAMQueuePlayer.h>
#import <YouTubeHeader/MLHAMPlayerItemSegment.h>
#import <YouTubeHeader/YTVarispeedSwitchController.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerOption.h>

#import <YTVideoOverlay/Header.h>
#import <YTVideoOverlay/Init.x>

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

// MLHAMQueuePlayer method declarations for rate control
@interface MLHAMQueuePlayer (YouSkipSilence)
- (void)setRate:(float)rate;
- (void)internalSetRate;
@end

// MLInnerTubePlayerConfig for checking varispeed
@interface MLInnerTubePlayerConfig : NSObject
- (BOOL)varispeedAllowed;
@end

// MLPlayerItem for getting config
@interface MLPlayerItem : NSObject
@property (nonatomic, readonly) MLInnerTubePlayerConfig *config;
@end

// MLHAMPlayerItemSegment for getting player item
@interface MLHAMPlayerItemSegment (YouSkipSilence)
- (MLPlayerItem *)playerItem;
@end

@interface YTMainAppVideoPlayerOverlayViewController (YouSkipSilence)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@property (nonatomic, weak) id delegate;
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
@property (nonatomic, strong) NSMutableDictionary *overlayButtons;
- (void)didPressYouSkipSilence:(id)arg;
- (void)didLongPressYouSkipSilence:(UILongPressGestureRecognizer *)gesture;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouSkipSilence)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
@property (nonatomic, strong) NSMutableDictionary *overlayButtons;
- (void)didPressYouSkipSilence:(id)arg;
- (void)didLongPressYouSkipSilence:(UILongPressGestureRecognizer *)gesture;
@end

#pragma mark - Audio Processing Tap Callbacks

// Forward declaration for manager
@class YouSkipSilenceManager;
static void updateAudioLevel(float level);

// Audio level tracking using KVO on the player's volume output
// We'll use a simpler approach - track audio from the video element via the player
static float g_currentAudioLevel = 50.0f;
static BOOL g_audioTapSetupDone = NO;

// MTAudioProcessingTap callbacks for getting real audio levels
static void tapInit(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    *tapStorageOut = clientInfo;
}

static void tapFinalize(MTAudioProcessingTapRef tap) {
    // Cleanup if needed
}

static void tapPrepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
    // Prepare for processing
}

static void tapUnprepare(MTAudioProcessingTapRef tap) {
    // Cleanup after processing
}

static void tapProcess(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut) {
    OSStatus status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, NULL, numberFramesOut);
    if (status != noErr) return;
    
    // Calculate RMS (Root Mean Square) volume level
    float totalSquared = 0;
    int sampleCount = 0;
    
    for (UInt32 i = 0; i < bufferListInOut->mNumberBuffers; i++) {
        AudioBuffer buffer = bufferListInOut->mBuffers[i];
        float *samples = (float *)buffer.mData;
        int frameCount = buffer.mDataByteSize / sizeof(float);
        
        for (int j = 0; j < frameCount; j++) {
            float sample = samples[j];
            totalSquared += sample * sample;
            sampleCount++;
        }
    }
    
    if (sampleCount > 0) {
        float rms = sqrtf(totalSquared / sampleCount);
        // Convert to percentage (0-100 scale)
        // Audio samples are typically -1 to 1, so RMS of 0.1 is fairly quiet
        float level = rms * 500; // Scale up for visibility
        level = fminf(100, fmaxf(0, level));
        
        g_currentAudioLevel = level;
        
        // Update manager on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            updateAudioLevel(level);
        });
    }
}

static float getAudioLevel(void) {
    return g_currentAudioLevel;
}

#pragma mark - YouSkipSilenceManager

// Global reference to the YouTube queue player for speed control
static MLHAMQueuePlayer *g_queuePlayer = nil;

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
@property (nonatomic, assign) float peakLevel;
@property (nonatomic, assign) float averageLevel;

+ (instancetype)sharedManager;
- (void)toggle;
- (void)attachToPlayer:(AVPlayer *)player;
- (void)detach;
- (void)loadSettings;
- (void)saveSettings;
- (void)resetTimeSaved;
- (NSString *)formattedTimeSaved:(NSTimeInterval)seconds;
- (void)updateVideoID:(NSString *)videoID;
- (void)setRate:(float)rate;

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
        _currentVolume = 50; // Start with middle value for visualization
        _peakLevel = 0;
        _averageLevel = 0;
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

- (void)setRate:(float)rate {
    // Use YouTube's MLHAMQueuePlayer for rate control
    if (g_queuePlayer) {
        [g_queuePlayer setRate:rate];
    } else if (_currentPlayer) {
        // Fallback to AVPlayer if queue player not available
        _currentPlayer.rate = rate;
    }
}

- (void)toggle {
    _isEnabled = !_isEnabled;
    [self saveSettings];
    
    if (!_isEnabled) {
        [self detach];
        // Reset to normal speed
        [self setRate:1.0f];
        _isSpedUp = NO;
        _samplesUnderThreshold = 0;
    } else {
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
    [self removeAudioTap];
}

- (void)setupAudioTap {
    // Setup audio tap for real audio level detection
    if (!_currentPlayer || !_currentPlayer.currentItem) {
        // Retry after a short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (_isEnabled && _currentPlayer && _currentPlayer.currentItem && !_audioMix) {
                [self setupAudioTap];
            }
        });
        return;
    }
    
    AVPlayerItem *item = _currentPlayer.currentItem;
    AVAsset *asset = item.asset;
    
    // Load tracks asynchronously since HLS streams don't have tracks available immediately
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = nil;
            AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:&error];
            
            if (status != AVKeyValueStatusLoaded) {
                // Tracks not loaded yet, retry
                return;
            }
            
            NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
            if (audioTracks.count == 0) {
                // No audio tracks found, use fallback audio detection
                return;
            }
            
            // Create audio mix for metering
            AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
            NSMutableArray *inputParameters = [NSMutableArray array];
            
            for (AVAssetTrack *track in audioTracks) {
                AVMutableAudioMixInputParameters *params = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
                
                // Setup MTAudioProcessingTap for audio level metering
                MTAudioProcessingTapCallbacks callbacks;
                callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
                callbacks.clientInfo = (__bridge void *)self;
                callbacks.init = tapInit;
                callbacks.finalize = tapFinalize;
                callbacks.prepare = tapPrepare;
                callbacks.unprepare = tapUnprepare;
                callbacks.process = tapProcess;
                
                MTAudioProcessingTapRef tap;
                OSStatus tapStatus = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap);
                
                if (tapStatus == noErr && tap) {
                    params.audioTapProcessor = tap;
                    self->_audioTap = tap;
                    CFRelease(tap);
                    g_audioTapSetupDone = YES;
                }
                
                [inputParameters addObject:params];
            }
            
            audioMix.inputParameters = inputParameters;
            item.audioMix = audioMix;
            self->_audioMix = audioMix;
        });
    }];
}

- (void)removeAudioTap {
    if (_currentPlayer.currentItem) {
        _currentPlayer.currentItem.audioMix = nil;
    }
    _audioMix = nil;
    _audioTap = NULL;
}

- (void)startAnalysis {
    if (_analysisTimer) {
        [_analysisTimer invalidate];
    }
    
    // Setup audio tap on the current player item for audio level detection
    [self setupAudioTap];
    
    // Start periodic analysis using a timer
    // This is a simplified approach that analyzes playback periodically
    _analysisTimer = [NSTimer scheduledTimerWithTimeInterval:0.025 // 25ms intervals, similar to skip-silence
                                                      target:self
                                                    selector:@selector(analyzeCurrentSample)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)analyzeCurrentSample {
    if (!_isEnabled) {
        return;
    }
    
    // Get the current volume from the audio meter
    float volume = getAudioLevel();
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
    // Return the current volume level set by the audio processing tap
    // This is updated in real-time by the tapProcess callback
    return _currentVolume;
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
    _isSpedUp = YES;
    _lastSpeedUpTime = CACurrentMediaTime();
    [self setRate:_silenceSpeed];
}

- (void)slowDown {
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
    [self setRate:speed];
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

// Function called from audio tap to update volume level
static void updateAudioLevel(float level) {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    manager.currentVolume = level;
}

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

#pragma mark - Settings Popup View Controller

@interface YouSkipSilenceSettingsViewController : UIViewController
@property (nonatomic, strong) UISlider *playbackSpeedSlider;
@property (nonatomic, strong) UISlider *silenceSpeedSlider;
@property (nonatomic, strong) UISlider *thresholdSlider;
@property (nonatomic, strong) UIView *audioVisualizerView;
@property (nonatomic, strong) UIView *audioLevelBar;
@property (nonatomic, strong) UIView *thresholdLine;
@property (nonatomic, strong) UILabel *playbackSpeedLabel;
@property (nonatomic, strong) UILabel *silenceSpeedLabel;
@property (nonatomic, strong) UILabel *thresholdLabel;
@property (nonatomic, strong) UISwitch *dynamicThresholdSwitch;
@property (nonatomic, strong) NSTimer *visualizerTimer;
@end

@implementation YouSkipSilenceSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    
    // Semi-transparent dark background
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    
    // Container view
    UIView *containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    containerView.layer.cornerRadius = 16;
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:containerView];
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = YSSLocalized(@"SETTINGS_TITLE");
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:titleLabel];
    
    // Close button
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeButton setTitle:@"✕" forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:20];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(dismissSettings) forControlEvents:UIControlEventTouchUpInside];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:closeButton];
    
    // Playback Speed Section
    UILabel *playbackTitleLabel = [[UILabel alloc] init];
    playbackTitleLabel.text = YSSLocalized(@"PLAYBACK_SPEED");
    playbackTitleLabel.font = [UIFont systemFontOfSize:14];
    playbackTitleLabel.textColor = [UIColor lightGrayColor];
    playbackTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:playbackTitleLabel];
    
    self.playbackSpeedLabel = [[UILabel alloc] init];
    self.playbackSpeedLabel.text = [NSString stringWithFormat:@"%.1fx", manager.playbackSpeed];
    self.playbackSpeedLabel.font = [UIFont boldSystemFontOfSize:14];
    self.playbackSpeedLabel.textColor = [UIColor whiteColor];
    self.playbackSpeedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.playbackSpeedLabel];
    
    self.playbackSpeedSlider = [[UISlider alloc] init];
    self.playbackSpeedSlider.minimumValue = 0.5;
    self.playbackSpeedSlider.maximumValue = 2.0;
    self.playbackSpeedSlider.value = manager.playbackSpeed;
    self.playbackSpeedSlider.tintColor = [UIColor systemBlueColor];
    [self.playbackSpeedSlider addTarget:self action:@selector(playbackSpeedChanged:) forControlEvents:UIControlEventValueChanged];
    self.playbackSpeedSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.playbackSpeedSlider];
    
    // Silence Speed Section
    UILabel *silenceTitleLabel = [[UILabel alloc] init];
    silenceTitleLabel.text = YSSLocalized(@"SILENCE_SPEED");
    silenceTitleLabel.font = [UIFont systemFontOfSize:14];
    silenceTitleLabel.textColor = [UIColor lightGrayColor];
    silenceTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:silenceTitleLabel];
    
    self.silenceSpeedLabel = [[UILabel alloc] init];
    self.silenceSpeedLabel.text = [NSString stringWithFormat:@"%.1fx", manager.silenceSpeed];
    self.silenceSpeedLabel.font = [UIFont boldSystemFontOfSize:14];
    self.silenceSpeedLabel.textColor = [UIColor whiteColor];
    self.silenceSpeedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.silenceSpeedLabel];
    
    self.silenceSpeedSlider = [[UISlider alloc] init];
    self.silenceSpeedSlider.minimumValue = 1.5;
    self.silenceSpeedSlider.maximumValue = 8.0;
    self.silenceSpeedSlider.value = manager.silenceSpeed;
    self.silenceSpeedSlider.tintColor = [UIColor systemOrangeColor];
    [self.silenceSpeedSlider addTarget:self action:@selector(silenceSpeedChanged:) forControlEvents:UIControlEventValueChanged];
    self.silenceSpeedSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.silenceSpeedSlider];
    
    // Volume Threshold Section with Visualizer
    UILabel *thresholdTitleLabel = [[UILabel alloc] init];
    thresholdTitleLabel.text = YSSLocalized(@"VOLUME_THRESHOLD");
    thresholdTitleLabel.font = [UIFont systemFontOfSize:14];
    thresholdTitleLabel.textColor = [UIColor lightGrayColor];
    thresholdTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:thresholdTitleLabel];
    
    self.thresholdLabel = [[UILabel alloc] init];
    self.thresholdLabel.text = [NSString stringWithFormat:@"%.0f%%", manager.silenceThreshold];
    self.thresholdLabel.font = [UIFont boldSystemFontOfSize:14];
    self.thresholdLabel.textColor = [UIColor whiteColor];
    self.thresholdLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.thresholdLabel];
    
    // Audio Visualizer Container
    self.audioVisualizerView = [[UIView alloc] init];
    self.audioVisualizerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    self.audioVisualizerView.layer.cornerRadius = 8;
    self.audioVisualizerView.clipsToBounds = YES;
    self.audioVisualizerView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.audioVisualizerView];
    
    // Audio Level Bar (green bar showing current audio level)
    self.audioLevelBar = [[UIView alloc] init];
    self.audioLevelBar.backgroundColor = [UIColor systemGreenColor];
    self.audioLevelBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.audioVisualizerView addSubview:self.audioLevelBar];
    
    // Threshold Line (red line showing threshold)
    self.thresholdLine = [[UIView alloc] init];
    self.thresholdLine.backgroundColor = [UIColor systemRedColor];
    self.thresholdLine.translatesAutoresizingMaskIntoConstraints = NO;
    [self.audioVisualizerView addSubview:self.thresholdLine];
    
    self.thresholdSlider = [[UISlider alloc] init];
    self.thresholdSlider.minimumValue = 5;
    self.thresholdSlider.maximumValue = 80;
    self.thresholdSlider.value = manager.silenceThreshold;
    self.thresholdSlider.tintColor = [UIColor systemRedColor];
    [self.thresholdSlider addTarget:self action:@selector(thresholdChanged:) forControlEvents:UIControlEventValueChanged];
    self.thresholdSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.thresholdSlider];
    
    // Dynamic Threshold Toggle
    UILabel *dynamicLabel = [[UILabel alloc] init];
    dynamicLabel.text = YSSLocalized(@"DYNAMIC_THRESHOLD");
    dynamicLabel.font = [UIFont systemFontOfSize:14];
    dynamicLabel.textColor = [UIColor lightGrayColor];
    dynamicLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:dynamicLabel];
    
    self.dynamicThresholdSwitch = [[UISwitch alloc] init];
    self.dynamicThresholdSwitch.on = manager.dynamicThreshold;
    self.dynamicThresholdSwitch.onTintColor = [UIColor systemGreenColor];
    [self.dynamicThresholdSwitch addTarget:self action:@selector(dynamicThresholdToggled:) forControlEvents:UIControlEventValueChanged];
    self.dynamicThresholdSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:self.dynamicThresholdSwitch];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Container
        [containerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [containerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [containerView.widthAnchor constraintEqualToConstant:320],
        
        // Title
        [titleLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:16],
        [titleLabel.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
        
        // Close button
        [closeButton.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:12],
        [closeButton.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-12],
        [closeButton.widthAnchor constraintEqualToConstant:30],
        [closeButton.heightAnchor constraintEqualToConstant:30],
        
        // Playback Speed
        [playbackTitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:24],
        [playbackTitleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        
        [self.playbackSpeedLabel.centerYAnchor constraintEqualToAnchor:playbackTitleLabel.centerYAnchor],
        [self.playbackSpeedLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
        
        [self.playbackSpeedSlider.topAnchor constraintEqualToAnchor:playbackTitleLabel.bottomAnchor constant:8],
        [self.playbackSpeedSlider.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        [self.playbackSpeedSlider.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
        
        // Silence Speed
        [silenceTitleLabel.topAnchor constraintEqualToAnchor:self.playbackSpeedSlider.bottomAnchor constant:20],
        [silenceTitleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        
        [self.silenceSpeedLabel.centerYAnchor constraintEqualToAnchor:silenceTitleLabel.centerYAnchor],
        [self.silenceSpeedLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
        
        [self.silenceSpeedSlider.topAnchor constraintEqualToAnchor:silenceTitleLabel.bottomAnchor constant:8],
        [self.silenceSpeedSlider.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        [self.silenceSpeedSlider.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
        
        // Volume Threshold
        [thresholdTitleLabel.topAnchor constraintEqualToAnchor:self.silenceSpeedSlider.bottomAnchor constant:20],
        [thresholdTitleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        
        [self.thresholdLabel.centerYAnchor constraintEqualToAnchor:thresholdTitleLabel.centerYAnchor],
        [self.thresholdLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
        
        // Audio Visualizer
        [self.audioVisualizerView.topAnchor constraintEqualToAnchor:thresholdTitleLabel.bottomAnchor constant:8],
        [self.audioVisualizerView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        [self.audioVisualizerView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
        [self.audioVisualizerView.heightAnchor constraintEqualToConstant:40],
        
        // Audio Level Bar
        [self.audioLevelBar.leadingAnchor constraintEqualToAnchor:self.audioVisualizerView.leadingAnchor],
        [self.audioLevelBar.topAnchor constraintEqualToAnchor:self.audioVisualizerView.topAnchor],
        [self.audioLevelBar.bottomAnchor constraintEqualToAnchor:self.audioVisualizerView.bottomAnchor],
        
        // Threshold Line
        [self.thresholdLine.topAnchor constraintEqualToAnchor:self.audioVisualizerView.topAnchor],
        [self.thresholdLine.bottomAnchor constraintEqualToAnchor:self.audioVisualizerView.bottomAnchor],
        [self.thresholdLine.widthAnchor constraintEqualToConstant:3],
        
        [self.thresholdSlider.topAnchor constraintEqualToAnchor:self.audioVisualizerView.bottomAnchor constant:8],
        [self.thresholdSlider.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        [self.thresholdSlider.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
        
        // Dynamic Threshold
        [dynamicLabel.topAnchor constraintEqualToAnchor:self.thresholdSlider.bottomAnchor constant:20],
        [dynamicLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16],
        [dynamicLabel.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-20],
        
        [self.dynamicThresholdSwitch.centerYAnchor constraintEqualToAnchor:dynamicLabel.centerYAnchor],
        [self.dynamicThresholdSwitch.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16],
    ]];
    
    // Start visualizer timer
    [self startVisualizerTimer];
    
    // Tap gesture to dismiss when tapping outside
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateVisualizerLayout];
}

- (void)startVisualizerTimer {
    self.visualizerTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 
                                                            target:self 
                                                          selector:@selector(updateVisualizer) 
                                                          userInfo:nil 
                                                           repeats:YES];
}

- (void)updateVisualizer {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    float currentVolume = manager.currentVolume;
    float threshold = manager.silenceThreshold;
    
    // Update audio level bar width based on current volume (0-100 scale)
    CGFloat maxWidth = self.audioVisualizerView.bounds.size.width;
    CGFloat levelWidth = (currentVolume / 100.0) * maxWidth;
    
    // Animate the level bar
    [UIView animateWithDuration:0.05 animations:^{
        CGRect frame = self.audioLevelBar.frame;
        frame.size.width = levelWidth;
        self.audioLevelBar.frame = frame;
        
        // Change color based on whether we're above or below threshold
        if (currentVolume < threshold) {
            self.audioLevelBar.backgroundColor = [UIColor systemOrangeColor]; // Below threshold (silence)
        } else {
            self.audioLevelBar.backgroundColor = [UIColor systemGreenColor]; // Above threshold (sound)
        }
    }];
}

- (void)updateVisualizerLayout {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    
    // Update threshold line position
    CGFloat maxWidth = self.audioVisualizerView.bounds.size.width;
    CGFloat thresholdX = (manager.silenceThreshold / 100.0) * maxWidth;
    
    CGRect thresholdFrame = self.thresholdLine.frame;
    thresholdFrame.origin.x = thresholdX - 1.5; // Center the line
    self.thresholdLine.frame = thresholdFrame;
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.view];
    UIView *containerView = self.view.subviews.firstObject;
    if (containerView && !CGRectContainsPoint(containerView.frame, location)) {
        [self dismissSettings];
    }
}

- (void)playbackSpeedChanged:(UISlider *)slider {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    float roundedValue = roundf(slider.value * 10) / 10.0; // Round to 1 decimal
    manager.playbackSpeed = roundedValue;
    self.playbackSpeedLabel.text = [NSString stringWithFormat:@"%.1fx", roundedValue];
    [manager saveSettings];
}

- (void)silenceSpeedChanged:(UISlider *)slider {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    float roundedValue = roundf(slider.value * 10) / 10.0; // Round to 1 decimal
    manager.silenceSpeed = roundedValue;
    self.silenceSpeedLabel.text = [NSString stringWithFormat:@"%.1fx", roundedValue];
    [manager saveSettings];
}

- (void)thresholdChanged:(UISlider *)slider {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    manager.silenceThreshold = slider.value;
    self.thresholdLabel.text = [NSString stringWithFormat:@"%.0f%%", slider.value];
    [manager saveSettings];
    [self updateVisualizerLayout];
}

- (void)dynamicThresholdToggled:(UISwitch *)switchControl {
    YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
    manager.dynamicThreshold = switchControl.on;
    [manager saveSettings];
    
    // Enable/disable threshold slider based on dynamic threshold state
    self.thresholdSlider.enabled = !switchControl.on;
    self.thresholdSlider.alpha = switchControl.on ? 0.5 : 1.0;
}

- (void)dismissSettings {
    [self.visualizerTimer invalidate];
    self.visualizerTimer = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [self.visualizerTimer invalidate];
}

@end

static void showSettingsPopup(UIViewController *presenter) {
    YouSkipSilenceSettingsViewController *settingsVC = [[YouSkipSilenceSettingsViewController alloc] init];
    settingsVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    settingsVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:settingsVC animated:YES completion:nil];
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

static void addLongPressGestureToButton(YTQTMButton *button, id target, SEL selector) {
    if (button) {
        // Remove existing long press gestures to avoid duplicates
        for (UIGestureRecognizer *gesture in button.gestureRecognizers) {
            if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
                [button removeGestureRecognizer:gesture];
            }
        }
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:selector];
        longPress.minimumPressDuration = 0.5;
        [button addGestureRecognizer:longPress];
    }
}

%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    if ([tweakId isEqualToString:TweakKey]) {
        YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
        return skipSilenceImage(@"3", manager.isEnabled);
    }
    return %orig;
}

- (void)setTopOverlayVisible:(BOOL)visible isAutonavCanceledState:(BOOL)canceledState {
    %orig;
    // Add long press gesture when button becomes visible
    if (visible && self.overlayButtons[TweakKey]) {
        addLongPressGestureToButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouSkipSilence:));
    }
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

- (UIImage *)buttonImage:(NSString *)tweakId {
    if ([tweakId isEqualToString:TweakKey]) {
        YouSkipSilenceManager *manager = [YouSkipSilenceManager sharedManager];
        return skipSilenceImage(@"3", manager.isEnabled);
    }
    return %orig;
}

- (void)updateIconVisibility {
    %orig;
    // Add long press gesture when button becomes visible
    if (self.overlayButtons[TweakKey]) {
        addLongPressGestureToButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouSkipSilence:));
    }
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

#pragma mark - MLHAMQueuePlayer Hook for Speed Control

%group Player

%hook MLHAMQueuePlayer

- (instancetype)init {
    self = %orig;
    if (self) {
        g_queuePlayer = self;
    }
    return self;
}

- (void)dealloc {
    if (g_queuePlayer == self) {
        g_queuePlayer = nil;
    }
    %orig;
}

// Hook setRate to support custom speeds for silence skipping
// This follows the same pattern as YouSpeed
- (void)setRate:(float)newRate {
    float currentRate = [[self valueForKey:@"_rate"] floatValue];
    if (currentRate == newRate) return;
    
    // Check if varispeed is allowed for this video
    MLHAMPlayerItemSegment *segment = [self valueForKey:@"_currentSegment"];
    if (segment) {
        MLPlayerItem *playerItem = [segment playerItem];
        if (playerItem) {
            MLInnerTubePlayerConfig *config = playerItem.config;
            if (config && ![config varispeedAllowed]) {
                // Varispeed not allowed for this video
                %orig;
                return;
            }
        }
    }
    
    // Set the rate directly (bypassing YouTube's speed restrictions)
    [self setValue:@(newRate) forKey:@"_rate"];
    [self internalSetRate];
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
    %init(Player);
}
