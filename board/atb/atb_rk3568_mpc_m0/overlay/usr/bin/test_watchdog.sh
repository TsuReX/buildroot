#!/bin/sh

cmd() {
    echo $@
    $@
}

# enable wathdog
cmd gpioset gpiochip4 9=1

while :
do
    sleep 0.5
    cmd gpioset gpiochip2 22=1
    sleep 0.5
    cmd gpioset gpiochip2 22=0
done
