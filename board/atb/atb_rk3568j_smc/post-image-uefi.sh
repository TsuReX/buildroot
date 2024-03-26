#!/bin/bash

#set -xe

BUILDROOT_HOME=$(pwd)
SOC=RK3568J
BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-uefi.cfg"
IMAGE_NAME="$(basename -s .dtb $2)"

echo "argc = $#"
echo "arg0 = $0"
echo "arg1 = $1"
echo "arg2 = $2"

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

UEFI_PATH=${BUILD}/quartz64_uefi-v1.1
#RKBIN_UEFI=${UEFI_PATH}/edk2-rockchip-non-osi/rkbin
RKBIN=${BUILD}/rkbin

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
TPL_BIN=rk3568_ddr_1056MHz_v1.13.bin
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
#TPL_BIN=rk3568_ddr_1560MHz_v1.13.bin

SPL_BIN_PATH=${RKBIN}/bin/rk35/${SPL_BIN}
TPL_BIN_PATH=${RKBIN}/bin/rk35/${TPL_BIN}

UART_TPL_BIN=uart_115200_${TPL_BIN}
sed 's/uart baudrate=/uart baudrate=115200/g' ${RKBIN}/tools/ddrbin_param.txt > ${BUILD}/rkbin/tools/ddrbin_param_115200.txt
cp ${TPL_BIN_PATH} ${RKBIN}/bin/rk35/${UART_TPL_BIN}
${RKBIN}/tools/ddrbin_tool ${RKBIN}/tools/ddrbin_param_115200.txt ${RKBIN}/bin/rk35/${UART_TPL_BIN}
TPL_BIN_PATH=${RKBIN}/bin/rk35/${UART_TPL_BIN}

echo "SPL_BIN_PATH ${SPL_BIN_PATH}"
echo "TPL_BIN_PATH ${TPL_BIN_PATH}"
echo "UART_TPL_BIN ${UART_TPL_BIN}"

# 1. Create idbloader.img
FLASHFILES="FlashHead.bin FlashData.bin FlashBoot.bin"
MINIALL_INI=RK3568MINIALL.ini
OUTPUT_INI=RK3568MINIALL_1056.ini
sed "s/rk3568_ddr_1560MHz_v1.13.bin/${UART_TPL_BIN}/g" ${RKBIN}/RKBOOT/RK3568MINIALL.ini > ${RKBIN}/RKBOOT/_${OUTPUT_INI}
sed "s/rk356x_spl_v1.12.bin/${SPL_BIN}/g" ${RKBIN}/RKBOOT/_${OUTPUT_INI} > ${RKBIN}/RKBOOT/${OUTPUT_INI}
(cd ${RKBIN} && ./tools/boot_merger RKBOOT/${OUTPUT_INI})

${RKBIN}/tools/boot_merger unpack -i ${RKBIN}/rk356x_spl_loader_*.bin -o ${IMAGES}/
cd ${IMAGES}
cat ${FLASHFILES} > idbloader.img
cd -


# 2. Create uefi.img

#copy files to images
cd ${IMAGES}
#/usr/bin/python ${UEFI_PATH}/scripts/extractbl31.py ${RKBIN}/bin/rk35/rk3568_bl31_v1.33.elf
/usr/bin/python ${UEFI_PATH}/scripts/extractbl31.py ${UEFI_PATH}/edk2-rockchip-non-osi/rkbin/bin/rk35/rk3568_bl31_v1.32.elf
cd -

cp ${UEFI_PATH}/edk2-rockchip-non-osi/rkbin/bin/rk35/rk3568_bl32_v2.01.bin ${IMAGES}/

cat ${BOARD_DIR}/uefi.its | sed "s,@BOARDTYPE@,${BOARD_NAME},g" > ${IMAGES}/uefi.its

${RKBIN}/tools/mkimage -f ${IMAGES}/uefi.its -E ${IMAGES}/uefi.itb
cp ${IMAGES}/uefi.itb ${IMAGES}/uefi.img
dd if=${IMAGES}/RK356X_EFI.fd of=${IMAGES}/uefi.img bs=1024 seek=1024   #copy to 1MB (ptr from its)

#2.5 Grub2 config
cp ${BOARD_DIR}/grub.cfg ${IMAGES}/efi-part/EFI/BOOT/

# 3. Linux kernel
cp ${IMAGES}/Image ${IMAGES}/linux

# 4. Linux device tree blob
cp ${IMAGES}/${DTB} ${IMAGES}/dtb

# 5. Rootfs
#cp ${IMAGES}/rootfs.cpio.gz ${IMAGES}/rootfs
#${RKBIN}/tools/mkimage -A arm -T ramdisk -C gzip -d ${OUTPUT}/images/rootfs.cpio.gz ${OUTPUT}/images/rootfs

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

lsblk
echo
exit $?
