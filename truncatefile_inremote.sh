#!/bin/bash

shopt -s dotglob
shopt -s nullglob

tempfilename="$1"

filename=$(echo "$2" | tr -d '\n' | xxd -r -p)

catfileinremote="/home/backup/.temp/catfileinremote.sh"

#echo "filename ban dau:""$filename" >> /home/backup/luutru.txt

#-------------------------------------------------------------------------------

generatecatfile(){
	local filename="$1"

	truncate -s 0 "$filename"
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
	echo '	local filesize="$3"' >> "$filename"
	echo '	local cmd1' >> "$filename"
	echo '	local cmd2' >> "$filename"
	echo '	local result' >> "$filename"
	echo '	local numcount' >> "$filename"
	echo '	local numcountmodulo' >> "$filename"
	echo '	local skipsize=0' >> "$filename"
	echo '	truncate -s 0 "$tempfilename"' >> "$filename"
	echo '	numcount=$(( $filesize/(500*1000*1000) ))' >> "$filename"
	echo '	numcountmodulo=$(( $filesize%(500*1000*1000) ))' >> "$filename"
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
			#if [ 0 -eq 0 ] ; then
	echo '				break' >> "$filename"
	echo '			else' >> "$filename"
	echo '				echo "sleep 15s"' >> "$filename"
	echo '				sleep 15		' >> "$filename"	
	echo '			fi	' >> "$filename"
	echo '		done' >> "$filename"
	echo '		dd if="$filename" bs="500MB" count=1 skip="$skipsize" >> "$tempfilename"' >> "$filename"
	echo '		skipsize=$(( $skipsize + 1 ))' >> "$filename"
	echo '	done' >> "$filename"
	echo '	truncsize=$(( (filesize / (8*1024*1024) ) * (8*1024*1024) ))' >> "$filename"
	echo '	truncate -s "$truncsize" "$tempfilename"' >> "$filename"
	echo '}' >> "$filename"
	echo 'appendfileinremotefunc "$1" "$2" "$3"' >> "$filename"

}
#-------------------------------------------------------------------------------
#neu tham so thu ba = 0
if [ "$3" -eq 0 ] ; then
	#neu ton tai tham so thu tu = 0, copy total file --> remove old file
	if [ "$4" -eq 0 ] ; then
		
		rm "$filename"
		
		rm "$tempfilename"
		
		rs=$(pgrep -f "$catfileinremote")
		
		if [ "$rs" ] ; then
			kill "$rs"
		fi
		
		exit 0
	#neu la append (ktra file ton tai)
	elif [ -f "$filename" ] ; then

		rm "$tempfilename"
				
		rs=$(pgrep -f "$catfileinremote")
		
		if [ "$rs" ] ; then
			kill "$rs"
		fi
		
		exit 0
	fi
elif [ "$3" -eq 1 ] ; then
	#neu la append
	if [ "$4" -ne 0 ] ; then
		rs=$(pgrep -f "$catfileinremote")
		if [ ! "$rs" ] ; then
			if [ ! -f "$tempfilename" ] ; then
				filesize=$(stat -c %s "$filename")
				#chuan bi file cat
				generatecatfile "$catfileinremote"
				bash "$catfileinremote" "$filename" "$tempfilename" "$filesize" &
				
				while true; do
					rs=$(pgrep -f "$catfileinremote")
					if [ "$rs" ] ; then
						sleep 1
					else
						break
					fi
				done
			fi
		fi
	#neu la copy
	else
		truncate -s 0 "$tempfilename"
	fi	
	exit 0
elif [ "$3" -eq 2 ] ; then
	count="$4"
	truncsize=$(( $count * (32*8*1024*1024) ))
	truncate -s "$truncsize" "$tempfilename"

	exit 0

elif [ "$3" -eq 3 ] ; then

	#co tempfile lai 1 byte
	filesize="$4"
	temptruncsize=$(( $filesize - 1 ))
	truncate -s "$temptruncsize" "$tempfilename"

	exit 0

elif [ "$3" -eq 4 ] ; then
	if [ "$4" -eq 1 ] ; then
		mv "$tempfilename" "$filename"
	else
		rm "$tempfilename"
	fi
	exit 0

#xu ly lai $3=5
elif [ "$3" -eq 5 ] ; then
	if [ -f "$tempfilename" ] ; then
		tempfilesize=$(stat -c %s "$tempfilename")
		echo "$tempfilesize"
	fi
	
	exit 0
#xu ly lai $3=6
else
	truncsize="$4"
	truncate -s "$truncsize" "$tempfilename"
	exit 0
fi



