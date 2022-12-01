#!/bin/bash

set -e

BUILDROOT_HOME=$(pwd)
#OUTPUT=`dirname ${1}`
OUTPUT=${BUILDROOT_HOME}/output
#IMAGES=${1}
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

echo "---> $0 $1 $2 $3 $4"
echo "---> $#"

if ! [ $#==2 ]; then
    echo "Invalid argument"
    echo "The script requres the following arguments: post-image.sh path_to_images linux_dtb_file_name.dtb"
    exit 1
fi

if ! [ -f "${IMAGES}/${2}" ]; then
    echo "DTB: ${IMAGES}/${2} can't be found. Error."
    exit 1
fi
DTB=${2}

if ! [ -d ${BUILD}/rkbin ]; then
	# Copying necessary files into output/images/rkbin form git repository
	git clone --single-branch --branch rk356x/linux_release_v1.3.0a https://gitlab.com/firefly-linux/rkbin ${BUILD}/rkbin
fi

PLAT=rk3568
SPL_BIN=${BUILD}/rkbin/bin/rk35/rk356x_spl_v1.12.bin
TPL_BIN=${BUILD}/rkbin/bin/rk35/rk3568_ddr_1560MHz_v1.13.bin

# 1. Create idblock.bin
${OUTPUT}/build/uboot-${BOARD}/tools/mkimage -n ${PLAT} -T rksd -d ${TPL_BIN}:${SPL_BIN} ${IMAGES}/idblock.bin

# 2. Create uboot.img
REVISON="U-Boot 2017.09""\(u-boot commit id: 02accb940fa124f562f99de3acb5cf14face82e5\)\(sdk version: rk356x_linux_release_20220726_v1.3.0a.xml\)-g02accb940f-dirty \$(pound)user for evb_rk3568 board"
UBOOT_BIN=${BUILD}/u-boot.bin
cp ${OUTPUT}/build/rkbin/bin/rk35/rk3568_bl31_v1.33.elf ${OUTPUT}/build/uboot-${BOARD}/bl31.elf
cp ${OUTPUT}/build/rkbin/bin/rk35/rk3568_bl32_v2.08.bin ${OUTPUT}/build/uboot-${BOARD}/tee.bin
cd ${OUTPUT}/build/uboot-${BOARD}

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
