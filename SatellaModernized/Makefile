# Basic environment configuration

export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64 arm64e

# Rootless support
export THEOS_PACKAGE_SCHEME = rootless

# Theos optimisations
export FINALPACKAGE = 1
export DEBUG = 0
export THEOS_LEAN_AND_MEAN = 1
export USING_JINX = 1

# Define subprojects
SUBPROJECTS += Tweak
SUBPROJECTS += Prefs

# Theos makefiles to include
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

internal-stage::
	# Tweak Filter
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries$(ECHO_END)
	$(ECHO_NOTHING)cp Tweak/SatellaJailed.plist $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/SatellaJailed.plist$(ECHO_END)
	
	# PreferenceLoader Entry
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)echo '{"entry" = {"bundle" = "SatellaJailedPrefs"; "cell" = "PSLinkCell"; "detail" = "SatellaRootListController"; "icon" = "icon.png"; "isController" = 1; "label" = "Satella Modernized";};}' > $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SatellaJailed.plist$(ECHO_END)
	$(ECHO_NOTHING)chmod 644 $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SatellaJailed.plist$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SatellaJailedPrefs.bundle -maxdepth 1 -type f -name 'icon*.png' -exec chmod 644 {} \;$(ECHO_END)
