#!/bin/sh

set -x

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

if ! [ $# == 2 ]; then
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

cd -

#cp ${BUILDROOT_HOME}/board/atb/${BOARD_NAME}/inittab ${BUILDROOT_HOME}/output/target/etc/
cp ${BUILDROOT_HOME}/board/atb/${BOARD_NAME}/fstab ${TARGET}/etc/
cp ${BUILDROOT_HOME}/board/atb/${BOARD_NAME}/S90mount ${TARGET}/etc/init.d/
chmod 0755 ${TARGET}/etc/init.d/S90mount
