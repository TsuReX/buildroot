#!/bin/bash

# Debugging options
# This command is used to print each being executed line of script
#set -x
# This command is used to stop script execution after a command finished with non zero value
#set -e

# ${0} - path to current script
# ${1} - path to images directory
# ${2} - being used dtd file

DTB_NAME=$2
BOARD_DIR=`dirname ${BR2_DL_DIR}`/`dirname $0`

# BUILD_DIR - is a buildroot environment variable
# TARGET_DIR - - is a buildroot environment variable
IMAGES_DIR=${BINARIES_DIR}

if ! [ $# == 2 ]; then
    echo "Invalid arguments"
    echo "The script requres the following arguments: path_to_images_folder linux_dtb_file_name.dtb"
    exit -1
fi

if ! [ -d ${BUILD_DIR}/rkbin ]; then
	# Copying necessary files into output/images/rkbin form git repository
	#git clone --single-branch --branch rk356x/linux_release_v1.3.0a https://gitlab.com/firefly-linux/rkbin ${BUILD_DIR}/rkbin
	git clone --single-branch --branch master https://github.com/rockchip-linux/rkbin.git ${BUILD_DIR}/rkbin
fi

##################################################################################
# 1. Create idblock.bin

SPL_BIN=u-boot-spl.bin

TPL_BIN=rk3568_ddr_1560MHz_v1.18.bin

# SPL being compiled from sources
SPL_BIN_PATH=${IMAGES_DIR}/${SPL_BIN}

# SPL binary from Rockchip
#SPL_BIN_PATH=${BUILD_DIR}/rkbin/bin/rk35/${SPL_BIN}

# TPL binary from Rockchip
TPL_BIN_PATH=${BUILD_DIR}/rkbin/bin/rk35/${TPL_BIN}

UART_TPL_BIN=uart_115200_${TPL_BIN}

sed 's/uart baudrate=/uart baudrate=115200/g' ${BUILD_DIR}/rkbin/tools/ddrbin_param.txt > ${BUILD_DIR}/rkbin/tools/ddrbin_param_115200.txt

cp ${TPL_BIN_PATH} ${BUILD_DIR}/rkbin/bin/rk35/${UART_TPL_BIN}

${BUILD_DIR}/rkbin/tools/ddrbin_tool ${BUILD_DIR}/rkbin/tools/ddrbin_param_115200.txt ${BUILD_DIR}/rkbin/bin/rk35/${UART_TPL_BIN}

TPL_BIN_PATH=${BUILD_DIR}/rkbin/bin/rk35/${UART_TPL_BIN}

UBOOT_REPO=$(cat $BR2_CONFIG | grep BR2_TARGET_UBOOT_CUSTOM_REPO_VERSION | awk -F= '{print $2}' | awk -F\" '{print $2}')

if ! [ -f ${TPL_BIN_PATH} ]; then
	echo "File ${TPL_BIN_PATH} is absent."
	exit -1
fi

if ! [ -f ${SPL_BIN_PATH} ]; then
	echo "File ${SPL_BIN_PATH} is absent."
	exit -1
fi

${BUILD_DIR}/uboot-${UBOOT_REPO}/tools/mkimage -n "rk3568" -T rksd -d ${TPL_BIN_PATH}:${SPL_BIN_PATH} ${IMAGES_DIR}/idblock.bin
if ! [ $? == 0 ]; then
	echo "idblock.bin can't be built."
	exit -1
fi

##################################################################################
# 2. Create uboot.img
UBOOT_BIN=${BUILD_DIR}/u-boot.bin

if ! [ -f ${BUILD_DIR}/rkbin/bin/rk35/rk3568_bl31_v1.43.elf ]; then
	echo "File ${BUILD_DIR}/rkbin/bin/rk35/rk3568_bl31_v1.43.elf is absent."
	exit -1
fi

cp ${BUILD_DIR}/rkbin/bin/rk35/rk3568_bl31_v1.43.elf ${BUILD_DIR}/uboot-${UBOOT_REPO}/bl31.elf

if ! [ -f ${BUILD_DIR}/rkbin/bin/rk35/rk3568_bl32_v2.10.bin ]; then
	echo "File ${BUILD_DIR}/rkbin/bin/rk35/rk3568_bl32_v2.10.bin is absent."
	exit -1
fi

cp ${BUILD_DIR}/rkbin/bin/rk35/rk3568_bl32_v2.10.bin ${BUILD_DIR}/uboot-${UBOOT_REPO}/tee.bin

# The script make_fit_atf.sh requires working directory u-boot
cd ${BUILD_DIR}/uboot-${UBOOT_REPO}

arch/arm/mach-rockchip/make_fit_atf.sh -t 0x08400000 > u-boot.its

ls bl31_0x*.bin

if ! [ $? == 0 ]; then
	echo "u-boot.its can't be built."
	exit -1
fi

tools/mkimage -f u-boot.its -E ${IMAGES_DIR}/uboot.img

cd ..
