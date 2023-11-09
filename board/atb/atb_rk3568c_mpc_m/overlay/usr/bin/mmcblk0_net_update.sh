#!/bin/sh
ip -4 address show | grep inet
echo "Waiting for connection"
nc -l -p 1234 | dd of=/dev/mmcblk0 bs=1M
