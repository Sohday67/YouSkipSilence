#pragma once

#import <Foundation/Foundation.h>

#if __has_include_next(<YTVideoOverlay/Header.h>)
#import_next <YTVideoOverlay/Header.h>
#else
// Keys used by YTVideoOverlay for tweak registration
static NSString *const AccessibilityLabelKey = @"accessibilityLabel";
static NSString *const ToggleKey = @"toggle";
static NSString *const AsTextKey = @"asText";
static NSString *const SelectorKey = @"selector";
static NSString *const UpdateImageOnVisibleKey = @"updateImageOnVisible";
static NSString *const ExtraBooleanKeys = @"extraBooleanKeys";
#endif
