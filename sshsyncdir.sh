#!/bin/bash

shopt -s dotglob
shopt -s nullglob

appdir_local=/home/dungnt/ShellScript/sshsyncapp
appdir_remote=/home/backup

memtemp_local="$appdir_local"/.temp
memtemp_remote="$appdir_remote"/.temp

compare_listdir_inremote=comparelistdir_remote.sh
compare_listfile_inremote=comparelistfile_remote.sh
getmd5hash_inremote=getmd5hash_inremote.sh
truncatefile_inremote=truncatefile_inremote.sh
dir_contains_uploadfiles="$appdir_local"/remotefiles

destipv6addr="backup@192.168.1.58"
destipv6addr_scp="backup@[192.168.1.58]"

fileprivatekey=/home/dungnt/.ssh/id_ed25519_privatekey
logtimedir_remote=/home/dungnt/MyDisk_With_FTP/logtime
logtimefile=logtimefile.txt
#file mang thong tin ds file trong dir --> up len de so sanh
outputfileforcmp_inremote=outputfile_inremote.txt
outputdirforcmp_inremote=outputdir_inremote.txt
uploadmd5hashfile=md5hashfile_fromlocal.txt


sleeptime=5
#for PRINTING
prt=1
#for OS Ubuntu 64
OS_Ver=1

#----------------------------------------TOOLS-------------------------------------

myecho(){
	local param=$1
	
	if [ $prt -eq 1 ]; then
			echo "$param"
	fi
}

myprintf(){
	local param1=$1
	local param2=$2
	
	if [ $prt -eq 1 ]; then
			printf "$param1"": %s\n" "$param2"
	fi
}

#-------------------------------CHECK NETWORK-------------------------------------

check_network(){
	local state
	local cmd
	
	#trang thai mac dinh=1:ko co mang
	state=1
	
	if [ "$OS_Ver" -eq 1 ] ; then
		ping -c 1 -W 1 -4 google.com > /dev/null
		cmd=$?
	else
		ping -4 google.com > /dev/null
		cmd=$?
	fi
	
	if [ "$cmd" -eq 0 ] ; then
		#co mang
		state=0
	fi 
	
	if [ "$state" -eq 1 ] ; then
		if [ "$OS_Ver" -eq 1 ] ; then
			ping -c 1 -W 1 -4 vnexpress.net > /dev/null
			cmd=$?
		else
			ping -4 vnexpress.net > /dev/null
			cmd=$?
		fi
	
		if [ "$cmd" -eq 0 ] ; then
			#co mang
			state=0
		fi 
		
	fi

	#0: co mang
	#1: ko co mang
	return "$state"
}

#------------------------------ VERIFY ACTIVE USER --------------------------------
verify_logged() {
	#mac dinh la ko thay active user 
	local kq
	local result
	local cmd
	local line
	local value
	local curtime
	local delaytime
	
	kq=1
	
	if [ -f "$fileprivatekey" ] ; then
	
		result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "tail ${logtimedir_remote}/${logtimefile}")
		cmd=$?
		echo "$result"
		
		if [ "$cmd" -eq 0 ] ; then
				#echo 'tim thay' $logtimefile
				if [ "$result" ] ; then
					curtime=$(($(date +%s%N)/1000000))
					#printf 'curtime:%s\n' "$curtime"
					value=$(echo "${result##*$'\n'}")
					printf 'value:%s\n' "$value"
					delaytime=$(( ( $curtime - $value ) / 60000 ))
					printf 'delaytime:%s\n' "$delaytime"" minutes"
					if [ "$delaytime" -gt 6 ] ; then
						#ko thay active web user
						kq=0
					else
						#tim thay co active web user
						kq=255
					fi
				fi
		fi
	fi

	#1: run function fail
	#0: no active web user found
	#255: active web user found
	return "$kq"
}

#------------------------------ FIND SAME FILE --------------------------------

find_list_same_files () {
	local param1=$1
	local param2=$2
	local count=0
	local mytemp="$memtemp_local"
	local workingdir=$(pwd)
	local cmd
	local cmd1
	local cmd2
	local cmd3
	local result
	local pathname
	local filesize
	local md5hash
	local mtime
	local mtime_temp
	local listfiles="listfilesforcmp.txt"
	local outputfile_inremote="$outputfileforcmp_inremote"
	local loopforcount
	
	rm "$mytemp"/*

	cd "$param1"/
	
	touch "$mytemp"/"$listfiles"
	
	#ERROR: co the co loi khi file vua bi xoa truoc khi lay filezise....
	#giai quyet: lay filesize cuoi cung, neu =0 --> bi xoa roi
	for pathname in ./* ;do
		if [ -f "$pathname" ] ; then 
			md5hash=$(head -c 1024 "$pathname" | md5sum | awk '{ print $1 }')
			#md5tailhash=$(get_src_content_file_md5sum "$pathname")
			mtime_temp=$(stat "$pathname" --printf='%y\n')
			mtime=$(date +'%s' -d "$mtime_temp")
			filesize=$(wc -c "$pathname" | awk '{print $1}')
			#printf "%s/%s/%s/%s/%s/%s\n" "$pathname" "f" "$filesize" "$md5hash" "$md5tailhash" "$mtime" >> "$mytemp"/"$listfiles"
			printf "%s/%s/%s/%s/%s\n" "$pathname" "f" "$filesize" "$md5hash" "$mtime" >> "$mytemp"/"$listfiles"
		fi
	done

	cd "$workingdir"/
	
	result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$mytemp"/"$listfiles" "$destipv6addr_scp":"$memtemp_remote"/)
	cmd1=$?
	myprintf "scp 1 listfile" "$cmd1"
			
	result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$compare_listfile_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
	cmd2=$?
	myprintf "scp 1 shellfile" "$cmd2"

	result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "rm ${memtemp_remote}/${outputfile_inremote}")
	cmd3=$?
	
	myprintf "ssh remove old outputfile" "$cmd3"
	pathname=$(echo "$param2" | tr -d '\n' | xxd -pu -c 1000000)
	
	if [ "$cmd1" -eq 0 ] && [ "$cmd2" -eq 0 ] && [ "$cmd3" -ne 255 ] ; then
		for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
		do
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${compare_listfile_inremote} ${listfiles} ${pathname} ${outputfile_inremote}")
			cmd=$?
			myprintf "ssh generate new outputfile" "$cmd"
			if [ "$cmd" -eq 0 ] ; then
				break
			else
				sleep 1
			fi
		done
		
		if [ "$cmd" -eq 0 ] ; then
			result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$destipv6addr_scp":"$memtemp_remote"/"$outputfile_inremote" "$mytemp"/)
			cmd=$?
			myprintf "scp getback outputfile" "$cmd"
		fi
	fi
}

#------------------------------FIND SAME DIRS--------------------------------------

find_list_same_dirs () {
	local param1=$1
	local param2=$2
	local count
	local workingdir=$(pwd)
	local cmd
	local cmd1
	local cmd2
	local cmd3
	local result
	local pathname
	local subpathname
	local filesize
	local listfiles="listdirsforcmp.txt"
	local outputdir_inremote="$outputdirforcmp_inremote"
	local loopforcount
	
	rm "$memtemp_local"/*

	cd "$param1"/
	
	touch "$memtemp_local"/"$listfiles"
	
	for pathname in ./* ; do
		if [ -d "$pathname" ] ; then 
			printf "%s/b/%s/%s\n" "$pathname" "d" "0" >> "$memtemp_local"/"$listfiles"
			count=0
			cd "$param1"/"$pathname"
			for subpathname in ./* ; do
				if [ -d "$subpathname" ] ; then 
					printf "%s/n/%s/%s\n" "$subpathname" "d" "1" >> "$memtemp_local"/"$listfiles"
				else
					printf "%s/n/%s/%s\n" "$subpathname" "f" "1" >> "$memtemp_local"/"$listfiles"
				fi
				count=$(($count + 1))
				if [ "$count" -eq 5 ] ; then
					break
				fi
			done
			printf "%s/e/%s/%s\n" "$pathname" "d" "0" >> "$memtemp_local"/"$listfiles"		
			cd "$param1"/
		fi
		
	done
	
	
	cd "$workingdir"/
	
	result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$memtemp_local"/"$listfiles" "$destipv6addr_scp":"$memtemp_remote"/)
	cmd1=$?
	myprintf "scp 1 listfile" "$cmd1"
			
	result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$compare_listdir_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
	cmd2=$?
	myprintf "scp 1 shellfile" "$cmd2"

	result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "rm ${memtemp_remote}/${outputdir_inremote}")
	cmd3=$?
	
	myprintf "ssh remove old outputfile" "$cmd3"
	pathname=$(echo "$param2" | tr -d '\n' | xxd -pu -c 1000000)
	
	if [ "$cmd1" -eq 0 ] && [ "$cmd2" -eq 0 ] && [ "$cmd3" -ne 255 ] ; then
		for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
		do
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${compare_listdir_inremote} ${listfiles} ${pathname} ${outputdir_inremote}")
			cmd=$?
			myprintf "ssh generate new outputdir" "$cmd"
			if [ "$cmd" -eq 0 ] ; then
				break
			else
				sleep 1
			fi
		done
		
		if [ "$cmd" -eq 0 ] ; then
			result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$destipv6addr_scp":"$memtemp_remote"/"$outputdir_inremote" "$memtemp_local"/)
			cmd=$?
			myprintf "scp getback outputdir" "$cmd"
		fi
	fi
}

#-------------------------------------SYNC-----------------------------------------
sync_dir(){
	local param1=$1
	local param2=$2
	local mytemp="$memtemp_local"
	local outputdir_inremote="$outputdirforcmp_inremote"
	local outputfile_inremote="$outputfileforcmp_inremote"
	local cmd
	local findresult
	local count
	local total
	local beforeslash
	local afterslash_1
	local afterslash_2
	local afterslash_3
	local afterslash_4
	local afterslash_5
	local afterslash_6
	local afterslash_7
	
	# declare array
	declare -a dirname
	
	# declare array
	declare -a name
	declare -a size
	declare -a md5hash
	declare -a mtime
	declare -a mtime_local
	declare -a apporcop
	
	# declare array
	local countother
	declare -a nameother
	declare -a statusother
	
	printf "%s vs %s\n" "$param1" "$param2" 
	
	#dong bo thu muc truoc
	find_list_same_dirs "$param1" "$param2"
	
	if [ -f "$mytemp"/"$outputdir_inremote" ] ; then
		count=0
		while IFS=/ read beforeslash afterslash_1 afterslash_2 afterslash_3
		do
			#echo "$afterslash_1"
			#echo "$afterslash_2"
			if [ "$afterslash_1" != "" ] ; then
				if [ "$afterslash_2" -ne 5 ] ; then
					dirname[$count]="$afterslash_1"
					count=$(($count + 1))				
				fi
			fi
		done < "$mytemp"/"$outputdir_inremote"
		
		for i in "${!dirname[@]}"
		do
			#echo "$param1"/"${dirname[$i]}"
			#echo "$param2"/"${dirname[$i]}"
			sync_dir "$param1"/"${dirname[$i]}" "$param2"/"${dirname[$i]}"
		done
	fi
	
	unset beforeslash
	unset afterslash_1
	unset afterslash_2
	
	#dong bo files
	find_list_same_files "$param1" "$param2"
	
	if [ -f "$mytemp"/"$outputfile_inremote" ] ; then
		count=0
		countother=0
		total=0
		while IFS=/ read beforeslash afterslash_1 afterslash_2 afterslash_3 afterslash_4 afterslash_5 afterslash_6 afterslash_7
		do
			if [ "$afterslash_1" != "" ] ; then
				if [ "$afterslash_2" -eq 0 ] ; then
					name[$count]="$afterslash_1"
					size[$count]="$afterslash_4"
					md5hash[$count]="$afterslash_5"
					mtime[$count]="$afterslash_6"
					mtime_local[$count]="$afterslash_7"
					echo "needappend:""${name[$count]}""-----""${size[$count]}""-----""${md5hash[$count]}""-----""${mtime[$count]}"
					apporcop[$count]=1
					count=$(($count + 1))
				elif [ "$afterslash_2" -eq 4 ] || [ "$afterslash_2" -eq 5 ] ; then
					name[$count]="$afterslash_1"
					size[$count]="$afterslash_4"
					md5hash[$count]="$afterslash_5"
					mtime[$count]="$afterslash_6"
					mtime_local[$count]="$afterslash_7"
					echo "needcopy:""${name[$count]}""-----""${size[$count]}""-----""${md5hash[$count]}""-----""${mtime[$count]}"
					apporcop[$count]=45
					count=$(($count + 1))
				else
					nameother[$countother]="$afterslash_1"
					statusother[$countother]="$afterslash_2"
					countother=$(($countother + 1))
				fi
				
				if [ "$afterslash_2" -ne 3 ] ; then
					total=$(($total + 1))
				fi
			else
				echo "--------------------""$total"" files received valid---------------------"
			fi
		done < "$mytemp"/"$outputfile_inremote"
		
		count=0
		for i in "${!nameother[@]}"
		do
			printf '%s status: %s\n' "${nameother[$i]}" "${statusother[$i]}" 
			count=$(($count + 1))
		done
		echo 'file ko duoc tinh------------'"$count"
		
		count=0
		for i in "${!name[@]}"
		do
			findresult=$(find "$param1" -maxdepth 1 -type f -name "${name[$i]}")
			
			cmd=$?
			#neu tim thay
			if [ "$cmd" -eq 0 ] && [ "$findresult" ] ; then
				#echo "nhung file giong ten nhung khac attribute:""$findresult"
				if [ "${apporcop[$i]}" -eq 1 ] ; then
					#file local da bi modify (ko ro vi tri bi modify) ---> append with hash
					echo "->append:""mtimelc:""${mtime_local[$i]}"" mtime:""${mtime[$i]}""-""$param1"" ""$param2"" ""${name[$i]}"" ""${size[$i]}"
					append_file_with_hash_checking "$param1" "$param2" "${name[$i]}" "${size[$i]}"
				else
					echo "->copy:""$param1"" ""$param2"" ""${name[$i]}"
					copy_file "$param1" "$param2" "${name[$i]}"
				fi
			#neu ko tim thay
			else
				printf '**********************************file not found\n'
			fi
			count=$(($count + 1))
		done
		
		echo "--------------------""$count"" files can append hoac copy ---------------------"
		
	#	return 0
	#else
	#	return 1
	fi
}
	
#------------------------------ APPEND FILE --------------------------------

append_native_file(){
	local dir1=$1
	local dir2=$2
	local filename=$3
	local filesizeinremote=$4
	local mtimebeforeup=$5
	local mtimeafterup
	local filenameinhex=$(echo "$dir2"/"$filename" | tr -d '\n' | xxd -pu -c 1000000)
	local result
	local cmd
	local cmd1
	local cmd2
	local loopforcount
	local count
	local cutsize
	local filesize
	local newfilesize
	local checksize
	local tempfilename="tempfile.being"
	local end
	local truncateparam4
	local uploadsize
	local loopforcount2
	
	declare -a getpipest
	
	#echo "$dir2""/""$filename"
	for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
	do		
		#vuot timeout
		if [ "$loopforcount" -eq 20 ] ;  then
			echo 'upload truncate file and catfile timeout, nghi dai'
			return 1
		fi
		
		result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$truncatefile_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
		cmd1=$?
		myprintf "scp 1 truncatefile" "$cmd1"
		
		result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${memtemp_remote}/${tempfilename} ${filenameinhex} 0 ${filesizeinremote}")
		cmd2=$?
		myprintf "run truncatefile in remote" "$cmd2"
		
		if [ "$cmd1" -eq 0 ] && [ "$cmd2" -eq 0 ] ; then
			#thoat vong lap for
			break
		else
			sleep 15			
		fi	
	done
	
	count=0
	end=0
	filesize=$(wc -c "$dir1"/"$filename" | awk '{print $1}')
	#khi filesize=rong do bi xoa dot ngot --> return 1
	if [ ! "$filesize" ] ; then
		return 1
	fi
	
	uploadsize=$(( $filesize - ($filesizeinremote / (8*1024*1024))*(8*1024*1024) ))
	
	while true; do
		for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
		do		
			#vuot timeout
			if [ "$loopforcount" -eq 20 ] ;  then
				echo 'server busy, nghi dai'
				return 1
			fi
		
			verify_logged
			cmd1=$?
			myprintf "verify active user" "$cmd1"
		
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "netstat -atn | grep ':22 ' | grep 'ESTABLISHED' | wc -l")
			cmd2=$?
			myprintf "run countsshuser" "$cmd2"
			myprintf "num sshuser" "$result"
			
			if [ "$cmd1" -eq 0 ] && [ "$cmd2" -ne 255 ] && [ "$result" -lt 2 ] ; then
				#thoat vong lap for
				break
			else
				sleep 15			
			fi	
		done
		
		rm "$memtemp_local"/"$tempfilename"
		
		if [ "$count" -eq 0 ] ; then
			cutsize=$(( ($filesizeinremote / (8*1024*1024) ) ))
		else
			cutsize=$(( $cutsize + 32 ))
		fi
		
		checksize=$(( ($cutsize + 32)*8*1024*1024 ))
		
		newfilesize=$(wc -c "$dir1"/"$filename" | awk '{print $1}')
		echo "$newfilesize"
		if [ ! "$newfilesize" ] || [ "$newfilesize" -ne "$filesize" ] ; then
			end=2
			truncateparam4=2
			echo "ket thuc 2"
		elif [ "$checksize" -ge "$filesize" ] ; then
			end=1
			truncateparam4=1
			echo "ket thuc 1"
		fi
		
		SECONDS=0
		if [ "$newfilesize" -eq "$filesize" ] ; then
			loopforcount=0
			while true;
			do	
				loopforcount=$(( $loopforcount + 1 ))
				
				#vuot timeout
				if [ "$loopforcount" -eq 20 ] ;  then
					echo 'uploadfile timeout, nghi dai'
					return 1
				fi
				
				echo 'begin upload partial file'
				echo "cutsize: ""$cutsize"
				
				dd if="$dir1"/"$filename" bs="8M" count=32 skip="$cutsize" | ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "cat - >> ${memtemp_remote}/${tempfilename}"
				
				getpipest=( "${PIPESTATUS[@]}" )
				echo "upload file to remote ""${getpipest[0]}"" va ""${getpipest[1]}"
				
				if [ "${getpipest[0]}" -eq 0 ] && [ "${getpipest[1]}" -eq 0 ] ; then
					#thoat vong lap while trong cung
					break
				else
					loopforcount2=0
					while true; do
						loopforcount2=$(( $loopforcount2 + 1 ))
						if [ "$loopforcount2" -eq 16 ] ;  then
							echo 'truncate file while failing timeout, nghi dai'
							return 1
						fi
						result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${memtemp_remote}/${tempfilename} ${filenameinhex} 1 ${count}")
						cmd=$?

						myprintf "run truncate file while failing in remote" "$cmd"
						
						if [ "$cmd" -eq 0 ] ; then
							break
						else
							sleep 1
						fi
					done		
				fi	
			
			done
		fi
		echo "elapsed time (using \$SECONDS): $SECONDS seconds"
		
		count=$(( $count + 1 ))
		
		
		if [ "$end" -eq 1 ] ; then
			#do thoi gian last truncate and rsync
			SECONDS=0
			
			for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
			do	
				#vuot timeout
				if [ "$loopforcount" -eq 20 ] ;  then
					echo 'truncate end file timeout, nghi dai'
					return 1
				fi
				
				
				echo 'begin truncate end file'
				result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${memtemp_remote}/${tempfilename} ${filenameinhex} 3 0 ${uploadsize} ${filesizeinremote}")
				cmd=$?
				myprintf "truncate end file in remote" "$cmd"
				
				
				if [ "$cmd" -eq 0 ] ; then
					#thoat vong lap for
					break
				else
					sleep 15			
				fi	
			done
			
			loopforcount=0
			while true;
			do	
				loopforcount=$(( $loopforcount + 1 ))
				
				#vuot timeout
				if [ "$loopforcount" -eq 20 ] ;  then
					echo 'uploadfile timeout, nghi dai'
					return 1
				fi
				#rsync tu khoi phuc khi mat mang, co mang lai
				echo 'append last of file'		
				rsync -vah --append --iconv=utf-8,utf-8 --protect-args -e "ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i ${fileprivatekey}" "$dir1"/"$filename" "$destipv6addr_scp":"$dir2"/"$filename"".concatenating"
				cmd=$?
				myprintf "append last of file in remote" "$cmd"
				
				if [ "$cmd" -eq 0 ] ; then
					break
				else
					loopforcount2=0
					while true; do
						loopforcount2=$(( $loopforcount2 + 1 ))
						if [ "$loopforcount2" -eq 16 ] ;  then
							echo 'truncate file when rsync fail, timeout, nghi dai'
							return 1
						fi
						result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${memtemp_remote}/${tempfilename} ${filenameinhex} 4 ${uploadsize}")
						cmd=$?

						myprintf "run truncate file when rsync fail in remote" "$cmd"
						
						if [ "$cmd" -eq 0 ] ; then
							break
						else
							sleep 1
						fi
					done	
				fi
			done

			mtimeafterup=$(stat "$dir1"/"$filename" --printf='%y\n')
			if [ "$mtimeafterup" ] ; then
				mtimeafterup=$(date +'%s' -d "$mtimeafterup")
				if [ "$mtimeafterup" == "$mtimebeforeup" ] ; then
					truncateparam4=1
				else
					echo "mtime ko bang mtimebeforeup 1"
					truncateparam4=2
				fi
			else
				echo "mtime ko bang mtimebeforeup 2"
				truncateparam4=2
			fi
			
			echo "last truncate and rsync elapsed time (using \$SECONDS): $SECONDS seconds"
		fi
		
		
		if [ "$end" -ne 0 ] ; then

			for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
			do	
				#vuot timeout
				if [ "$loopforcount" -eq 20 ] ;  then
					echo 'movement file timeout, nghi dai'
					return 1
				fi
				
				echo 'begin movement file'
				result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${memtemp_remote}/${tempfilename} ${filenameinhex} 3 ${truncateparam4} ${filesizeinremote}")
				cmd=$?
				myprintf "movement file in remote" "$cmd"
			
				if [ "$cmd" -eq 0 ] ; then
					#thoat vong lap for
					break
				else
					sleep 15			
				fi	
			done
			
			if [ "$truncateparam4" -eq 1 ] ; then
				return 0
			else
				return 1
			fi
		
		fi
	done
}

append_file_with_hash_checking(){
	local param1=$1
	local param2=$2
	local filename=$3
	local filesize_remote=$4
	local truncnum
	local hashlocalfile
	local hashremotefile
	local result
	local cmd
	local cmd1
	local cmd2
	local filesize
	local loopforcount
	local temphashfilename="tempfile.totalmd5sum.being"
	local tempfilename
	local mtime
	
	rm "$memtemp_local"/"$temphashfilename"
	
	tempfilename=$(echo "$param2""/""$filename" | tr -d '\n' | xxd -pu -c 1000000)
	
	for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
	do		
		#vuot timeout
		if [ "$loopforcount" -eq 20 ] ;  then
			echo 'append with hash timeout, nghi dai'
			return 1
		fi
		
		result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$getmd5hash_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
		cmd1=$?
		myprintf "scp 1 shellmd5hashfile" "$cmd1"
	
		result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${getmd5hash_inremote} ${tempfilename}")
		cmd2=$?
		echo "get ""$cmd2"" md5sum:""$result"
		
		if [ "$cmd1" -eq 0 ] && [ "$cmd2" -eq 0 ] ; then
			#thoat vong lap for
			break
		else
			sleep 15			
		fi	
	done
		
	hashremotefile=$(echo "$result" | awk '{ print $1 }')
	filesize=$(wc -c "$param1"/"$filename" | awk '{print $1}')

	if [ -f "$param1"/"$filename" ] && [ "$filesize" -gt 0 ] ; then
		truncnum=$(( ( $filesize_remote / 500000000 ) + 1 ))
		echo 'truncnum ' "$truncnum"
		dd if="$param1"/"$filename" of="$memtemp_local"/"$temphashfilename" bs="500MB" count="$truncnum" skip=0
		
		if [ -f "$memtemp_local"/"$temphashfilename" ] ; then
			truncate -s "$filesize_remote" "$memtemp_local"/"$temphashfilename"
			hashlocalfile=$(md5sum "$memtemp_local"/"$temphashfilename" | awk '{ print $1 }')
			
			if [ "$hashlocalfile" == "$hashremotefile" ] ; then
				echo 'has same md5hash after truncate-->continue append'
				mtime=$(stat "$param1"/"$filename" --printf='%y\n')
				if [ "$mtime" ] ; then
					mtime=$(date +'%s' -d "$mtime")
					append_native_file "$param1" "$param2" "$filename" "$filesize_remote" "$mtime"
					return "$?"
				else
					echo 'mtime changed-->can not continue append'
					return 1
				fi
			else
				echo 'no same md5hash after truncate-->copy total file'
				copy_file "$param1" "$param2" "$filename"
				return "$?"
			fi
			
		else
			echo 'dd command error, nghi dai'
			return 1
		fi
		
	else
		echo 'big error,ko thay file, nghi dai'
		return 1
	fi
		
}

copy_file() {
	local dir1=$1
	local dir2=$2
	local filename=$3
	local mtime

	mtime=$(stat "$dir1"/"$filename" --printf='%y\n')
	
	if [ "$mtime" ] ; then
		mtime=$(date +'%s' -d "$mtime")
		append_native_file "$dir1" "$dir2" "$filename" 0 "$mtime"
		return "$?"
	else
		echo 'mtime changed-->can not continue copy'
		return 1
	fi
}


main(){
	local cmd
	local result
	
	if [ ! -d "$memtemp_local" ] ; then
		mkdir "$memtemp_local"
	fi
	
	rm "$memtemp_local"/*

	while true; do
	
		check_network
		cmd=$?
		myprintf "check network" "$cmd"
		
		if [ "$cmd" -eq 0 ] && [ -f "$fileprivatekey" ] ; then
			
			#add to know_hosts for firsttime
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "mkdir ${memtemp_remote}")
			cmd=$?
			myprintf "mkdir temp at remote" "$cmd"

			verify_logged
			cmd=$?
			myprintf "verify active user" "$cmd"
			
			break
			
			#if verifyresult: no active user -> sync_dir
			if [ "$cmd" -gt 10 ] ; then
				myecho "begin sync dir"
				#sync_dir "$dir_ori" "$dir_dest"
				echo "go to sleep 1"
				#sleep "$sleeptime"m
			else
				echo "go to sleep 2"
				#sleep "$sleeptime"m
			fi
		else
			echo "go to sleep 00"
			#sleep "$sleeptime"m
		fi
	done
	
}

mtime=$(stat "/home/dungnt/ShellScript/tối quá"/"file500mb.txt" --printf='%y\n')
mtime=$(date +'%s' -d "$mtime")

#main
#find_list_same_files "/home/dungnt/ShellScript/tối quá" "/home/backup/biết sosanh"
#find_list_same_dirs "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục"
sync_dir "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục"
#copy_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "file tét.txt"
#append_native_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "file tét.txt" 20000000 "$mainhash"
#copy_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "noi"
#append_native_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "noi" 1 "$mainhash"
#copy_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "file500mb.txt"
#append_native_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "file500mb.txt" 400000000 "$mtime"
