TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YouSkipSilence
YouSkipSilence_FILES = Tweak.xm \
  YouSkipSilence/YSSManager.m \
  YouSkipSilence/YSSConstants.m \
  YouSkipSilence/YSSPreferences.m \
  YouSkipSilence/YSSSilenceDetector.mm \
  YouSkipSilence/YSSOverlayController.m
YouSkipSilence_CFLAGS = -fobjc-arc
YouSkipSilence_FRAMEWORKS = AVFoundation UIKit
YouSkipSilence_PRIVATE_FRAMEWORKS = MediaToolbox

SUBPROJECTS += Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
