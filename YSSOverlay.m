#import "YSSOverlay.h"
#import "YSSPreferences.h"
#import "YSSAudioTap.h"
#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>

@interface YSSOverlay ()
@property (nonatomic, strong) UIButton *toggleButton;
@end

@implementation YSSOverlay

+ (instancetype)shared {
    static YSSOverlay *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)installOverlayIfNeeded {
    if (self.toggleButton) {
        return;
    }

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(12, 100, 32, 32);
    button.layer.cornerRadius = 6.0;
    button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    [button addTarget:self action:@selector(toggleTapped) forControlEvents:UIControlEventTouchUpInside];

    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [button addGestureRecognizer:press];

    self.toggleButton = button;
    [self updateButtonState];

    UIView *overlayView = [self resolveOverlayContainer];
    if (overlayView) {
        [overlayView addSubview:button];
    }
}

- (UIWindow *)currentKeyWindow {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) {
            continue;
        }
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
    }
    return [UIApplication sharedApplication].windows.firstObject;
}

- (UIView *)resolveOverlayContainer {
    Class overlayClass = NSClassFromString(@"YTVideoOverlay");
    if (overlayClass && [overlayClass respondsToSelector:@selector(sharedOverlay)]) {
        id overlay = [overlayClass performSelector:@selector(sharedOverlay)];
        if ([overlay respondsToSelector:@selector(overlayView)]) {
            return [overlay performSelector:@selector(overlayView)];
        }
        if ([overlay respondsToSelector:@selector(containerView)]) {
            return [overlay performSelector:@selector(containerView)];
        }
    }

    UIWindow *keyWindow = [self currentKeyWindow];
    return keyWindow.rootViewController.view;
}

- (void)toggleTapped {
    YSSPreferences *prefs = [YSSPreferences shared];
    prefs.enabled = !prefs.enabled;
    HBPreferences *hbPrefs = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    [hbPrefs setBool:prefs.enabled forKey:kYSSEnabledKey];
    [self updateButtonState];
    [[YSSAudioTap shared] updatePlaybackRateIfNeeded];
}

- (void)updateButtonState {
    if (!self.toggleButton) {
        return;
    }
    BOOL enabled = [YSSPreferences shared].enabled;
    NSString *symbol = enabled ? @"speaker.wave.2.fill" : @"speaker.slash.fill";
    UIImage *image = [UIImage systemImageNamed:symbol];
    [self.toggleButton setImage:image forState:UIControlStateNormal];
    self.toggleButton.tintColor = enabled ? [UIColor systemGreenColor] : [UIColor systemRedColor];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    [self presentSpeedSelector];
}

- (void)presentSpeedSelector {
    UIViewController *presenter = [self topViewController];
    if (!presenter) {
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"YouSkipSilence" message:@"Adjust speeds" preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Playback Speed" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentPlaybackSelectorFrom:presenter];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Silence Speed" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentSilenceSelectorFrom:presenter];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:sheet animated:YES completion:nil];
}

- (void)presentPlaybackSelectorFrom:(UIViewController *)presenter {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Playback Speed" message:@"Choose a preset or enter custom" preferredStyle:UIAlertControllerStyleAlert];
    NSArray<NSNumber *> *presets = @[@1.1, @1.2, @1.3, @1.4, @1.5];
    for (NSNumber *preset in presets) {
        NSString *title = [NSString stringWithFormat:@"%@x", preset];
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self updatePlaybackSpeed:preset.floatValue];
        }]];
    }

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Custom (e.g. 1.25)";
        field.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Set Custom" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        float value = alert.textFields.firstObject.text.floatValue;
        if (value > 0.0f) {
            [self updatePlaybackSpeed:value];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)presentSilenceSelectorFrom:(UIViewController *)presenter {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Silence Speed" message:@"Choose a preset or enter custom" preferredStyle:UIAlertControllerStyleAlert];
    NSArray<NSNumber *> *presets = @[@1.5, @2.0, @2.5, @3.0];
    for (NSNumber *preset in presets) {
        NSString *title = [NSString stringWithFormat:@"%@x", preset];
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self updateSilenceSpeed:preset.floatValue];
        }]];
    }

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Custom (e.g. 2.2)";
        field.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Set Custom" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        float value = alert.textFields.firstObject.text.floatValue;
        if (value > 0.0f) {
            [self updateSilenceSpeed:value];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)updatePlaybackSpeed:(float)value {
    YSSPreferences *prefs = [YSSPreferences shared];
    prefs.playbackSpeed = value;
    HBPreferences *hbPrefs = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    [hbPrefs setObject:@(value) forKey:kYSSPlaybackSpeedKey];
    [[YSSAudioTap shared] updatePlaybackRateIfNeeded];
}

- (void)updateSilenceSpeed:(float)value {
    YSSPreferences *prefs = [YSSPreferences shared];
    prefs.silenceSpeed = value;
    HBPreferences *hbPrefs = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    [hbPrefs setObject:@(value) forKey:kYSSSilenceSpeedKey];
    [[YSSAudioTap shared] updatePlaybackRateIfNeeded];
}

- (UIViewController *)topViewController {
    UIViewController *root = [self currentKeyWindow].rootViewController;
    UIViewController *top = root;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    return top;
}

@end
