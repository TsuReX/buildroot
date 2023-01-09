#!/bin/bash

set -e

BUILDROOT_HOME=$(pwd)
SOC=RK3358J
BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"

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

IMAGES=$1
OUTPUT=${IMAGES}/..
BUILD=${OUTPUT}/build
GENIMAGE_TMP="${IMAGES}/genimage.tmp"
BINARIES_DIR=${OUTPUT}/images

DTB=$2

if ! [ -d ${BUILD}/rkbin ]; then
	# Copying necessary files into output/images/rkbin form git repository
	git clone --single-branch --branch px30/firefly https://gitlab.com/firefly-linux/rkbin ${BUILD}/rkbin
fi

PLAT=px30

SPL_BIN=${BUILD}/rkbin/bin/rk33/px30_miniloader_v1.35.bin
TPL_BIN=${BUILD}/rkbin/bin/rk33/px30_ddr_333MHz_uart2_m1_v2.02.bin


# 1. Create idblock.bin
echo "---> ${BUILD}/uboot-${UBOOT_REPO}/tools/mkimage -n ${PLAT} -T rksd -d ${TPL_BIN}:${SPL_BIN} ${IMAGES}/idblock.bin"
${BUILD}/uboot-${UBOOT_REPO}/tools/mkimage -n ${PLAT} -T rksd -d ${TPL_BIN}:${SPL_BIN} ${IMAGES}/idblock.bin

# px30_loader_v2.02.135.bin
#./rkbin/tools/boot_merger /home/user/drive/workspace/rk356x_linux_release_20211019/rkbin/RKBOOT/PX30MINIALL.ini

# 2. Create trust.img

cd ${BUILD}/rkbin
./tools/trust_merger ./RKTRUST/PX30TRUST.ini --size 2048 2 --sha 3 --rsa 3
cp trust.img ${IMAGES}
cd -

# 2.1 Create uboot.img
${BUILD}/rkbin/tools/loaderimage --pack --uboot ${IMAGES}/u-boot.bin ${IMAGES}/uboot.img 0x00200000 --size 2048 2


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

if [ $? -eq 0 ]; then
	echo
	echo "Now file sdcard.img was created successfully. To make bootable sd-card put next"
	echo "command to your terminal:"
	echo
	echo "		sudo dd if=output/images/sdcard.img of=/dev/sdX status=progress bs=1M"
	echo
	echo "This bootable sd-card will contain MBR with U-Boot, boot fat32 partition with Linux kernel,"
	echo "DTB file, rootfs-image and second ext2 partition with linux filesystem."
	echo
fi

exit $?
