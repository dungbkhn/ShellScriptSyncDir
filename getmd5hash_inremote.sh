#!/bin/bash

shopt -s dotglob
shopt -s nullglob

param=$(echo "$1" | tr -d '\n' | xxd -r -p)

md5sum "$param"
