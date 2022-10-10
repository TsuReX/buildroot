#!/bin/bash

set -e

buildroot_home=$(pwd)
img_utils_src=${buildroot_home}/dl/imx-mkimage/git/
img_utils=${buildroot_home}/output/imx-mkimage/
output=${buildroot_home}/output
images=${output}/images
board="atb-imx8m-smarc-congasmc1"
soc=iMX8MQ

BUILD_DIR=${output}/build
BINARIES_DIR=${output}/images

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-atb.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

#
#prepare imx-mkimage
#
echo PREPARE imx-mkimage
if [ -d ${img_utils} ]; then
	rm -rf ${img_utils}
fi
cp -Rp $img_utils_src $img_utils

# Copying necessary files into imx-mkimage/iMX8M directory
cp ${buildroot_home}/output/images/u-boot-spl.bin ${img_utils}/iMX8M
cp ${buildroot_home}/output/images/lpddr4_pmu_train_1d_imem.bin ${img_utils}/iMX8M
cp ${buildroot_home}/output/images/lpddr4_pmu_train_1d_dmem.bin ${img_utils}/iMX8M
cp ${buildroot_home}/output/images/lpddr4_pmu_train_2d_imem.bin ${img_utils}/iMX8M
cp ${buildroot_home}/output/images/lpddr4_pmu_train_2d_dmem.bin ${img_utils}/iMX8M
cp ${buildroot_home}/output/build/uboot-${board}/arch/arm/dts/imx8mq-evk.dtb ${img_utils}/iMX8M/imx8mq-evk.dtb
cp ${buildroot_home}/output/images/bl31.bin ${img_utils}/iMX8M
cp ${buildroot_home}/output/build/uboot-${board}/u-boot-nodtb.bin	${img_utils}/iMX8M
cp ${buildroot_home}/output/build/uboot-${board}/tools/mkimage		${img_utils}/iMX8M/mkimage_uboot
cp ${output}/build/firmware-imx-8.12/firmware/hdmi/cadence/signed_hdmi_imx8m.bin	${img_utils}/iMX8M

# Building bootloader usd_flash.bin
echo MAKING usd_flash.bin
cd ${img_utils}
make SOC=${soc} BOARD=${board} OUTIMG=usd_flash.bin flash_evk
cd ${buildroot_home}

# Prepare all files for genimage
cp ${img_utils}/iMX8M/usd_flash.bin ${images}
cp ${images}/Image ${images}/linux
cp ${output}/build/linux-lf-5.10.y_var03/arch/arm64/boot/dts/freescale/imx8mq-evk.dtb ${images}/dtb
cp ${images}/rootfs.cpio.gz ${images}/rootfs
${output}/host/bin/mkimage -A arm -T ramdisk -C gzip -d ${output}/images/rootfs.cpio.gz ${output}/images/rootfs

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

${output}/host/bin/genimage \
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
	echo "		sudo dd if=output/images/sdcard.img of=/dev/sdX status=progress"
	echo
	echo "This bootable sd-card will contain MBR with U-Boot, boot fat32 partition with Linux kernel,"
	echo "DTB file, rootfs-image and second ext2 partition with linux filesystem."
	echo
fi

exit $?
