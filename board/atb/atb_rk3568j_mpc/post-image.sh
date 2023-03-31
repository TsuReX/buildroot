#!/bin/bash

#set -xe

BUILDROOT_HOME=$(pwd)
#OUTPUT=`dirname ${1}`
#OUTPUT=${BUILDROOT_HOME}/output
#IMAGES=${1}
#IMAGES=${OUTPUT}/images
SOC=RK3568J
#BUILD=${OUTPUT}/build
#BINARIES_DIR=${OUTPUT}/images
BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
IMAGE_NAME="$(basename -s .dtb $2)"

echo "argc = $#"
echo "arg0 = $0"
echo "arg1 = $1"
echo "arg2 = $2"


UBOOT_REPO=$(cat $BR2_CONFIG | grep BR2_TARGET_UBOOT_CUSTOM_REPO_VERSION | awk -F= '{print $2}' | awk -F\" '{print $2}')

if ! [ $# == 2 ]; then
    echo "Invalid arguments"
    echo "The script requres the following arguments: path_to_images_folder linux_dtb_file_name.dtb"
    exit -1
fi

#if [ -z "$1" ] ; then
#	echo "ERROR: path to output directory isn't specified"
#fi

#if [ -z "$2" ]; then
#    echo "ERROR: $2 DTB file isn't specified"
#    exit -1
#fi

IMAGES=$1
OUTPUT=${IMAGES}/..
BUILD=${OUTPUT}/build
GENIMAGE_TMP="${IMAGES}/genimage.tmp"
BINARIES_DIR=${OUTPUT}/images

DTB=$2

if ! [ -d ${BUILD}/rkbin ]; then
	# Copying necessary files into output/images/rkbin form git repository
	git clone --single-branch --branch rk356x/linux_release_v1.3.0a https://gitlab.com/firefly-linux/rkbin ${BUILD}/rkbin
fi
PLAT=rk3568
#SPL_BIN=rk356x_spl_nand_v1.07.bin
#SPL_BIN=rk356x_spl_v1.08.bin
SPL_BIN=rk356x_spl_v1.12.bin


#TPL_BIN=rk3568_ddr_1056MHz_v1.05.bin
#TPL_BIN=rk3568_ddr_1184MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_1560MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_528MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_780MHz_v1.05.bin
#TPL_BIN=rk3568_ddr_920MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_1056MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_1332MHz_v1.05.bin
#TPL_BIN=rk3568_ddr_1560MHz_v1.05.bin
#TPL_BIN=rk3568_ddr_324MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_630MHz_v1.05.bin
#TPL_BIN=rk3568_ddr_780MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_1184MHz_v1.05.bin
#TPL_BIN=rk3568_ddr_1332MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_1560MHz_v1.05-firefly.bin
#TPL_BIN=rk3568_ddr_528MHz_v1.05.bin
#TPL_BIN=rk3568_ddr_630MHz_v1.13.bin
#TPL_BIN=rk3568_ddr_920MHz_v1.05.bin
TPL_BIN=rk3568_ddr_1560MHz_v1.13.bin

SPL_BIN_PATH=${BUILD}/rkbin/bin/rk35/${SPL_BIN}
TPL_BIN_PATH=${BUILD}/rkbin/bin/rk35/${TPL_BIN}

UART_TPL_BIN=uart_115200_${TPL_BIN}
sed 's/uart baudrate=/uart baudrate=115200/g' ${BUILD}/rkbin/tools/ddrbin_param.txt > ${BUILD}/rkbin/tools/ddrbin_param_115200.txt
cp ${TPL_BIN_PATH} ${BUILD}/rkbin/bin/rk35/${UART_TPL_BIN}
${BUILD}/rkbin/tools/ddrbin_tool ${BUILD}/rkbin/tools/ddrbin_param_115200.txt ${BUILD}/rkbin/bin/rk35/${UART_TPL_BIN}
TPL_BIN_PATH=${BUILD}/rkbin/bin/rk35/${UART_TPL_BIN}


# 1. Create idblock.bin
${BUILD}/uboot-${UBOOT_REPO}/tools/mkimage -n ${PLAT} -T rksd -d ${TPL_BIN_PATH}:${SPL_BIN_PATH} ${IMAGES}/idblock.bin

# 2. Create uboot.img
REVISON="U-Boot 2017.09""\(u-boot commit id: 02accb940fa124f562f99de3acb5cf14face82e5\)\(sdk version: rk356x_linux_release_20220726_v1.3.0a.xml\)-g02accb940f-dirty \$(pound)user for evb_rk3568 board"
UBOOT_BIN=${BUILD}/u-boot.bin
cp ${BUILD}/rkbin/bin/rk35/rk3568_bl31_v1.33.elf ${OUTPUT}/build/uboot-${UBOOT_REPO}/bl31.elf
cp ${BUILD}/rkbin/bin/rk35/rk3568_bl32_v2.08.bin ${OUTPUT}/build/uboot-${UBOOT_REPO}/tee.bin
cd ${BUILD}/uboot-${UBOOT_REPO}

./arch/arm/mach-rockchip/make_fit_atf.sh -t 0x08400000 > u-boot.its
#
# Check if make_fit_atf.sh done his job Ok.
# It will fail to create bl31_0x*.bin files if there
# is no python2 in a system or because of another reason.
#
ls bl31_0x*.bin
if ! [ $? ]; then
	exit -1
fi

./tools/mkimage -f u-boot.its -E u-boot.itb
cp u-boot.itb ${IMAGES}/uboot.img
cd -

# 3. Linux kernel
cp ${IMAGES}/Image ${IMAGES}/linux

# 4. Linux device tree blob
#cp ${BUILD}/linux-rk356x_linux_release_v1.3.0a/arch/arm64/boot/dts/rockchip/rk3568-evb1-ddr4-v10-linux.dtb ${IMAGES}/dtb
#cp ${IMAGES}/rk3568-firefly-aioj.dtb ${IMAGES}/dtb
cp ${IMAGES}/${DTB} ${IMAGES}/dtb

# 5. Rootfs
cp ${IMAGES}/rootfs.cpio.gz ${IMAGES}/rootfs
${BUILD}/uboot-${UBOOT_REPO}/tools/mkimage -A arm -T ramdisk -C gzip -d ${OUTPUT}/images/rootfs.cpio.gz ${OUTPUT}/images/rootfs

# Pass an empty rootpath. genimage makes a full copy of the given rootpath to
# ${GENIMAGE_TMP}/root so passing TARGET_DIR would be a waste of time and disk
# space. We don't rely on genimage to build the rootfs image, just to insert a
# pre-built one in the disk image.

trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"

rm -rf "${GENIMAGE_TMP}"

echo ROOTPATH_TMP=${ROOTPATH_TMP}
echo GENIMAGE_TMP=${GENIMAGE_TMP}
echo BINARIES_DIR=${BINARIES_DIR}
echo GENIMAGE_CFG=${GENIMAGE_CFG}

export PATH=$PATH:/sbin

${OUTPUT}/host/bin/genimage \
	--rootpath "${ROOTPATH_TMP}"   \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}"  \
	--outputpath "${BINARIES_DIR}" \
	--config "${GENIMAGE_CFG}"

mv ${IMAGES}/sdcard.img ${IMAGES}/${IMAGE_NAME}.img

if [ $? -eq 0 ]; then
	echo
	echo "Now file sdcard.img was created successfully. To make bootable sd-card put next"
	echo "command to your terminal:"
	echo
	echo "		sudo dd if=${IMAGES}/${IMAGE_NAME}.img of=/dev/sdX status=progress bs=1M"
	echo
	echo "This bootable sd-card will contain MBR with U-Boot, boot fat32 partition with Linux kernel,"
	echo "DTB file, rootfs-image and second ext2 partition with linux filesystem."
	echo
fi

exit $?
