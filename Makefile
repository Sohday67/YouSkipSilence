ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET = iphone:clang:latest:15.0
else ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
	TARGET = iphone:clang:latest:15.0
else
	TARGET = iphone:clang:latest:11.0
endif
INSTALL_TARGET_PROCESSES = YouTube
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YouSkipSilence

$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include
$(TWEAK_NAME)_FRAMEWORKS = UIKit AVFoundation CoreMedia QuartzCore MediaToolbox

include $(THEOS_MAKE_PATH)/tweak.mk
