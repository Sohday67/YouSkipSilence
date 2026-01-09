#import "YSSRootListController.h"
#import <Cephei/HBPreferences.h>
#import "../YouSkipSilence/YSSConstants.h"

@interface YSSRootListController ()
@property (nonatomic, strong) HBPreferences *preferences;
@end

@implementation YSSRootListController

- (instancetype)init {
    self = [super init];
    if (self) {
        _preferences = [[HBPreferences alloc] initWithIdentifier:kYSSPrefsIdentifier];
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (NSString *)totalSavedText {
    double value = [self.preferences doubleForKey:kYSSPrefTotalSaved];
    return [self formattedDuration:value];
}

- (NSString *)lastSavedText {
    double value = [self.preferences doubleForKey:kYSSPrefLastSaved];
    return [self formattedDuration:value];
}

- (void)resetStatistics {
    [self.preferences setDouble:0.0 forKey:kYSSPrefTotalSaved];
    [self.preferences setDouble:0.0 forKey:kYSSPrefLastSaved];
    [self reloadSpecifiers];
}

- (NSString *)formattedDuration:(double)seconds {
    NSInteger totalSeconds = (NSInteger)round(seconds);
    NSInteger minutes = totalSeconds / 60;
    NSInteger remSeconds = totalSeconds % 60;
    return [NSString stringWithFormat:@"%ldm %lds", (long)minutes, (long)remSeconds];
}

- (BOOL)dynamicThresholdDisabled:(id)specifier {
    return ![self.preferences boolForKey:kYSSPrefDynamicThreshold];
}

@end
