#!/bin/bash
set -x
# using: sudo dommc.sh /dev/sdX
if [ $# -eq 0 ]
then
    echo "ERROR: Disk not specified! Example: ./dommc.sh /dev/sdx"
    exit 1
fi
if ! [ -b $1 ]
then
    echo "ERROR: $1 not found!"
    exit 1
fi

#dtc -I dts -O dtb rk3588-atb_modify.dts -o rk3588-atb.dtb
dtc -I dtb -O dts ../../../output/rk3588/build/linux-be06bef47e321e8c6549b1b4a036d341610d0b90/arch/arm64/boot/dts/rk3588-atb.dtb -o ../../../output/rk3588/build/linux-be06bef47e321e8c6549b1b4a036d341610d0b90/arch/arm64/boot/dts/rk3588-atb_auto.dts 
umount $1
umount $1'1'
umount $1'2'
sudo sgdisk -e $1
sudo fsck -y $1'1'
sudo fsck -y $1'2'

mount $1'1' /media/egorov/test/
dir
#cp ./rk3588-atb.dtb /media/egorov/test/dtb-5.10.160-rockchip-rk3588/rockchip/rk3588-atb.dtb
cp ../../../output/rk3588/build/linux-be06bef47e321e8c6549b1b4a036d341610d0b90/arch/arm64/boot/dts/rk3588-atb.dtb /media/egorov/test/dtb-5.10.160-rockchip-rk3588/rockchip/rk3588-atb.dtb
cp ../../../output/rk3588/images/Image /media/egorov/test/vmlinuz-5.10.160-rockchip-rk3588

sudo sgdisk -e $1
umount $1
umount $1'1'
umount $1'2'
sudo fsck -y $1'1'
sudo fsck -y $1'2'

sync


#echo "Create partitions"
#echo -e "o\n n\n p\n 1\n \n +1G\n    n\n p\n 2\n \n +1M\n    n\n p\n 3\n \n \n    t\n 1\n b\n    t\n 2\n a2\n    w\nq\n" | fdisk $1
partprobe

#echo "Create Fat32 fs"
#mkfs.vfat $1'1'

#echo "Create ext4 fs"
#mkfs.ext4 $1'3'

#echo 'Reset u-boot environment'
#dd if=/dev/zero of=$1 seek=1 bs=512 count=3

#echo 'Copy files'
#dd if=./preloader-mkpimage.bin of=$1'2'
#rm -rf ./mnt
#mkdir mnt
#mount $1'1' ./mnt
#cp ./boot/fpga.rbf ./mnt
#cp ./boot/main_prj.img ./mnt
#cp ./boot/u-boot.img ./mnt
#cp ./boot/u-boot.scr ./mnt
#cp ./boot/uImage ./mnt
#cp ./boot/fpga.dtb ./mnt
#cp ./boot/sh.ini   ./mnt
#umount $1'1'
#mount $1'3' ./mnt
#tar -zxf rootfs.tar.gz -C ./mnt
#mkdir ./mnt/home
#mkdir ./mnt/home/ekra
#mkdir ./mnt/home/ekra/boot
#cp ./core.arh ./mnt/home/ekra
#cp ./sh.elf   ./mnt/home/ekra
#cp ./uvat_m302.arh ./mnt/home/ekra
#cp ./S90pre.sh ./mnt/etc/init.d
#cp ./sshd_config ./mnt/etc/ssh
#cp ./interfaces ./mnt/etc/network
#chown root:root ./mnt/* -R
#sync
#umount $1'3'
#echo 'SD card for terminal created'
