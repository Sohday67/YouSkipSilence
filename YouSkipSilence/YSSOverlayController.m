#import "YSSOverlayController.h"
#import "YSSPreferences.h"
#import "YSSManager.h"
#import <objc/message.h>

@interface YSSOverlayController ()
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, weak) UIViewController *controller;
@end

@implementation YSSOverlayController

+ (instancetype)sharedController {
    static YSSOverlayController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YSSOverlayController alloc] init];
    });
    return sharedInstance;
}

- (void)installOverlayInViewController:(UIViewController *)controller {
    if (self.button) {
        self.controller = controller;
        [self updateButtonState];
        return;
    }
    self.controller = controller;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    button.layer.cornerRadius = 14.0;
    button.layer.masksToBounds = YES;
    button.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
    [button addTarget:self action:@selector(toggleEnabled) forControlEvents:UIControlEventTouchUpInside];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showPopup:)];
    [button addGestureRecognizer:longPress];

    self.button = button;
    UIView *overlayView = [self findOverlayContainerInController:controller] ?: controller.view;
    [overlayView addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:overlayView.trailingAnchor constant:-16],
        [button.bottomAnchor constraintEqualToAnchor:overlayView.bottomAnchor constant:-90]
    ]];

    [self updateButtonState];
}

- (UIView *)findOverlayContainerInController:(UIViewController *)controller {
    id overlayManager = [self videoOverlayManager];
    if (overlayManager && [overlayManager respondsToSelector:@selector(overlayView)]) {
        UIView *view = ((UIView *(*)(id, SEL))objc_msgSend)(overlayManager, @selector(overlayView));
        if ([view isKindOfClass:[UIView class]]) {
            return view;
        }
    }
    return controller.view;
}

- (id)videoOverlayManager {
    Class overlayClass = NSClassFromString(@"YTVideoOverlay");
    if (overlayClass && [overlayClass respondsToSelector:@selector(sharedInstance)]) {
        return ((id (*)(id, SEL))objc_msgSend)(overlayClass, @selector(sharedInstance));
    }
    return nil;
}

- (void)toggleEnabled {
    YSSPreferences *preferences = [YSSPreferences sharedInstance];
    BOOL enabled = !preferences.enabled;
    [preferences setEnabled:enabled];
    [[YSSManager sharedManager] setEnabled:enabled];
    [self updateButtonState];
}

- (void)updateButtonState {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImage *image = nil;
    if ([YSSPreferences sharedInstance].enabled) {
        image = [UIImage systemImageNamed:@"speaker.wave.2" withConfiguration:config];
    } else {
        image = [UIImage systemImageNamed:@"speaker.slash" withConfiguration:config];
    }
    [self.button setImage:image forState:UIControlStateNormal];
    self.button.tintColor = [YSSPreferences sharedInstance].enabled ? [UIColor systemGreenColor] : [UIColor systemGrayColor];
}

- (void)showPopup:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Skip Silence" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [self addSpeedActionsToAlert:alert title:@"Playback Speed" currentValue:[YSSPreferences sharedInstance].playbackSpeed selector:@selector(updatePlaybackSpeed:) presets:@[@1.1, @1.2, @1.3, @1.4, @1.5]];
    [self addSpeedActionsToAlert:alert title:@"Silence Speed" currentValue:[YSSPreferences sharedInstance].silenceSpeed selector:@selector(updateSilenceSpeed:) presets:@[@1.5, @2.0, @2.5, @3.0]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];

    alert.popoverPresentationController.sourceView = self.button;
    alert.popoverPresentationController.sourceRect = self.button.bounds;

    [self.controller presentViewController:alert animated:YES completion:nil];
}

- (void)addSpeedActionsToAlert:(UIAlertController *)alert title:(NSString *)title currentValue:(double)currentValue selector:(SEL)selector presets:(NSArray<NSNumber *> *)presets {
    NSString *header = [NSString stringWithFormat:@"%@ (current %.2fx)", title, currentValue];
    [alert addAction:[UIAlertAction actionWithTitle:header style:UIAlertActionStyleDefault handler:nil]];
    for (NSNumber *preset in presets) {
        NSString *titleString = [NSString stringWithFormat:@"%.1fx", preset.doubleValue];
        UIAlertAction *action = [UIAlertAction actionWithTitle:titleString style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self performSelector:selector withObject:preset];
        }];
        [alert addAction:action];
    }
    UIAlertAction *custom = [UIAlertAction actionWithTitle:@"Custom…" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
        [self promptForCustomSpeedWithTitle:title selector:selector];
    }];
    [alert addAction:custom];
}

- (void)promptForCustomSpeedWithTitle:(NSString *)title selector:(SEL)selector {
    UIAlertController *input = [UIAlertController alertControllerWithTitle:title message:@"Enter a custom speed" preferredStyle:UIAlertControllerStyleAlert];
    [input addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.placeholder = @"1.0";
    }];

    UIAlertAction *save = [UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *text = input.textFields.firstObject.text;
        double value = text.doubleValue;
        [self performSelector:selector withObject:@(value)];
    }];
    [input addAction:save];
    [input addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    [self.controller presentViewController:input animated:YES completion:nil];
}

- (void)updatePlaybackSpeed:(NSNumber *)value {
    double speed = MAX(1.0, value.doubleValue);
    [[YSSPreferences sharedInstance] setPlaybackSpeed:speed];
    [[YSSManager sharedManager] setEnabled:[YSSPreferences sharedInstance].enabled];
}

- (void)updateSilenceSpeed:(NSNumber *)value {
    double speed = MAX(1.0, value.doubleValue);
    [[YSSPreferences sharedInstance] setSilenceSpeed:speed];
    [[YSSManager sharedManager] setEnabled:[YSSPreferences sharedInstance].enabled];
}

@end
