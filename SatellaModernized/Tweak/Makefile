# Theos optimisations

ARCHS = arm64 arm64e

ifeq ($(ROOTLESS),1)
	TARGET = iphone:clang:latest:15.0
endif


# Processes die if they are killed

INSTALL_TARGET_PROCESSES = SpringBoard

# Prefer a local SwiftPM checkout so Linux builds do not depend on Xcode.
JINX_PATH ?= $(CURDIR)/.build/checkouts/Jinx/Sources/Jinx

ifeq ($(wildcard $(JINX_PATH)),)
XCODE_DERIVED_DATA ?= $(HOME)/Library/Developer/Xcode/DerivedData
XCODE_JINX_PATH := $(shell find "$(XCODE_DERIVED_DATA)" -maxdepth 4 -type d -path "*/SourcePackages/checkouts/Jinx/Sources/Jinx" 2>/dev/null | head -n 1)
JINX_PATH := $(XCODE_JINX_PATH)
endif

ifeq ($(strip $(JINX_PATH)),)
$(error Could not locate Jinx sources. Set JINX_PATH=/path/to/Jinx/Sources/Jinx or run 'swift package resolve' in Tweak/)
endif

# Define included files, imported frameworks, etc.

LIBRARY_NAME = SatellaJailed
$(LIBRARY_NAME)_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

# Include stealth C sources
STEALTH_C_FILES = $(shell find Sources/Stealth -name '*.c' -o -name '*.m' 2>/dev/null)
$(LIBRARY_NAME)_CFLAGS += -ISources/Stealth

$(LIBRARY_NAME)_FILES = Sources/load.s \
    $(shell find Sources/$(LIBRARY_NAME) -name '*.swift') \
    $(shell find $(JINX_PATH) -name '*.swift') \
    $(STEALTH_C_FILES)

# Installation logic
internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries$(ECHO_END)
	$(ECHO_NOTHING)cp SatellaJailed.plist $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/SatellaJailed.plist$(ECHO_END)

# Theos makefiles to include

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/library.mk
