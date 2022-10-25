#!/bin/sh

buildroot_home=$(pwd)
board=atb-imx8mq-smarc-congasmc1

cd ${buildroot_home}/output/target

mkdir -p var/run
mkdir -p var/lock
mkdir -p var/log
mkdir -a home

#cp ${buildroot_home}/board/atb/${board}/inittab ${buildroot_home}/output/target/etc/
cp ${buildroot_home}/board/atb/${board}/fstab ${buildroot_home}/output/target/etc/
cp ${buildroot_home}/board/atb/${board}/S90mount ${buildroot_home}/output/target/etc/init.d/
chmod 0755 ${buildroot_home}/output/target/etc/init.d/S90mount
