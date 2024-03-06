#!/bin/bash

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

bash -c 'while : ; do ffmpeg -loglevel quiet -i /home/user/Videos/Food_Fizzle_UHD_4K.mp4 -f null -; done' &
CODEC_PID=$!

bash -c "while : ; do clpeak > /dev/null; done" &
GPU_PID=$!

bash -c 'stress --cpu $(nproc)' &
CPU_PID=$!

sleep 1

read -p "Press enter to stop stress test..."

kill $CODEC_PID
kill $GPU_PID
kill $CPU_PID
