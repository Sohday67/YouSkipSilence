#import <UIKit/UIKit.h>
#import "YouSkipSilence/YSSManager.h"
#import "YouSkipSilence/YSSOverlayController.h"

%hook YTPlayerViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [[YSSManager sharedManager] attachToPlayerViewController:self];
    [[YSSOverlayController sharedController] installOverlayInViewController:self];
}

%end

%hook YTAVPlayer

- (void)setRate:(float)rate {
    %orig(rate);
    [[YSSManager sharedManager] handlePlaybackRateChange:rate];
}

%end
