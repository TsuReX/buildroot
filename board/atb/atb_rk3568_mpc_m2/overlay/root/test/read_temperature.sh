#!/bin/bash

temperature_soc()
{
    echo $(calc $(cat /sys/class/thermal/thermal_zone0/temp) / 1000)
}

temperature_gpu()
{
    echo $(calc $(cat /sys/class/thermal/thermal_zone1/temp) / 1000)
}

while :
do
    STR=$(printf "SOC=%0.1f; GPU=%0.1f" $(temperature_soc) $(temperature_gpu))
    echo "$(date +"%H.%M.%S"): $STR"
    sleep 1
done
