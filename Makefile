ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:13.0
INSTALL_TARGET_PROCESSES = YouTube

THEOS_PACKAGE_SCHEME = rootless

TWEAK_NAME = YouSkipSilence
YouSkipSilence_FILES = Tweak.xm \
	YSSManager.m \
	YSSAudioTap.m \
	YSSOverlay.m \
	YSSPreferences.m
YouSkipSilence_CFLAGS = -fobjc-arc
YouSkipSilence_FRAMEWORKS = UIKit AVFoundation MediaToolbox
YouSkipSilence_LIBRARIES =

BUNDLE_NAME = YouSkipSilencePrefs
YouSkipSilencePrefs_FILES = Preferences/YSSRootListController.m
YouSkipSilencePrefs_INSTALL_PATH = /Library/PreferenceBundles
YouSkipSilencePrefs_FRAMEWORKS = UIKit
YouSkipSilencePrefs_PRIVATE_FRAMEWORKS = Preferences
YouSkipSilencePrefs_LIBRARIES =
YouSkipSilencePrefs_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
