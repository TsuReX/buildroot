#!/bin/sh

#set -xe

#
# Common variables
#
BUILDROOT_HOME=$(pwd)
BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"

echo "argc = $#"
echo "arg0 = $0"
echo "arg1 = $1"
echo "arg2 = $2"

if ! [ $# -eq 2 ]; then
    echo "Invalid arguments"
    echo "The script requres the following arguments: path_to_images_folder linux_dtb_file_name.dtb"
    exit -1
fi

TARGET=${1}

cd ${TARGET}

mkdir -p var/run
mkdir -p var/lock
mkdir -p var/log
mkdir -p home
mkdir -p etc/network
mkdir -p etc/ifplugd

cd -

cp ${BUILDROOT_HOME}/board/atb/${BOARD_NAME}/interfaces ${TARGET}/etc/network/
cp ${BUILDROOT_HOME}/board/atb/${BOARD_NAME}/ifplugd.conf ${TARGET}/etc/ifplugd/
cp ${BUILDROOT_HOME}/board/atb/${BOARD_NAME}/fstab ${TARGET}/etc/
