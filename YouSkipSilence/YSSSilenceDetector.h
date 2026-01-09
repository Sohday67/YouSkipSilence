#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol YSSSilenceDetectorDelegate <NSObject>
- (void)silenceDetectorDidDetectSilence:(BOOL)isSilent rms:(float)rms;
@end

@interface YSSSilenceDetector : NSObject

@property (nonatomic, weak) id<YSSSilenceDetectorDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL running;

- (instancetype)initWithPlayerItem:(AVPlayerItem *)item;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
