TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = YouSkipSilencePrefs
YouSkipSilencePrefs_FILES = YSSRootListController.m
YouSkipSilencePrefs_FRAMEWORKS = UIKit
YouSkipSilencePrefs_PRIVATE_FRAMEWORKS = Preferences
YouSkipSilencePrefs_EXTRA_FRAMEWORKS = CepheiPrefs
YouSkipSilencePrefs_INSTALL_PATH = /Library/PreferenceBundles
YouSkipSilencePrefs_ENTRY_PLIST = entry.plist
YouSkipSilencePrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
