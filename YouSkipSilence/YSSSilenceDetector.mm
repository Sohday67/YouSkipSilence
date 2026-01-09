#import "YSSSilenceDetector.h"
#import "YSSPreferences.h"
#include <math.h>

static void YSSAudioTapInit(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut);
static void YSSAudioTapFinalize(MTAudioProcessingTapRef tap);
static void YSSAudioTapPrepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat);
static void YSSAudioTapUnprepare(MTAudioProcessingTapRef tap);
static void YSSAudioTapProcess(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags,
                               AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut);

@interface YSSSilenceDetector ()
@property (nonatomic, weak) AVPlayerItem *playerItem;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) float baseline;
@property (nonatomic, assign) float lastRms;
@end

@implementation YSSSilenceDetector {
    MTAudioProcessingTapRef _tap;
}

- (instancetype)initWithPlayerItem:(AVPlayerItem *)item {
    self = [super init];
    if (self) {
        _playerItem = item;
        _baseline = 0.02f;
        _lastRms = 0.0f;
    }
    return self;
}

- (void)start {
    if (self.running || !self.playerItem) {
        return;
    }
    self.running = YES;

    MTAudioProcessingTapCallbacks callbacks;
    callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
    callbacks.clientInfo = (__bridge void *)self;
    callbacks.init = YSSAudioTapInit;
    callbacks.finalize = YSSAudioTapFinalize;
    callbacks.prepare = YSSAudioTapPrepare;
    callbacks.unprepare = YSSAudioTapUnprepare;
    callbacks.process = YSSAudioTapProcess;

    MTAudioProcessingTapRef tap = NULL;
    OSStatus status = MTAudioProcessingTapCreate(kCFAllocatorDefault,
                                                 &callbacks,
                                                 kMTAudioProcessingTapCreationFlag_PostEffects,
                                                 &tap);
    if (status != noErr || !tap) {
        self.running = NO;
        return;
    }

    _tap = tap;
    AVMutableAudioMixInputParameters *inputParams = nil;
    AVAssetTrack *audioTrack = [[self.playerItem.asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (audioTrack) {
        inputParams = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack];
        inputParams.audioTapProcessor = tap;
    }

    if (!inputParams) {
        CFRelease(tap);
        _tap = NULL;
        self.running = NO;
        return;
    }

    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    audioMix.inputParameters = @[inputParams];
    self.playerItem.audioMix = audioMix;
}

- (void)stop {
    if (!self.running) {
        return;
    }
    self.running = NO;
    if (_tap) {
        CFRelease(_tap);
        _tap = NULL;
    }
    self.playerItem.audioMix = nil;
}

- (void)handleRms:(float)rms {
    self.lastRms = rms;
    YSSPreferences *preferences = [YSSPreferences sharedInstance];
    float threshold = (float)preferences.fixedThreshold;
    if (preferences.dynamicThreshold) {
        float alpha = 0.05f;
        self.baseline = (alpha * rms) + ((1.0f - alpha) * self.baseline);
        threshold = MAX(self.baseline * 1.8f, 0.01f);
    }
    BOOL isSilent = rms < threshold;
    [self.delegate silenceDetectorDidDetectSilence:isSilent rms:rms];
}

@end

static void YSSAudioTapInit(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    *tapStorageOut = clientInfo;
}

static void YSSAudioTapFinalize(MTAudioProcessingTapRef tap) {
    (void)tap;
}

static void YSSAudioTapPrepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
    (void)tap;
    (void)maxFrames;
    (void)processingFormat;
}

static void YSSAudioTapUnprepare(MTAudioProcessingTapRef tap) {
    (void)tap;
}

static void YSSAudioTapProcess(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags,
                               AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut) {
    OSStatus status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, NULL, numberFramesOut);
    if (status != noErr) {
        return;
    }

    YSSSilenceDetector *detector = (__bridge YSSSilenceDetector *)MTAudioProcessingTapGetStorage(tap);
    if (!detector) {
        return;
    }

    float rms = 0.0f;
    if (bufferListInOut->mNumberBuffers > 0) {
        AudioBuffer buffer = bufferListInOut->mBuffers[0];
        if (buffer.mData && buffer.mDataByteSize > 0) {
            UInt32 sampleCount = buffer.mDataByteSize / sizeof(Float32);
            Float32 *samples = (Float32 *)buffer.mData;
            double sum = 0.0;
            for (UInt32 i = 0; i < sampleCount; i++) {
                float sample = samples[i];
                sum += sample * sample;
            }
            rms = (float)sqrt(sum / MAX(sampleCount, 1));
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [detector handleRms:rms];
    });
}
