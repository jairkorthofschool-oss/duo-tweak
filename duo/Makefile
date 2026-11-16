SDKVER ?= 14.5
TARGET := iphone:clang:$(SDKVER):14.0
THEOS_PACKAGE_SCHEME := rootless
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := DuoTweak
DuoTweak_FILES := Tweak.x
DuoTweak_FRAMEWORKS := UIKit Foundation CoreMotion
DuoTweak_CFLAGS := -fobjc-arc -Wno-deprecated-declarations

BUNDLE_NAME := DuoTweakPrefs
DuoTweakPrefs_FILES := DuoTweakPrefs/DuoTweakPrefsListController.m
DuoTweakPrefs_PRIVATE_FRAMEWORKS := Preferences
DuoTweakPrefs_FRAMEWORKS := UIKit Foundation
DuoTweakPrefs_CFLAGS := -fobjc-arc -Wno-deprecated-declarations
DuoTweakPrefs_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
