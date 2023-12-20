#!/bin/bash

# Debugging options
# This command is used to print each being executed line of script
#set -x
# This command is used to stop script execution after a command finished with non zero value
#set -e

# ${0} - path to current script
# ${1} - path to images directory
# ${2} - being used dtd file

BUILDROOT_HOME=$(pwd)
DTB_NAME=$2
BOARD_DIR=`dirname ${BR2_DL_DIR}`/`dirname $0`
WORKING_DIR=`dirname ${BR2_CONFIG}`
BUILD_DIR=${WORKING_DIR}/build
TARGET_DIR=${WORKING_DIR}/target
IMAGES_DIR=${WORKING_DIR}/images

if ! [ $# == 2 ]; then
    echo "Invalid arguments"
    echo "The script requres the following arguments: path_to_images_folder linux_dtb_file_name.dtb"
    exit -1
fi

if ! [ -d ${BUILD_DIR}/rkbin ]; then
	# Copying necessary files into output/images/rkbin form git repository
	#git clone --single-branch --branch rk356x/linux_release_v1.3.0a https://gitlab.com/firefly-linux/rkbin ${BUILD_DIR}/rkbin
	git clone https://github.com/rockchip-linux/rkbin.git ${BUILD_DIR}/rkbin
	
fi

##################################################################################
# 1. Create idblock.bin


SPL_BIN=u-boot-spl.bin


#TPL_BIN=rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.07.bin
TPL_BIN=rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.12.bin


# SPL being compiled from sources
SPL_BIN_PATH=${IMAGES_DIR}/${SPL_BIN}

# SPL binary from Rockchip
#SPL_BIN_PATH=${BUILD_DIR}/rkbin/bin/rk35/${SPL_BIN}

# TPL binary from Rockchip
TPL_BIN_PATH=${BUILD_DIR}/rkbin/bin/rk35/${TPL_BIN}

UART_TPL_BIN=uart_115200_${TPL_BIN}

#sed 's/uart baudrate=/uart baudrate=115200/g' ${BUILD_DIR}/rkbin/tools/ddrbin_param.txt > ${BUILD_DIR}/rkbin/tools/ddrbin_param.txt

cp ${TPL_BIN_PATH} ${BUILD_DIR}/rkbin/bin/rk35/${UART_TPL_BIN}

${BUILD_DIR}/rkbin/tools/ddrbin_tool ${BOARD_DIR}/ddrbin_param.txt ${BUILD_DIR}/rkbin/bin/rk35/${UART_TPL_BIN}

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

${BUILD_DIR}/uboot-${UBOOT_REPO}/tools/mkimage -n "rk3588" -T rksd -d ${TPL_BIN_PATH}:${SPL_BIN_PATH} ${IMAGES_DIR}/idblock.bin
if ! [ $? == 0 ]; then
	echo "idblock.bin can't be built."
	exit -1
fi

##################################################################################
# 2. Create uboot.img
UBOOT_BIN=${BUILD_DIR}/u-boot.bin

if ! [ -f ${BUILD_DIR}/rkbin/bin/rk35/rk3588_bl31_v1.40.elf ]; then
	echo "File ${BUILD_DIR}/rkbin/bin/rk35/rk3588_bl31_v1.40.elf is absent."
	exit -1
fi

cp ${BUILD_DIR}/rkbin/bin/rk35/rk3588_bl31_v1.40.elf ${BUILD_DIR}/uboot-${UBOOT_REPO}/bl31.elf

if ! [ -f ${BUILD_DIR}/rkbin/bin/rk35/rk3588_bl32_v1.13.bin ]; then
	echo "File ${BUILD_DIR}/rkbin/bin/rk35/rk3588_bl32_v1.13.bin is absent."
	exit -1
fi

cp ${BUILD_DIR}/rkbin/bin/rk35/rk3588_bl32_v1.13.bin ${BUILD_DIR}/uboot-${UBOOT_REPO}/tee.bin

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

##################################################################################
# 3. Linux kernel
cp ${IMAGES_DIR}/Image ${IMAGES_DIR}/linux

##################################################################################
# 4. Linux device tree blob
cp ${IMAGES_DIR}/${DTB_NAME} ${IMAGES_DIR}/dtb

##################################################################################
# 5. Rootfs
cp ${IMAGES_DIR}/rootfs.cpio.gz ${IMAGES_DIR}/rootfs

${BUILD_DIR}/uboot-${UBOOT_REPO}/tools/mkimage -A arm -T ramdisk -C gzip -d ${WORKING_DIR}/images/rootfs.cpio.gz ${WORKING_DIR}/images/rootfs

if ! [ $? == 0 ]; then
	echo "rootfs wasn't created due to error."
	exit -1
fi


# These images are stored in dl directory where all packages being used for building are stored.
#wget -T 1 --ftp-user='atbftp_user' --ftp-password='32Vj_hy%c@gR' ftp://ftp.atb-e.ru:2121/ATB_FTP/buildroot/
#ROOTFS_IMG="debian10-lxde.rootfs.ext4"
ROOTFS_IMG="debian11_3588.rootfs.ext4"
echo "External rootfs is ${ROOTFS_IMG}"

if ! [ -e ${BUILDROOT_HOME}/dl/${ROOTFS_IMG} ]; then
	cd ${BUILDROOT_HOME}/dl/
	wget -T 1 --ftp-user='atbftp_user' --ftp-password='32Vj_hy%c@gR' ftp://ftp.atb-e.ru:2121/ATB_FTP/buildroot/${ROOTFS_IMG}
	cd -
fi


# Copy new or replace existing image to avoid impact of changes made earlier
cp -f ${BUILDROOT_HOME}/dl/${ROOTFS_IMG} ${IMAGES_DIR}/ext.rootfs.ext4

echo ""
echo ""
echo "WARNING!"
echo "The following operations require privileged access."
echo "To be assured that nothing dangerous is executed, you can observe the following file $0"
echo ""
echo ""
# Unmount and remove mnt directory if it exists by any reasons
mountpoint ${IMAGES_DIR}/mnt -q
if [ $? == 0 ]; then
	sudo umount ${IMAGES_DIR}/mnt
fi
sudo rm -rf ${IMAGES_DIR}/mnt

mkdir ${IMAGES_DIR}/mnt
sudo mount ${IMAGES_DIR}/ext.rootfs.ext4 ${IMAGES_DIR}/mnt
if ! [ $? == 0 ]; then
	exit -3
fi

sudo cp ${TARGET_DIR}/etc/fstab ${IMAGES_DIR}/mnt/etc/
sudo cp -r ${TARGET_DIR}/lib/modules ${IMAGES_DIR}/mnt/lib/
sudo cp -R ${TARGET_DIR}/etc/udev ${IMAGES_DIR}/mnt/etc/

sudo umount ${IMAGES_DIR}/mnt
sudo rm -rf ${IMAGES_DIR}/mnt


##################################################################################
# 6. Final image
UBOOT_ENV_SIZE=0x8000

${BUILD_DIR}/uboot-${UBOOT_REPO}/tools/mkenvimage -s ${UBOOT_ENV_SIZE} -o ${IMAGES_DIR}/uboot.env ${BOARD_DIR}/uboot/uboot.env.txt

if ! [ $? == 0 ]; then
	echo "u-boot environment wasn't created due to error."
	exit -1
fi

ROOTPATH_TMP=`mktemp -d`

GENIMAGE_TMP="${IMAGES_DIR}/genimage.tmp"

rm -rf ${GENIMAGE_TMP}

${WORKING_DIR}/host/bin/genimage					\
	--rootpath		${ROOTPATH_TMP}					\
	--tmppath		"${IMAGES_DIR}/genimage.tmp"	\
	--inputpath		${IMAGES_DIR}					\
	--outputpath	${IMAGES_DIR}					\
	--config		"${BOARD_DIR}/genimage.cfg"

if ! [ $? == 0 ]; then
	rm -rf ${ROOTPATH_TMP}
	echo "Block device image wasn't created due to error."
	exit -1
fi

rm -rf ${ROOTPATH_TMP}

IMAGE_NAME=`basename -s .dtb ${DTB_NAME}`-usd

mv ${IMAGES_DIR}/image.bin ${IMAGES_DIR}/${IMAGE_NAME}.img

##################################################################################

echo

ls -lh ${IMAGES_DIR}/${IMAGE_NAME}.img

echo
echo "Now file ${IMAGE_NAME}.img was created successfully. To make bootable sd-card put next"
echo "command to your terminal:"
echo
echo "		sudo dd if=${IMAGES_DIR}/${IMAGE_NAME}.img of=/dev/sdX status=progress bs=1M"
echo
echo

lsblk
echo
