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

# rkbin from github: https://github.com/rockchip-linux/rkbin.git
tar -xf ${BR2_DL_DIR}/rkbin/rkbin-b4558da0860ca48bf1a571dd33ccba580b9abe23.tar.gz -C ${BUILD_DIR}
RKBIN_DIR=${BUILD_DIR}/rkbin

################################################################################
# 1. Create idbloader.img

SPL_BIN=u-boot-spl.bin
TPL_BIN=rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.12.bin

# SPL being compiled from sources
SPL_BIN_PATH=${BINARIES_DIR}/${SPL_BIN}

# SPL binary from Rockchip
# SPL_BIN_PATH=${RKBIN_DIR}/bin/rk35/${SPL_BIN}

# TPL binary from Rockchip
TPL_BIN_PATH=${RKBIN_DIR}/bin/rk35/${TPL_BIN}

UART_TPL_BIN=uart_115200_${TPL_BIN}

sed 's/uart baudrate=/uart baudrate=115200/g' ${RKBIN_DIR}/tools/ddrbin_param.txt > ${RKBIN_DIR}/tools/ddrbin_param_115200.txt

cp -f ${TPL_BIN_PATH} ${RKBIN_DIR}/bin/rk35/${UART_TPL_BIN}

${RKBIN_DIR}/tools/ddrbin_tool ${RKBIN_DIR}/tools/ddrbin_param_115200.txt ${RKBIN_DIR}/bin/rk35/${UART_TPL_BIN}

TPL_BIN_PATH=${RKBIN_DIR}/bin/rk35/${UART_TPL_BIN}

UBOOT_REPO=$(cat $BR2_CONFIG | grep BR2_TARGET_UBOOT_CUSTOM_REPO_VERSION | awk -F= '{print $2}' | awk -F\" '{print $2}')

check_file ${TPL_BIN_PATH}
check_file ${SPL_BIN_PATH}

${BUILD_DIR}/uboot-${UBOOT_REPO}/tools/mkimage -n "rk3588" -T rksd -d ${TPL_BIN_PATH}:${SPL_BIN_PATH} ${BINARIES_DIR}/idbloader.img

################################################################################
# 2. Create u-boot.itb
UBOOT_BIN=${BUILD_DIR}/u-boot.bin

check_file ${RKBIN_DIR}/bin/rk35/rk3588_bl31_v1.40.elf
check_file ${RKBIN_DIR}/bin/rk35/rk3588_bl32_v1.13.bin

cp -f ${RKBIN_DIR}/bin/rk35/rk3588_bl31_v1.40.elf ${BUILD_DIR}/uboot-${UBOOT_REPO}/bl31.elf
cp -f ${RKBIN_DIR}/bin/rk35/rk3588_bl32_v1.13.bin ${BUILD_DIR}/uboot-${UBOOT_REPO}/tee.bin

# The script make_fit_atf.sh requires working directory u-boot
cd ${BUILD_DIR}/uboot-${UBOOT_REPO}

arch/arm/mach-rockchip/make_fit_atf.sh -t 0x08400000 > u-boot.its

tools/mkimage -f u-boot.its -E ${BINARIES_DIR}/u-boot.itb
