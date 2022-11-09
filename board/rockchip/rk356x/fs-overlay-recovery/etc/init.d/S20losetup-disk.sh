#!/bin/sh

resolve_bootdisk() {
	local DEV=""
	local BOOTMEDIA=""
	local BOOTDEVICE=""
	local BOOTNODE=""
	local devices

	for x in $(cat /proc/cmdline); do
			case ${x} in
				storagemedia=*)
					BOOTMEDIA=$(echo ${x} | cut -f 2 -d =)
				;;
				storagenode=*)
					BOOTNODE=$(echo $x | awk 'BEGIN{FS="@"} {print $NF}')
				;;
			esac
	done

	case ${BOOTMEDIA} in
		emmc)
			DEV=/dev/mmcblk[0-9]
			;;
		sd)
			DEV=/dev/mmcblk[0-9]
			;;
		usb)
			DEV=/dev/sd[a-z]
			;;
		scsi)
			DEV=/dev/sd[a-z]
			;;
		nvme)
			DEV=/dev/nvme[0-9]n[0-9]
			BOOTNODE="\.pcie"
			;;
	esac

	for x in $(ls $DEV); do
		devices=$(udevadm info --query=path --name=${x} |grep "$BOOTNODE")
		if [ $devices ]; then
			BOOTDEVICE=$x
			break
		fi
	done

	echo $BOOTDEVICE
}

losetup_bootdevice()
{
	local BOOTDEVICE
	local virtual_offset=0
	local virtual_count=0
	
 	for x in $(cat /proc/cmdline); do
			case ${x} in
				virtual_lba_offset=*)
					virtual_offset=$(echo ${x} | cut -f 2 -d =)
				;;
				virtual_lba_count=*)
					virtual_count=$(echo ${x} | cut -f 2 -d =)
				;;
			esac
	done

	if [ $virtual_count -eq 0 ]; then
		return 0
	fi

	BOOTDEVICE=$(resolve_bootdisk)
	virtual_offset=$(expr $virtual_offset \* 512)
	virtual_count=$(expr $virtual_count \* 512)
	/sbin/losetup $1 -o $virtual_offset --sizelimit $virtual_count -P --direct-io=on $BOOTDEVICE
}

case "$1" in
	start|"")
	if [ -e /dev/mmcblkloop ]; then
		losetup_bootdevice /dev/mmcblkloop
	fi
	;;
esac
