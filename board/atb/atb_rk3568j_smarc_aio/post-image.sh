#!/bin/bash

set -e

buildroot_home=$(pwd)
img_utils_src=${buildroot_home}/dl/imx-mkimage/git/
img_utils=${buildroot_home}/output/imx-mkimage/
output=${buildroot_home}/output
images=${output}/images
board="atb-var-sodimm-voskhod1"
soc=RK3568J

BUILD_DIR=${output}/build
BINARIES_DIR=${output}/images

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# Copying necessary files into imx-mkimage/iMX8M directory
git clone --single-branch --branch rk356x/linux_release_v1.3.0a https://gitlab.com/firefly-linux/rkbin ${images}/rkbin
PLAT="rk3568"
SPL_BIN="rkbin/bin/rk35/rk356x_spl_v1.12.bin"
TPL_BIN="rkbin/bin/rk35/rk3568_ddr_1560MHz_v1.13.bin"

${BUILD_DIR}/u-boot/tools/mkimage -n ${PLAT} -T rksd -d ${TPL_BIN}:${SPL_BIN} ${images}/idblock.bin


REVISON="U-Boot 2017.09""\(u-boot commit id: 02accb940fa124f562f99de3acb5cf14face82e5\)\(sdk version: rk356x_linux_release_20220726_v1.3.0a.xml\)-g02accb940f-dirty \$(pound)user for evb_rk3568 board"
UBOOT_BIN=${BUILD_DIR}/u-boot.bin
#UBOOT_DTB=${BUILD_DIR}/arch/arm/dts/rk3568-firefly.dtb
# or
UBOOT_DTB=${BUILD_DIR}/u-boot.dtb
${BUILD_DIR}/u-boot/tools/mkimage -f auto -A arm -T firmware -C none -O u-boot -a 0x00a00000 -e 0 -n ${REVISION} -E -b ${UBOOT_DTB} -d ${UBOOT_BIN} u-boot.img



# 1. idblock.bin
# 2. u-boot-dtb.bin = u-boot.bin = u-boot-nodtb.bin + u-boot.dtb
# 3. Linux kernel
cp ${images}/Image ${images}/linux

# 4. Linux device tree blob
#cp ${images}/atb-imx8mp-som-symphony.dtb ${images}/dtb
cp ${images}/atb-var-sodimm-voskhod1.dtb ${images}/dtb

# 5. Rootfs
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
