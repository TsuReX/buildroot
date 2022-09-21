#!/bin/sh

echo Executing POST IMAGE SCRIPT

export PATH=${PATH}:/sbin:/usr/sbin

buildroot_home=$(pwd)
usd_device=/dev/sdb
img_utils_src=${buildroot_home}/dl/imx-mkimage/git/
img_utils=${buildroot_home}/output/imx-mkimage/
output=${buildroot_home}/output
board="atb-var-som"
soc=iMX8MP

# Patch soc.mak to it be able clean temaporary boot files
#cat dl/imx-mkimage/git/iMX8M/soc.mak | grep usd_flash.bin
#if ! [ $? -eq 0 ] ; then
#	patch -u dl/imx-mkimage/git/iMX8M/soc.mak -i board/atb/mkimage-clean-temp-boot-files.patch
#else
#	echo soc.mak is already patched
#fi

#
#prepare imx-mkimage
#
echo PREPARE imx-mkimage
if [ -d ${img_utils} ]; then
	rm -rf ${img_utils}
fi
cp -Rp $img_utils_src $img_utils


#
# Function formates specified block device
# and creates partiotions with file systems where OS's files will be copied to.
#
# TODO: Implement error generation.
prepare_storage() {
	# $1 - path to a block device that will be formated and prepared for file systems

	echo "---> Preparing storage"

	if ! [[ $# -eq 1 ]]
	then
		return -1
	fi

	local device=$1

	echo "Fill the device ${1} with zeroes"
	sudo dd if=/dev/zero of=$device bs=1M count=8
	sleep 1
	echo "Create MSDOS partition table on the device ${1}"
	sudo /usr/sbin/parted $device mklabel msdos -s
	sleep 1
	echo "Create first partition"
	sudo /usr/sbin/parted $device mkpart primary 8M 520M -s
	sleep 1
	echo "Create second partition"
	sudo /usr/sbin/parted $device mkpart primary 528M 1G -s
	sleep 1
	echo "Create fat32 file system on the patition ${device}1"
	sudo mkfs.fat -F32 $device"1"
	sleep 1
	echo "Create ext4 file system on the patition ${device}2"
	echo y | sudo mkfs.ext4 $device"2"
	sleep 1
	sudo parted $device print

	return 0
}

#
# Functions places prepared bootloader binary to specified block device.
#
# TODO: Implement error generation.
make_image() {
	# $1 - board final image buildig utilities directory
	# $2 - board {atb-var-som | atb-imx8m-smarc}

	echo "---> Preparing image"

	if ! [[ $# -eq 2 ]]
	then
		return -1
	fi

	local board=$2
	case $2 in
		"atb-var-som" | "atb-imx8mp-som-symphony" | "atb-imx8mp-som-voskhod1")
			local soc="iMX8MP"
			local seek=32
		;;

		"atb-imx8m-smarc")
			local soc="iMX8MQ"
			local seek=33
		;;

		*)
			return -2
		;;
	esac

	cd $1
	echo `pwd`

	#make clean

	cp ${buildroot_home}/output/images/u-boot-spl.bin iMX8M
	cp ${buildroot_home}/output/images/lpddr4_pmu_train_1d_imem_202006.bin iMX8M
	cp ${buildroot_home}/output/images/lpddr4_pmu_train_1d_dmem_202006.bin iMX8M
	cp ${buildroot_home}/output/images/lpddr4_pmu_train_2d_imem_202006.bin iMX8M
	cp ${buildroot_home}/output/images/lpddr4_pmu_train_2d_dmem_202006.bin iMX8M
	cp ${buildroot_home}/output/images/atb-imx8mp-som-symphony.dtb iMX8M/imx8mp-evk.dtb
	cp ${buildroot_home}/output/images/bl31.bin iMX8M
	cp ${buildroot_home}/output/build/uboot-atb-var-som/u-boot-nodtb.bin	iMX8M
	cp ${buildroot_home}/output/build/uboot-atb-var-som/tools/mkimage	iMX8M/mkimage_uboot

	echo MAKING usd_flash.bin
	make SOC=${soc} BOARD=${board} OUTIMG=usd_flash.bin flash_evk
	echo "Installing boot loader into sd-card (usd_flash.bin)"
	sudo dd if=./iMX8M/usd_flash.bin of=/dev/sdb bs=1k seek=${seek} conv=fsync status=progress

	sha256sum ./iMX8M/usd_flash.bin

	cd ..

	return 0
}

#
# Function copies to target storage device binaries needed for OS booting: linux kernel, dtb, root file system image.
#
# TODO: Make paremeters to be obtained from arguments
# TODO: Implement error generation.
prepare_os_images_storage() {
	echo "---> Preparing kernel, dtb and rootfs files on the bootable storage"
	echo $(pwd)
	sleep 5
	sudo rm -rf ${output}/target_flash_p1
	mkdir ${output}/target_flash_p1
	sudo mount /dev/sdb1 ${output}/target_flash_p1
	sudo rm -rf ${output}/target_flash_p1/*

	linux_dtb="${buildroot_home}/output/images/atb-imx8mp-som-symphony.dtb"
	linux="${buildroot_home}/output/images/Image"
	rootfs="${buildroot_home}/output/images/rootfs.cpio.gz"

	echo "Copy dtb"
#	find ./rootfs | cpio -H newc -o | gzip -9 > _rootfs.cpio.gz ; ./imx-mkimage/iMX8M/mkimage_uboot -A arm -T ramdisk -C gzip -d _rootfs.cpio.gz rootfs.cpio.gz; rm _rootfs.cpio.gz

	sudo cp $linux_dtb ${output}/target_flash_p1/dtb
	sha256sum $linux_dtb ${output}/target_flash_p1/dtb

	echo "Copy linux"
	sudo cp $linux ${output}/target_flash_p1/linux
	sha256sum $linux ${output}/target_flash_p1/linux

	echo "Copy rootfs"
	sudo ${buildroot_home}/output/host/bin/mkimage -A arm -T ramdisk -C gzip -d $rootfs ${output}/target_flash_p1/rootfs
#	sudo cp $rootfs ./target_flash_p1/rootfs
	sha256sum $rootfs ${output}/target_flash_p1/rootfs

	sleep 1

	ls -l ./target_flash_p1
	sudo umount ./target_flash_p1
	sudo rm -rf ./target_flash_p1
	sudo rm -rf rootfs.cpio.gz

	return 0
}

#
# Function copies to target storage device
#
# TODO: Make paremeters to be obtained from arguments
prepare_rootfs() {
	echo "---> Preparing root fs on the bootable storage"

	sudo rm -rf ./target_flash_p2
	mkdir ./target_flash_p2
	sudo mount /dev/sdb2 ./target_flash_p2
	sudo rm -rf ./target_flash_p2/*
	sudo cp -r ${buildroot_home}/output/target/* ./target_flash_p2
	sleep 1
	sudo umount ./target_flash_p2
	sudo rm -rf ./target_flash_p2

	return 0
}

prepare_storage ${usd_device}

make_image ${img_utils} ${board}

prepare_os_images_storage

prepare_rootfs

