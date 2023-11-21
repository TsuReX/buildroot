################################################################################
#
# edk2
#
################################################################################

QUARTZ64_UEFI_VERSION = v1.1
QUARTZ64_UEFI_SITE = https://github.com/jaredmcneill/quartz64_uefi
QUARTZ64_UEFI_SITE_METHOD = git
QUARTZ64_UEFI_LICENSE = BSD-2-Clause-Patent
QUARTZ64_UEFI_LICENSE_FILES = License.txt
QUARTZ64_UEFI_CPE_ID_VENDOR = tianocore
QUARTZ64_UEFI_DEPENDENCIES = host-python3 host-acpica host-util-linux
QUARTZ64_UEFI_INSTALL_TARGET = NO
QUARTZ64_UEFI_INSTALL_IMAGES = YES

ifeq ($(QUARTZ64_UEFI_BUILD_DEBUG),y)
QUARTZ64_UEFI_BUILD_TYPE = DEBUG
else 
QUARTZ64_UEFI_BUILD_TYPE = RELEASE
endif

# Build system notes.
#
# The EDK2 build system is rather unique, so here are a few useful notes.
#
# First, builds rely heavily on Git submodules to fetch various dependencies
# into specific directory structures. It might be possible to work around this
# and rely on Buildroot's infrastructure, but using Git submodules greatly
# simplifies this already complicated build system.
#
# Second, the build system is spread across various commands and stages.
# Therefore, all build variables needs to be exported to be available
# accordingly. The first stage will build $(@D)/BaseTools which contains
# various tools and scripts for the host.
#
# Third, where applicable, the dependency direction between EDK2 and
# ARM Trusted Firmware (ATF) will go in different direction for different
# platforms. Most commonly, ATF will depend on EDK2 via the BL33 payload.
# But for some platforms (e.g. QEMU SBSA or DeveloperBox) EDK2 will package
# the ATF images within its own build system. In such cases, intermediary
# "EDK2 packages" will be built in $(EDK2_BUILD_PACKAGES) in order for EDK2
# to be able to use them in subsequent build stages.
#
# For more information about the build setup:
# https://edk2-docs.gitbook.io/edk-ii-build-specification/4_edk_ii_build_process_overview

QUARTZ64_UEFI_GIT_SUBMODULES = YES
QUARTZ64_UEFI_BUILD_PACKAGES = $(@D)/Build/Buildroot
QUARTZ64_UEFI_PACKAGES_PATH = $(@D):$(QUARTZ64_UEFI_BUILD_PACKAGES):$(STAGING_DIR)/usr/share/edk2-platforms

ifeq ($(BR2_TARGET_QUARTZ64_UEFI_PLATFORM_ARM_ATB_RK3568_SMC),y)
QUARTZ64_UEFI_ARCH = AARCH64
QUARTZ64_UEFI_PACKAGE_NAME = ATB-RK3568
QUARTZ64_UEFI_PLATFORM_NAME = ATB-RK3568
QUARTZ64_UEFI_BUILD_DIR = $(QUARTZ64_UEFI_PLATFORM_NAME)
QUARTZ64_UEFI_SOURCE = edk2-$(QUARTZ64_UEFI_VERSION).tar.gz
BR_NO_CHECK_HASH_FOR += $(QUARTZ64_UEFI_SOURCE)
QUARTZ64_UEFI_PACKAGES_PATH=$(@D)/edk2:$(@D)/edk2-platforms:$(@D)/edk2-non-osi:$(@D)/edk2-rockchip
endif

QUARTZ64_UEFI_BASETOOLS_OPTS = \
	EXTRA_LDFLAGS="$(HOST_LDFLAGS)" \
	EXTRA_OPTFLAGS="$(HOST_CPPFLAGS)"

QUARTZ64_UEFI_BUILD_ENV += \
	WORKSPACE=$(@D) \
	PACKAGES_PATH=$(QUARTZ64_UEFI_PACKAGES_PATH) \
	PYTHON_COMMAND=$(HOST_DIR)/bin/python3 \
	IASL_PREFIX=$(HOST_DIR)/bin/ \
	NASM_PREFIX=$(HOST_DIR)/bin/ \
	GCC5_$(QUARTZ64_UEFI_ARCH)_PREFIX=$(TARGET_CROSS)

QUARTZ64_UEFI_BUILD_OPTS = \
	-t GCC5 \
	-n $(BR2_JLEVEL) \
	-a $(QUARTZ64_UEFI_ARCH) \
	-b $(QUARTZ64_UEFI_BUILD_TYPE) \
	-p Platform/ATB/${QUARTZ64_UEFI_PACKAGE_NAME}/${QUARTZ64_UEFI_PLATFORM_NAME}.dsc

define QUARTZ64_UEFI_BUILD_CMDS
	mkdir -p $(QUARTZ64_UEFI_BUILD_PACKAGES)
	export $(QUARTZ64_UEFI_BUILD_ENV) && \
	unset ARCH && \
	source $(@D)/edk2/edksetup.sh && \
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/edk2/BaseTools $(QUARTZ64_UEFI_BASETOOLS_OPTS) && \
	build $(QUARTZ64_UEFI_BUILD_OPTS)
endef

define QUARTZ64_UEFI_INSTALL_IMAGES_CMDS
	cp -f $(@D)/Build/$(QUARTZ64_UEFI_BUILD_DIR)/$(QUARTZ64_UEFI_BUILD_TYPE)_GCC5/FV/*.fd $(BINARIES_DIR)
endef

$(eval $(generic-package))
