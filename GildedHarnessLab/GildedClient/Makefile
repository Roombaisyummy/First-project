ARCHS = arm64
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Gilded
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Gilded
Gilded_FILES = $(shell find Sources -name '*.swift')
Gilded_RESOURCE_FILES = Info.plist AppIcon60x60@2x.png AppIcon60x60@3x.png
Gilded_FRAMEWORKS = SwiftUI UIKit StoreKit
Gilded_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
