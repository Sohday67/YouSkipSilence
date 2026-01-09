#import "YSSAudioTap.h"
#import "YSSPreferences.h"
#import <MediaToolbox/MediaToolbox.h>

static const float kYSSNoiseFloorAlpha = 0.1f;
static const float kYSSThresholdMultiplier = 1.6f;
static const CFTimeInterval kYSSRateSwitchDebounce = 0.35;

static void YSSTapInit(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut);
static void YSSTapFinalize(MTAudioProcessingTapRef tap);
static void YSSTapPrepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat);
static void YSSTapUnprepare(MTAudioProcessingTapRef tap);
static void YSSTapProcess(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut);

@interface YSSAudioTap ()
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, assign) MTAudioProcessingTapRef tap;
@property (nonatomic, assign) float noiseFloor;
@property (nonatomic, assign) BOOL isSilent;
@property (nonatomic, assign) CFTimeInterval lastSwitchTime;
@property (nonatomic, assign) CFTimeInterval silenceStartTime;
@end

@implementation YSSAudioTap

+ (instancetype)shared {
    static YSSAudioTap *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)attachToPlayerItem:(AVPlayerItem *)item {
    if (!item) {
        return;
    }
    if (self.playerItem == item) {
        return;
    }
    [self detach];
    self.playerItem = item;

    AVAsset *asset = item.asset;
    NSArray<AVAssetTrack *> *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count == 0) {
        return;
    }

    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    NSMutableArray<AVMutableAudioMixInputParameters *> *paramsArray = [NSMutableArray array];
    for (AVAssetTrack *track in audioTracks) {
        AVMutableAudioMixInputParameters *params = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track];
        [paramsArray addObject:params];
    }

    MTAudioProcessingTapCallbacks callbacks;
    memset(&callbacks, 0, sizeof(callbacks));
    callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
    callbacks.clientInfo = (__bridge void *)self;
    callbacks.init = YSSTapInit;
    callbacks.finalize = YSSTapFinalize;
    callbacks.prepare = YSSTapPrepare;
    callbacks.unprepare = YSSTapUnprepare;
    callbacks.process = YSSTapProcess;

    MTAudioProcessingTapRef tap;
    OSStatus status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap);
    if (status != noErr) {
        return;
    }
    self.tap = tap;

    for (AVMutableAudioMixInputParameters *params in paramsArray) {
        params.audioTapProcessor = tap;
    }

    audioMix.inputParameters = paramsArray;
    item.audioMix = audioMix;
}

- (void)detach {
    if (self.tap) {
        CFRelease(self.tap);
        self.tap = NULL;
    }
    self.playerItem = nil;
    self.noiseFloor = 0.0f;
    self.isSilent = NO;
    self.lastSwitchTime = 0.0;
    self.silenceStartTime = 0.0;
}

- (void)resetForNewVideo {
    self.silenceStartTime = 0.0;
    self.isSilent = NO;
    self.noiseFloor = 0.0f;
}

- (void)updatePlaybackRateIfNeeded {
    YSSPreferences *prefs = [YSSPreferences shared];
    if (!self.player) {
        return;
    }
    if (!prefs.enabled) {
        if (self.player.rate != 1.0f) {
            self.player.rate = 1.0f;
        }
        return;
    }
    float targetRate = self.isSilent ? prefs.silenceSpeed : prefs.playbackSpeed;
    if (fabs(self.player.rate - targetRate) > 0.01f) {
        self.player.rate = targetRate;
    }
}

- (void)handleRMSValue:(float)rms {
    YSSPreferences *prefs = [YSSPreferences shared];
    if (!prefs.enabled) {
        return;
    }

    if (self.noiseFloor <= 0.0f) {
        self.noiseFloor = rms;
    } else {
        self.noiseFloor = (kYSSNoiseFloorAlpha * rms) + ((1.0f - kYSSNoiseFloorAlpha) * self.noiseFloor);
    }

    float threshold = prefs.dynamicThreshold ? (self.noiseFloor * kYSSThresholdMultiplier) : prefs.fixedThreshold;
    BOOL shouldBeSilent = rms < threshold;
    CFTimeInterval now = CACurrentMediaTime();

    if (shouldBeSilent != self.isSilent && (now - self.lastSwitchTime) > kYSSRateSwitchDebounce) {
        [self transitionToSilent:shouldBeSilent atTime:now];
    }
}

- (void)transitionToSilent:(BOOL)silent atTime:(CFTimeInterval)now {
    self.isSilent = silent;
    self.lastSwitchTime = now;

    if (silent) {
        self.silenceStartTime = now;
    } else if (self.silenceStartTime > 0.0) {
        CFTimeInterval duration = now - self.silenceStartTime;
        self.silenceStartTime = 0.0;
        [self recordSavedTime:duration];
    }
    [self updatePlaybackRateIfNeeded];
}

- (void)recordSavedTime:(CFTimeInterval)duration {
    if (duration <= 0.05) {
        return;
    }
    YSSPreferences *prefs = [YSSPreferences shared];
    double saved = (duration / prefs.playbackSpeed) - (duration / prefs.silenceSpeed);
    if (saved <= 0.0) {
        return;
    }
    prefs.totalSaved += saved;
    prefs.lastVideoSaved += saved;
    [prefs saveStatistics];
}

static void YSSTapInit(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    *tapStorageOut = clientInfo;
}

static void YSSTapFinalize(MTAudioProcessingTapRef tap) {
}

static void YSSTapPrepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
}

static void YSSTapUnprepare(MTAudioProcessingTapRef tap) {
}

static void YSSTapProcess(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut) {
    MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, NULL, numberFramesOut);
    YSSAudioTap *self = (__bridge YSSAudioTap *)MTAudioProcessingTapGetStorage(tap);
    if (!self || !bufferListInOut) {
        return;
    }

    float sum = 0.0f;
    size_t count = 0;
    for (UInt32 i = 0; i < bufferListInOut->mNumberBuffers; i++) {
        AudioBuffer buffer = bufferListInOut->mBuffers[i];
        float *data = (float *)buffer.mData;
        if (!data) {
            continue;
        }
        UInt32 samples = buffer.mDataByteSize / sizeof(float);
        for (UInt32 j = 0; j < samples; j++) {
            float sample = data[j];
            sum += sample * sample;
        }
        count += samples;
    }

    if (count == 0) {
        return;
    }

    float rms = sqrtf(sum / (float)count);
    [self handleRMSValue:rms];
}

@end
