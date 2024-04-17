#!/bin/bash

# This command is used to print each being executed line of script
# set -x

# This command is used to stop script execution after a command finished with non zero value
set -e

# Buildroot Enviroment Variables:
# $BR2_CONFIG   - "output/.config"
# $BUILD_DIR    - "output/build"
# $TARGET_DIR   - "output/build"
# $BINARIES_DIR - "output/images"
# $BR2_DL_DIR   - "buildroot/dl"

check_file()
{
	if ! [ -f ${1} ]; then
		echo
		echo "ERROR: File not found. ${1}"
		echo
		exit -1
	fi
}

# rkbin from github: https://gitlab.com/firefly-linux/rkbin.git
RKBIN_LINK=https://gitlab.com/firefly-linux/rkbin/-/archive/rk3588/linux_release_v1.3.0e/rkbin-rk3588-linux_release_v1.3.0e.tar.gz

# Download archive to dl folder (if not exist)
if ! [ -f ${BR2_DL_DIR}/rkbin/rkbin-rk3588-linux_release_v1.3.0e.tar.gz ]; then
	wget ${RKBIN_LINK} -P ${BR2_DL_DIR}/rkbin/
fi

tar -xf ${BR2_DL_DIR}/rkbin/rkbin-rk3588-linux_release_v1.3.0e.tar.gz -C ${BUILD_DIR}
RKBIN_DIR=${BUILD_DIR}/rkbin-rk3588-linux_release_v1.3.0e

################################################################################
# 1. Create idbloader.img

SPL_FILE_NAME=u-boot-spl.bin
TPL_FILE_NAME=rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin

# SPL being compiled from sources
SPL_BIN=${BINARIES_DIR}/${SPL_FILE_NAME}

# TPL binary from Rockchip
TPL_BIN=${RKBIN_DIR}/bin/rk35/${TPL_FILE_NAME}

CUSTOM_TPL=${RKBIN_DIR}/bin/rk35/custom_${TPL_FILE_NAME}

#-------------------------------------------------------------------------------
# TPL custom configuration
TPL_CONFIG=${RKBIN_DIR}/tools/tpl_custom_config.txt

rm -f ${TPL_CONFIG} ${CUSTOM_TPL}
cp -f ${TPL_BIN} ${CUSTOM_TPL}

# get
${RKBIN_DIR}/tools/ddrbin_tool rk3588 -g ${TPL_CONFIG} ${CUSTOM_TPL}

sed -i 's/uart baudrate=1500000/uart baudrate=115200/g' ${TPL_CONFIG}
sed -i 's/lp4_freq=2112/lp4_freq=1560/g' ${TPL_CONFIG}
sed -i 's/lp4x_freq=2112/lp4x_freq=1560/g' ${TPL_CONFIG}

# set
${RKBIN_DIR}/tools/ddrbin_tool rk3588 ${TPL_CONFIG} ${CUSTOM_TPL}
#-------------------------------------------------------------------------------

UBOOT_REPO=$(cat $BR2_CONFIG | grep BR2_TARGET_UBOOT_CUSTOM_REPO_VERSION | awk -F= '{print $2}' | awk -F\" '{print $2}')

check_file ${CUSTOM_TPL}
check_file ${SPL_BIN}

${BUILD_DIR}/uboot-${UBOOT_REPO}/tools/mkimage -n "rk3588" -T rksd -d ${CUSTOM_TPL}:${SPL_BIN} ${BINARIES_DIR}/idbloader.img

################################################################################
# 2. Create u-boot.itb
UBOOT_BIN=${BUILD_DIR}/u-boot.bin

# Trusted Firmware-A (TF-A)
BL31=${RKBIN_DIR}/bin/rk35/rk3588_bl31_v1.42.elf
BL32=${RKBIN_DIR}/bin/rk35/rk3588_bl32_v1.14.bin

check_file ${BL31}
check_file ${BL32}

cp -f ${BL31} ${BUILD_DIR}/uboot-${UBOOT_REPO}/bl31.elf
cp -f ${BL32} ${BUILD_DIR}/uboot-${UBOOT_REPO}/tee.bin

# The script make_fit_atf.sh requires working directory u-boot
cd ${BUILD_DIR}/uboot-${UBOOT_REPO}

arch/arm/mach-rockchip/make_fit_atf.sh -t 0x08400000 > u-boot.its

tools/mkimage -f u-boot.its -E ${BINARIES_DIR}/u-boot.itb
