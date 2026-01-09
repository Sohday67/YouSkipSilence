#import "YSSRootListController.h"
#import "../YSSPreferences.h"
#import <Cephei/HBPreferences.h>

@implementation YSSRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    return [prefs objectForKey:specifier.properties[@"key"]] ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    [prefs setObject:value forKey:specifier.properties[@"key"]];
    if ([specifier.properties[@"key"] isEqualToString:kYSSTotalSavedKey] ||
        [specifier.properties[@"key"] isEqualToString:kYSSLastVideoSavedKey]) {
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YouSkipSilencePreferencesChanged" object:nil];
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
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    double value = [[prefs objectForKey:kYSSTotalSavedKey] doubleValue];
    return [self formatSeconds:value];
}

- (NSString *)getLastSaved:(PSSpecifier *)specifier {
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    double value = [[prefs objectForKey:kYSSLastVideoSavedKey] doubleValue];
    return [self formatSeconds:value];
}

- (void)resetStatistics:(PSSpecifier *)specifier {
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    [prefs setObject:@0.0 forKey:kYSSTotalSavedKey];
    [prefs setObject:@0.0 forKey:kYSSLastVideoSavedKey];
    [self reloadSpecifiers];
}

@end
