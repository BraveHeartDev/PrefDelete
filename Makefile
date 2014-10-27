include theos/makefiles/common.mk

export ARCHS = armv7 arm64
ADDITIONAL_OBJCFLAGS = -fobjc-arc

TWEAK_NAME = PrefDelete
PrefDelete_FILES = Tweak.xm
PrefDelete_FRAMEWORKS = UIKit
PrefDelete_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk


