#import "YSSRootListController.h"
#import "../YSSPreferences.h"
#import <CoreFoundation/CoreFoundation.h>

@implementation YSSRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
    id value = [defaults objectForKey:specifier.properties[@"key"]];
    return value ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
    [defaults setObject:value forKey:specifier.properties[@"key"]];
    [defaults synchronize];
    if ([specifier.properties[@"key"] isEqualToString:kYSSTotalSavedKey] ||
        [specifier.properties[@"key"] isEqualToString:kYSSLastVideoSavedKey]) {
        return;
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kYSSPrefsChangedNotification,
                                         NULL,
                                         NULL,
                                         true);
}

- (NSString *)formatSeconds:(double)seconds {
    NSInteger totalSeconds = (NSInteger)round(seconds);
    NSInteger minutes = totalSeconds / 60;
    NSInteger remaining = totalSeconds % 60;
    if (minutes > 0) {
        return [NSString stringWithFormat:@"%ldm %lds", (long)minutes, (long)remaining];
    }
    return [NSString stringWithFormat:@"%lds", (long)remaining];
}

- (NSString *)getTotalSaved:(PSSpecifier *)specifier {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
    double value = [[defaults objectForKey:kYSSTotalSavedKey] doubleValue];
    return [self formatSeconds:value];
}

- (NSString *)getLastSaved:(PSSpecifier *)specifier {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
    double value = [[defaults objectForKey:kYSSLastVideoSavedKey] doubleValue];
    return [self formatSeconds:value];
}

- (void)resetStatistics:(PSSpecifier *)specifier {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kYSSPrefsIdentifier];
    [defaults setObject:@0.0 forKey:kYSSTotalSavedKey];
    [defaults setObject:@0.0 forKey:kYSSLastVideoSavedKey];
    [defaults synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kYSSPrefsChangedNotification,
                                         NULL,
                                         NULL,
                                         true);
    [self reloadSpecifiers];
}

@end
