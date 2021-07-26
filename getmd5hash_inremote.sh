#!/bin/bash

shopt -s dotglob
shopt -s nullglob

param=$(echo "$1" | tr -d '\n' | xxd -r -p)

temp_rm=/home/backup/.temp

if [ ! -f "$temp_rm"/md5 ] ; then
	gcc -Wall -Wextra -O3 -D_LARGEFILE_SOURCE=1 -D_FILE_OFFSET_BITS=64 -o md5 md5.c
fi

if [ -f "$param" ] ; then
		filesize=$(wc -c "$param" | awk '{print $1}')
		n=$(( $filesize/1000000000 ))
		m=$(( $filesize%1000000000 ))
        "$temp_rm"/md5 "$param" n m
        exit 0
else
        exit 1
fi
