#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YSSOverlay : NSObject
+ (instancetype)shared;
- (void)installOverlayIfNeeded;
- (void)updateButtonState;
@end

NS_ASSUME_NONNULL_END
