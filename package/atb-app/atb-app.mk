################################################################################
#
# atb-app
#
################################################################################

ATB_APP_VERSION = develop
ATB_APP_SITE = https://git1.atb-e.ru/cpu_soft/build_systems/packages/atb-app.git
ATB_APP_SITE_METHOD = git
#ATB_APP_LICENSE = GPL-2.0
#ATB_APP_LICENSE_FILES = mmc.h
BR_NO_CHECK_HASH_FOR += atb-app-develop-br1.tar.gz
ATB_APP_CFLAGS = $(TARGET_CFLAGS)

define ATB_APP_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) all
endef

define ATB_APP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/atb-app $(TARGET_DIR)/usr/bin/atb-app
endef

$(eval $(generic-package))
