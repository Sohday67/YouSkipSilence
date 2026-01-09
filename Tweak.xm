#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "YSSManager.h"
#import "YSSOverlay.h"
#import "YSSPreferences.h"
#import "YSSAudioTap.h"

static void YSSPreferencesDidChange(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

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
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    YSSPreferencesDidChange,
                                    (__bridge CFStringRef)kYSSPrefsChangedNotification,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

static void YSSPreferencesDidChange(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[YSSPreferences shared] reload];
    [[YSSOverlay shared] updateButtonState];
    [[YSSAudioTap shared] updatePlaybackRateIfNeeded];
}
