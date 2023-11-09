EEUPDATEARM_VERSION = develop
EEUPDATEARM_SITE = https://git1.atb-e.ru/cpu_soft/build_systems/packages/eeupdate_arm.git
EEUPDATEARM_SITE_METHOD = git

define EEUPDATEARM_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) all
endef

define EEUPDATEARM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/eeupdate_arm $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
