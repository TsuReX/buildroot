################################################################################
#
# v4l2loopback
#
################################################################################

ATB_CAN_VERSION = main
ATB_CAN_SITE = https://git1.atb-e.ru/cpu_soft/build_systems/packages/atb_can.git
ATB_CAN_SITE_METHOD = git

ifeq ($(BR2_PACKAGE_ATB_CAN_UTILS),y)
define ATB_CAN_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/utils/atb_candump/atb_candump $(TARGET_DIR)/home/atb_can/atb_candump
	$(INSTALL) -D -m 0755 $(@D)/utils/atb_cansend/atb_cansend  $(TARGET_DIR)/home/atb_can/atb_cansend
	$(INSTALL) -D -m 0755 $(@D)/driver/atb_mcp2518/atb_mcp.ko  $(TARGET_DIR)/home/atb_can/atb_mcp.ko
endef
endif

$(eval $(kernel-module))

define ATB_CAN_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) all
endef

$(eval $(generic-package))
