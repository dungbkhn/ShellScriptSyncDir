#!/bin/bash

shopt -s dotglob
shopt -s nullglob

tempfilename="$1"

filename=$(echo "$2" | tr -d '\n' | xxd -r -p)

partialfile="/home/backup/.temp/partialfile.being"

catfileinremote="/home/backup/.temp/catfileinremote.sh"

#echo "filename ban dau:""$filename" >> /home/backup/luutru.txt

#neu tham so thu ba = 0
if [ "$3" -eq 0 ] ; then
	#neu ton tai tham so thu tu = 0, copy total file --> remove old file
	if [ "$4" -eq 0 ] ; then
		
		rm "$filename"
		
		rm "$tempfilename"

		touch "$tempfilename"
		
		exit 0
	#neu la append (ktra file ton tai)
	elif [ -f "$filename" ] ; then

		rm "$tempfilename"
		
		touch "$tempfilename"
		
		exit 0
	fi
elif [ "$3" -eq 1 ] ; then
	count="$4"
	truncsize=$(( $count * (32*8*1024*1024) ))
	truncate -s "$truncsize" "$tempfilename"
	
	exit 0
	
elif [ "$3" -eq 4 ] ; then
	newfilename="$filename"".concatenating"
	
	#co tempfile lai 1 byte
	filesize="$4"
	truncsize=$(( $filesize - 1 ))
	truncate -s "$truncsize" "$newfilename"
	exit 0
	
#"$3" -eq 3
else
	if [ "$4" -eq 0 ] ; then
		
		#co tempfile lai 1 byte
		filesize="$5"
		truncsize=$(( $filesize - 1 ))
		truncate -s "$truncsize" "$tempfilename"
		
		#chuan bi doi ten
		newfilename="$filename"".concatenating"
		
		rs=$(pgrep -f "$catfileinremote")
		#neu da append xong
		if [ "$6" -ne 0 ] && [ ! "$rs" ] ; then
			
			filesize=$(wc -c "$filename" | awk '{print $1}')
			truncsize=$(( (filesize / (8*1024*1024) ) * (8*1024*1024) ))
			rm "$partialfile"
			dd if="$filename" of="$partialfile" bs=10MB count=2 iflag=skip_bytes skip="$truncsize"

			#chuan bi file cat
			touch "$catfileinremote"
			truncate -s 0 "$catfileinremote"
			echo 'mv "$1" "$3"' >> "$catfileinremote"
			echo 'truncate -s "$4" "$3"' >> "$catfileinremote"
			echo 'cat "$2" >> "$3"' >> "$catfileinremote"
			echo 'rm "$2"' >> "$catfileinremote"
			
			bash "$catfileinremote" "$filename" "$tempfilename" "$newfilename" "$truncsize" &
			
			while true; do
				if [ -f "$tempfilename" ] ; then
					sleep 1
				else
					break
				fi
			done
			
		elif [ "$6" -ne 0 ] && [ "$rs" ] ; then
			while true; do
				if [ -f "$tempfilename" ] ; then
					sleep 1
				else
					break
				fi
			done
		
		#neu copy xong
		elif [ "$6" -eq 0 ] ; then
			mv "$tempfilename" "$newfilename"
		fi

		exit 0
		
	elif [ "$4" -eq 1 ] ; then
		mv "$filename"".concatenating" "$filename"
		exit 0
	else
		if [ "$5" -eq 0 ] ; then
			rm "$filename"".concatenating"
		else
			mv "$filename"".concatenating" "$filename"
			filesize="$5"
			truncsize=$(( (filesize / (8*1024*1024) ) * (8*1024*1024) ))
			truncate -s "$truncsize" "$filename"
			cat "$partialfile" >> "$filename"
		fi
		
		exit 0
	fi
fi



