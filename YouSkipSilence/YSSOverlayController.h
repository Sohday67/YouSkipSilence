#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface YSSOverlayController : NSObject
+ (instancetype)sharedController;
- (void)installOverlayInViewController:(UIViewController *)controller;
@end

NS_ASSUME_NONNULL_END
