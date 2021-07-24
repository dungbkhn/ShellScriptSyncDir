#!/bin/bash

shopt -s dotglob
shopt -s nullglob

tempfilename="$1"

filename=$(echo "$2" | tr -d '\n' | xxd -r -p)

partialfile="/home/backup/.temp/partialfile.being"

catfileinremote="/home/backup/.temp/catfileinremote.sh"

#echo "filename ban dau:""$filename" >> /home/backup/luutru.txt

#-------------------------------------------------------------------------------

generatecatfile(){
	local filename="$1"
	if [ ! -f "$filename" ] ; then
		touch "$filename"
		echo '#!/bin/bash' >> "$filename"
		echo 'shopt -s dotglob' >> "$filename"
		echo 'shopt -s nullglob' >> "$filename"
		echo 'logtimedir_remote=/home/dungnt/StoreProj/logtime' >> "$filename"
		echo 'logtimefile=logtimefile.txt' >> "$filename"
		echo 'verify_logged() {' >> "$filename"
		echo '	local kq' >> "$filename"
		echo '	local cmd' >> "$filename"
		echo '	local value' >> "$filename"
		echo '	local curtime' >> "$filename"
		echo '	local delaytime' >> "$filename"
		echo '	kq=1' >> "$filename"
		echo '	value=$(tail -n 1 "$logtimedir_remote"/"$logtimefile")' >> "$filename"
		echo '	cmd=$?' >> "$filename"
		echo '	if [ "$cmd" -eq 0 ] ; then' >> "$filename"
		echo '		if [ "$value" ] ; then' >> "$filename"
		echo '			curtime=$(($(date +%s%N)/1000000))' >> "$filename"
		echo '			echo "$value"' >> "$filename"
		echo '			delaytime=$(( ( $curtime - $value ) / 60000 ))' >> "$filename"
		echo '			echo "$delaytime"' >> "$filename"
		echo '			if [ "$delaytime" -gt 6 ] ; then' >> "$filename"
		echo '				kq=0' >> "$filename"
		echo '			else' >> "$filename"
		echo '				kq=255' >> "$filename"
		echo '			fi' >> "$filename"
		echo '		fi' >> "$filename"
		echo '	fi' >> "$filename"
		echo '	return "$kq"' >> "$filename"
		echo '}' >> "$filename"
		echo 'appendfileinremotefunc(){' >> "$filename"
		echo '	local filename="$1"' >> "$filename"
		echo '	local tempfilename="$2"' >> "$filename"
		echo '	local newfilename="$3"' >> "$filename"
		echo '	local truncsize="$4"' >> "$filename"
		echo '	local tempfilesize="$5"' >> "$filename"
		echo '	local cmd1' >> "$filename"
		echo '	local cmd2' >> "$filename"
		echo '	local result' >> "$filename"
		echo '	local numcount' >> "$filename"
		echo '	local numcountmodulo' >> "$filename"
		echo '	local skipsize=0' >> "$filename"
		echo '	mv "$filename" "$newfilename"' >> "$filename"
		echo '	truncate -s "$truncsize" "$newfilename"' >> "$filename"
		echo '	numcount=$(( $tempfilesize/(500*1000*1000) ))' >> "$filename"
		echo '	numcountmodulo=$(( $tempfilesize%(500*1000*1000) ))' >> "$filename"
		echo '	if [ "$numcountmodulo" -ne 0 ] ; then' >> "$filename"
		echo '		numcount=$(( $numcount + 1 ))' >> "$filename"
		echo '	fi' >> "$filename"
		#test
		#echo '		while true; do	' >> "$filename"
		#echo '			sleep 1	' >> "$filename"
		#echo '		done' >> "$filename"
		#end test
		echo '	while [ "$skipsize" -lt "$numcount" ] ; do' >> "$filename"
		echo '		while true; do	' >> "$filename"
		echo '			verify_logged' >> "$filename"
		echo '			cmd1=$?' >> "$filename"
		echo '			echo "$cmd1"' >> "$filename"
		echo '			result=$(netstat -atn | grep ":22 " | grep "ESTABLISHED" | wc -l)' >> "$filename"
		echo '			cmd2=$?' >> "$filename"
		echo '			echo "$cmd2"" ""$result"' >> "$filename"
		echo '			if [ "$cmd1" -eq 0 ] && [ "$cmd2" -eq 0 ] && [ "$result" -lt 2 ] ; then' >> "$filename"
		echo '				break' >> "$filename"
		echo '			else' >> "$filename"
		echo '				echo "sleep 15s"' >> "$filename"
		echo '				sleep 15			' >> "$filename"
		echo '			fi	' >> "$filename"
		echo '		done' >> "$filename"
		echo '		dd if="$tempfilename" bs="500MB" count=1 skip="$skipsize" >> "$newfilename"' >> "$filename"
		echo '		skipsize=$(( $skipsize + 1 ))' >> "$filename"
		echo '	done' >> "$filename"
		echo '	rm "$tempfilename"' >> "$filename"
		echo '}' >> "$filename"
		echo 'appendfileinremotefunc "$1" "$2" "$3" "$4" "$5"' >> "$filename"
	fi
}

#-------------------------------------------------------------------------------
#neu tham so thu ba = 0
if [ "$3" -eq 0 ] ; then
	#neu ton tai tham so thu tu = 0, copy total file --> remove old file
	if [ "$4" -eq 0 ] ; then
		
		rm "$filename"
		
		rm "$tempfilename"

		touch "$tempfilename"
		
		rs=$(pgrep -f "$catfileinremote")
		
		if [ "$rs" ] ; then
			kill "$rs"
		fi
		
		exit 0
	#neu la append (ktra file ton tai)
	elif [ -f "$filename" ] ; then

		rm "$tempfilename"
		
		touch "$tempfilename"
		
		rs=$(pgrep -f "$catfileinremote")
		
		if [ "$rs" ] ; then
			kill "$rs"
		fi
		
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
	temptruncsize=$(( $filesize - 1 ))
	truncate -s "$temptruncsize" "$newfilename"
	exit 0
	
#"$3" -eq 3
else
	if [ "$4" -eq 0 ] ; then
		
		#co tempfile lai 1 byte
		filesize="$5"
		temptruncsize=$(( $filesize - 1 ))
		truncate -s "$temptruncsize" "$tempfilename"
		
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
			generatecatfile "$catfileinremote"
			
			bash "$catfileinremote" "$filename" "$tempfilename" "$newfilename" "$truncsize" "$temptruncsize" &
			
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



