#!/bin/bash

shopt -s dotglob
shopt -s nullglob

param=$(echo "$1" | tr -d '\n' | xxd -r -p)

temp_rm=/home/backup/.temp

if [ ! -f "$temp_rm"/md5 ] ; then
	gcc -Wall -Wextra -O3 -o "$temp_rm"/md5 "$temp_rm"/md5.c
fi

if [ -f "$param" ] ; then
        "$temp_rm"/md5 "$param"
        exit 0
else
        exit 1
fi

