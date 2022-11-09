#!/bin/sh

block_name=$1
device=$(udevadm info --query=path --name=${block_name})

block_num=${device##*[a-zA-Z]}
block_name="/dev/$(echo ${device} | awk -F'/' '{print $NF}')"
device="/dev/$(echo ${device} | awk -F'/' '{print $(NF-1)}')"

/usr/sbin/sgdisk -e ${device}
/usr/sbin/parted ${device} <<EOF
resizepart ${block_num} -34s
q
EOF
/sbin/mke2fs -t ext4 -b 4096 -O ^huge_file -m 0 -q -F ${block_name}
/sbin/e2fsck -fy ${block_name}
