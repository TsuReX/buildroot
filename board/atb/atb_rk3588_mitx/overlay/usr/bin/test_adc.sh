#!/bin/bash

ADC_12v_RAW=$(cat /sys/bus/iio/devices/iio:device0/in_voltage4_raw)
ADC_5v_RAW=$(cat /sys/bus/iio/devices/iio:device0/in_voltage6_raw)
ADC_3v3_RAW=$(cat /sys/bus/iio/devices/iio:device0/in_voltage7_raw)

ADC_12v=$(calc "1.8 * $ADC_12v_RAW / 4095" | tr -d "\t~")
ADC_5v=$(calc "1.8 * $ADC_5v_RAW / 4095" | tr -d "\t~")
ADC_3v3=$(calc "1.8 * $ADC_3v3_RAW / 4095" | tr -d "\t~")

# voltage divider calculation: volt_adc * (R1 + R2) / R2
VOLTAGE_12v=$(calc "$ADC_12v * (100 + 11) / 11" | tr -d "\t~")
VOLTAGE_5v=$(calc "$ADC_5v * (200 + 100) / 100" | tr -d "\t~")
VOLTAGE_3v3=$(calc "$ADC_3v3 * (100 + 100) / 100" | tr -d "\t~")

echo
echo "12v  line: $VOLTAGE_12v"
echo "5v   line: $VOLTAGE_5v"
echo "3.3v line: $VOLTAGE_3v3"
echo
