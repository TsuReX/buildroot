#!/bin/bash

set -e

#
# Common variables
#
BUILDROOT_HOME=$(pwd)
BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-atb.cfg"
SOC=iMX8MQ

#
# mkimage variaables
#
IMG_UTILS_SRC=${BUILDROOT_HOME}/dl/imx-mkimage/git/
IMG_UTILS=${BUILDROOT_HOME}/output/imx-mkimage/


echo "argc = $#"
echo "arg0 = $0"
echo "arg1 = $1"
echo "arg2 = $2"

if ! [ $# == 2 ]; then
    echo "Invalid arguments"
    echo "The script requres the following arguments: path_to_images_folder linux_dtb_file_name.dtb"
    exit -1
fi

UBOOT_REPO=$(cat $BR2_CONFIG | grep BR2_TARGET_UBOOT_CUSTOM_REPO_VERSION | awk -F= '{print $2}' | awk -F\" '{print $2}')

#
# Variables depends on build
#
IMAGES=${1}
BINARIES_DIR=${IMAGES}
OUTPUT=${IMAGES}/..
BUILD=${OUTPUT}/build
GENIMAGE_TMP="${BUILD}/genimage.tmp"

#
#prepare imx-mkimage
#
echo PREPARE imx-mkimage
if [ -d ${IMG_UTILS} ]; then
	rm -rf ${IMG_UTILS}
fi
cp -Rp ${IMG_UTILS_SRC} ${IMG_UTILS}

# Copying necessary files into imx-mkimage/iMX8M directory
cp ${IMAGES}/u-boot-spl.bin ${IMG_UTILS}/iMX8M
cp ${IMAGES}/lpddr4_pmu_train_1d_imem.bin ${IMG_UTILS}/iMX8M
cp ${IMAGES}/lpddr4_pmu_train_1d_dmem.bin ${IMG_UTILS}/iMX8M
cp ${IMAGES}/lpddr4_pmu_train_2d_imem.bin ${IMG_UTILS}/iMX8M
cp ${IMAGES}/lpddr4_pmu_train_2d_dmem.bin ${IMG_UTILS}/iMX8M
cp ${IMAGES}/u-boot.dtb ${IMG_UTILS}/iMX8M/imx8mq-evk.dtb
cp ${IMAGES}/bl31.bin ${IMG_UTILS}/iMX8M
cp ${IMAGES}/uboot-${UBOOT_REPO}/u-boot-nodtb.bin		${IMG_UTILS}/iMX8M
cp ${IMAGES}/uboot-${UBOOT_REPO}/tools/mkimage		${IMG_UTILS}/iMX8M/mkimage_uboot
cp ${IMAGES}/firmware-imx-8.12/firmware/hdmi/cadence/signed_hdmi_imx8m.bin	${IMG_UTILS}/iMX8M

# Building bootloader usd_flash.bin
echo MAKING usd_flash.bin
cd ${IMG_UTILS}
make SOC=${SOC} BOARD=${BOARD_NAME} OUTIMG=usd_flash.bin flash_evk
cd ${BUILDROOT_HOME}

# Prepare all files for genimage
cp ${IMG_UTILS}/iMX8M/usd_flash.bin ${IMAGES}
cp ${IMAGES}/Image ${IMAGES}/linux
cp ${IMAGES}/${2} ${IMAGES}/dtb
cp ${IMAGES}/rootfs.cpio.gz ${IMAGES}/rootfs
${OUTPUT}/host/bin/mkimage -A arm -T ramdisk -C gzip -d ${OUTPUT}/images/rootfs.cpio.gz ${OUTPUT}/images/rootfs

# Prepare 3-rd partition
dd if=/dev/zero of=${OUTPUT}/images/home.ext2 bs=1M count=100 status=progress
/sbin/mkfs.ext2 ${OUTPUT}/images/home.ext2 -L "home"

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

if [ $? -eq 0 ]; then
	echo
	echo "Now file sdcard.img was created successfully. To make bootable sd-card put next"
	echo "command to your terminal:"
	echo
	echo "		sudo dd if=output/images/sdcard.img of=/dev/sdX bs=1M status=progress"
	echo
	echo "This bootable sd-card will contain MBR with U-Boot, boot fat32 partition with Linux kernel,"
	echo "DTB file, rootfs-image and second ext2 partition with linux filesystem."
	echo
fi

exit $?
