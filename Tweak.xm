#import <AVFoundation/AVFoundation.h>
#import "YSSManager.h"
#import "YSSOverlay.h"
#import "YSSPreferences.h"
#import "YSSAudioTap.h"

%hook AVPlayer

- (void)replaceCurrentItemWithPlayerItem:(AVPlayerItem *)item {
    %orig;
    [[YSSManager shared] attachToPlayer:self item:item];
}

- (void)play {
    %orig;
    [[YSSManager shared] playerDidStartPlayback:self];
}

%end

%hook UIApplication

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;
    [[YSSPreferences shared] reload];
    [[YSSOverlay shared] installOverlayIfNeeded];
}

%end

%ctor {
    [[YSSPreferences shared] reload];
    [[NSNotificationCenter defaultCenter] addObserverForName:@"YouSkipSilencePreferencesChanged"
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(__unused NSNotification *note) {
        [[YSSPreferences shared] reload];
        [[YSSOverlay shared] updateButtonState];
        [[YSSAudioTap shared] updatePlaybackRateIfNeeded];
    }];
}
