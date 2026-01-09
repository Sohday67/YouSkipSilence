#pragma once

#import <Foundation/Foundation.h>

#if __has_include_next(<YTVideoOverlay/Header.h>)
#import_next <YTVideoOverlay/Header.h>
#else
static NSString *const AccessibilityLabelKey = @"AccessibilityLabelKey";
static NSString *const SelectorKey = @"SelectorKey";
static NSString *const UpdateImageOnVisibleKey = @"UpdateImageOnVisibleKey";
static NSString *const ExtraBooleanKeys = @"ExtraBooleanKeys";
#endif
