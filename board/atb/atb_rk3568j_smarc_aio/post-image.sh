#!/bin/bash

set -e

BUILDROOT_HOME=$(pwd)
IMG_UTILS_SRC=${BUILDROOT_HOME}/dl/imx-mkimage/git/
IMG_UTILS=${BUILDROOT_HOME}/output/imx-mkimage/
OUTPUT=${BUILDROOT_HOME}/output
IMAGES=${OUTPUT}/images
SOC=RK3568J
BUILD=${OUTPUT}/build
BINARIES_DIR=${OUTPUT}/images
BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
GENIMAGE_TMP="${BUILD}/genimage.tmp"
#BOARD=`echo $BOARD_NAME | sed 's/_/-/g'`
BOARD=atb-rk3568-smarc-aio

if ! [ -f ${BUILD}/rkbin ]; then
	# Copying necessary files into output/images/rkbin form git repository
	git clone --single-branch --branch rk356x/linux_release_v1.3.0a https://gitlab.com/firefly-linux/rkbin ${BUILD}/rkbin
fi

PLAT=rk3568
SPL_BIN=${BUILD}/rkbin/bin/rk35/rk356x_spl_v1.12.bin
TPL_BIN=${BUILD}/rkbin/bin/rk35/rk3568_ddr_1560MHz_v1.13.bin

# Create idblock.bin
${OUTPUT}/build/uboot-${BOARD}/tools/mkimage -n ${PLAT} -T rksd -d ${TPL_BIN}:${SPL_BIN} ${IMAGES}/idblock.bin

REVISON="U-Boot 2017.09""\(u-boot commit id: 02accb940fa124f562f99de3acb5cf14face82e5\)\(sdk version: rk356x_linux_release_20220726_v1.3.0a.xml\)-g02accb940f-dirty \$(pound)user for evb_rk3568 board"
UBOOT_BIN=${BUILD}/u-boot.bin
#UBOOT_DTB=${BUILD}/arch/arm/dts/rk3568-firefly.dtb
# or

#rsync -avPt --delete-after ${IMAGES}/rkbin/ ${BUILD}/rkbin/
cp board/atb/${BOARD_NAME}/make-atb.sh	${BUILD}/uboot-${BOARD}/

# Create proper uboot.img
cd ${OUTPUT}/build/uboot-${BOARD}
./make-atb.sh	atb_rk3568_smarc
cp uboot.img ${IMAGES}
cd ${BUILDROOT_HOME}

#${OUTPUT}/build/uboot-${BOARD}/tools/mkimage -f auto -A arm -T firmware -C none -O u-boot -a 0x00a00000 -e 0 -n ${REVISION} -E -b ${IMAGES}/u-boot.dtb -d ${IMAGES}/u-boot.bin ${IMAGES}/u-boot.img

# 1. idblock.bin
# 2. u-boot-dtb.bin = u-boot.bin = u-boot-nodtb.bin + u-boot.dtb
# 3. Linux kernel
cp ${IMAGES}/Image ${IMAGES}/linux

# 4. Linux device tree blob
#cp ${IMAGES}/atb-imx8mp-som-symphony.dtb ${IMAGES}/dtb
cp ${BUILD}/linux-rk356x_linux_release_v1.3.0a/arch/arm64/boot/dts/rockchip/rk3568-evb1-ddr4-v10-linux.dtb ${IMAGES}/dtb

# 5. Rootfs
cp ${IMAGES}/rootfs.cpio.gz ${IMAGES}/rootfs
${OUTPUT}/build/uboot-${BOARD}/tools/mkimage -A arm -T ramdisk -C gzip -d ${OUTPUT}/images/rootfs.cpio.gz ${OUTPUT}/images/rootfs

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
	echo "		sudo dd if=output/images/sdcard.img of=/dev/sdX status=progress"
	echo
	echo "This bootable sd-card will contain MBR with U-Boot, boot fat32 partition with Linux kernel,"
	echo "DTB file, rootfs-image and second ext2 partition with linux filesystem."
	echo
fi

exit $?
