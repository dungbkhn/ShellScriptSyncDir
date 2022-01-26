#!/bin/bash
#loi khi filesize=0 --> kothe sync
#./sshsyncdir.sh /home/dungnt/MySyncDir /home/dungnt/ShellScript/sshsyncapp 192.168.1.158 /home/dungnt/.ssh/id_ed25519_privatekey
shopt -s dotglob
shopt -s nullglob

#appdir_local=/home/dungnt/ShellScript/sshsyncapp
appdir_local="$2"
appdir_remote=/home/backup

memtemp_local="$appdir_local"/.temp
memtemp_remote="$appdir_remote"/.temp

getlistdirfiles_remote=getlistdirfiles_remote.sh
compare_listdir_inremote=comparelistdir_remote.sh
compare_listfile_inremote=comparelistfile_remote.sh
getmd5hash_inremote=getmd5hash_inremote.sh
truncatefile_inremote=truncatefile_inremote.sh
md5_fileC_inremote=md5.c
md5file=md5
dir_contains_uploadfiles="$appdir_local"/remotefiles

#destipv6addr="backup@192.168.1.158"
#destipv6addr_scp="backup@[192.168.1.158]"

destipv6addr="backup@""$3"
destipv6addr_scp="backup@[""$3""]"

#fileprivatekey=/home/dungnt/.ssh/id_ed25519_privatekey
fileprivatekey="$4"
logtimedir_remote=/home/dungnt/StoreProj/logtime
logtimefile=logtimefile.txt
#file mang thong tin ds file trong dir --> up len de so sanh
outputfileforcmp_inremote=outputfile_inremote.txt
outputdirforcmp_inremote=outputdir_inremote.txt
uploadmd5hashfile=md5hashfile_fromlocal.txt
stoppedfilelist=stoppedfilelist.txt
mainlogfile="$memtemp_local"/mainlog.txt
#errorfile=errors.txt

#for Sleep
sleeptime=10m
#for PRINTING
prt=3
#for OS Ubuntu 64
OS_Ver=1
#for DirHash
befDirHash=""
afDirHash=""
hashcount=0
hashcountmodulo=0

#----------------------------------------TOOLS-------------------------------------

mech(){
	local param=$1
	
	if [ $prt -eq 1 ]; then
		echo "$param"
	elif [ $prt -eq 2 ]; then
		echo "$param" >> "$mainlogfile"
	elif [ $prt -eq 3 ]; then
		echo "$param"
		echo "$param" >> "$mainlogfile"
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
	
		result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "tail -n 1 ${logtimedir_remote}/${logtimefile}")
		cmd=$?
		#echo "$result"
		
		if [ "$cmd" -eq 0 ] ; then
				if [ "$result" ] ; then
					curtime=$(($(date +%s%N)/1000000))
					value="$result"
					delaytime=$(( ( $curtime - $value ) / 60000 ))
					
					#printf 'delaytime:%s\n' "$delaytime"" minutes"
					
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
	
	rm "$mytemp"/"$listfiles"
	rm "$mytemp"/"$outputfile_inremote"
	
	cd "$param1"/
	cmd="$?"
	
	if [ "$cmd" -ne 0 ] ; then
		return 1
	fi
	
	touch "$mytemp"/"$listfiles"
	
	for pathname in ./* ;do
		if [ -f "$pathname" ] ; then 
			md5hash=$(head -c 1024 "$pathname" | md5sum | awk '{ print $1 }')
			#md5tailhash=$(get_src_content_file_md5sum "$pathname")
			mtime_temp=$(stat "$pathname" --printf='%y\n')
			mtime=$(date +'%s' -d "$mtime_temp")
			filesize=$(stat -c %s "$pathname")
			#printf "%s/%s/%s/%s/%s/%s\n" "$pathname" "f" "$filesize" "$md5hash" "$md5tailhash" "$mtime" >> "$mytemp"/"$listfiles"
			printf "%s/%s/%s/%s/%s\n" "$pathname" "f" "$filesize" "$md5hash" "$mtime" >> "$mytemp"/"$listfiles"
		fi
	done

	cd "$workingdir"/
	
	result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$mytemp"/"$listfiles" "$destipv6addr_scp":"$memtemp_remote"/)
	cmd1=$?
	mech "scp 1 listfile ""$cmd1"
			
	result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "rm ${memtemp_remote}/${outputfile_inremote}")
	cmd2=$?
	mech "ssh remove old outputfile ""$cmd2"
	
	pathname=$(echo "$param2" | tr -d '\n' | xxd -pu -c 1000000)
	
	if [ "$cmd1" -eq 0 ] && [ "$cmd2" -ne 255 ] ; then
		for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
		do
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${compare_listfile_inremote} ${listfiles} ${pathname} ${outputfile_inremote}")
			cmd=$?
			mech "ssh generate new outputfile ""$cmd"
			if [ "$cmd" -eq 0 ] ; then
				break
			else
				sleep 1
			fi
		done
		
		if [ "$cmd" -eq 0 ] ; then
			result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$destipv6addr_scp":"$memtemp_remote"/"$outputfile_inremote" "$mytemp"/)
			cmd=$?
			mech "scp getback outputfile ""$cmd"
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
	
	rm "$memtemp_local"/"$listfiles"
	rm "$memtemp_local"/"$outputdir_inremote"

	cd "$param1"/
	cmd="$?"
	
	if [ "$cmd" -ne 0 ] ; then
		return 1
	fi
	
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
	mech "scp 1 listfile ""$cmd1"
	
	result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "rm ${memtemp_remote}/${outputdir_inremote}")
	cmd2=$?
	mech "ssh remove old outputfile ""$cmd2"
	
	pathname=$(echo "$param2" | tr -d '\n' | xxd -pu -c 1000000)
	
	if [ "$cmd1" -eq 0 ] && [ "$cmd2" -ne 255 ] ; then
		for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
		do
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${compare_listdir_inremote} ${listfiles} ${pathname} ${outputdir_inremote}")
			cmd=$?
			mech "ssh generate new outputdir ""$cmd"
			if [ "$cmd" -eq 0 ] ; then
				break
			else
				sleep 1
			fi
		done
		
		if [ "$cmd" -eq 0 ] ; then
			result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$destipv6addr_scp":"$memtemp_remote"/"$outputdir_inremote" "$memtemp_local"/)
			cmd=$?
			mech "scp getback outputdir ""$cmd"
		fi
	fi
}


	
#------------------------------ APPEND FILE --------------------------------

append_native_file(){
	local dir1=$1
	local dir2=$2
	local filename=$3
	local filesizeinremote=$4
	local mtimebeforeup=$5
	local filesizewithremake=$6
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
	local tempfilename="/var/res/backup/.Temp/tempfile.being"
	local end
	local truncateparam4
	local uploadsize
	local loopforcount2
	
	declare -a getpipest
	
	if [ "$filesizewithremake" -eq 0 ] ; then
		for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
		do		
			#vuot timeout
			if [ "$loopforcount" -eq 20 ] ;  then
				mech 'upload truncate file and catfile timeout, nghi dai'
				return 1
			fi
			
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${tempfilename} ${filenameinhex} 0 ${filesizeinremote}")
			cmd=$?
			mech "run truncatefile in remote ""$cmd"
			
			if [ "$cmd" -eq 0 ] ; then
				#thoat vong lap for
				break
			else
				sleep 15			
			fi	
		done
		
		for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
		do	
			#vuot timeout
			if [ "$loopforcount" -eq 20 ] ;  then
				mech 'cp file in remote timeout, nghi dai'
				return 1
			fi
			
			mech 'begin cp file in remote'
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${tempfilename} ${filenameinhex} 1 ${filesizeinremote}")
			cmd=$?
			mech "cp file in remote ""$cmd"
		
			if [ "$cmd" -eq 0 ] ; then
				#thoat vong lap for
				break
			else
				sleep 15			
			fi	
		done
	fi
	
	filesize=$(stat -c %s "$dir1"/"$filename")
	#khi filesize=rong do bi xoa dot ngot --> return <> 0
	if [ ! "$filesize" ] ; then
		mech 'Notes: original file has been not found'
		return 250
	fi
	
	uploadsize=$filesize
	count=0
	end=0
		
	while true; do
		for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
		do		
			#vuot timeout
			if [ "$loopforcount" -eq 20 ] ;  then
				mech 'server busy, nghi dai'
				return 1
			fi
		
			verify_logged
			cmd1=$?
			mech "verify active user ""$cmd1"
		
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "netstat -atn | grep ':22 ' | grep 'ESTABLISHED' | wc -l")
			cmd2=$?
			mech "run countsshuser ""$cmd2"
			mech "num sshuser ""$result"
			
			if [ "$cmd1" -eq 0 ] && [ "$cmd2" -ne 255 ] && [ "$result" -lt 2 ] ; then
				#thoat vong lap for
				break
			else
				sleep 15			
			fi	
		done
		
		if [ "$count" -eq 0 ] ; then
			if [ "$filesizewithremake" -eq 0 ] ; then
				cutsize=$(( ($filesizeinremote / (8*1024*1024) ) ))
			else
				cutsize=$(( ($filesizewithremake / (8*1024*1024) ) ))
			fi
		else
			cutsize=$(( $cutsize + 32 ))
		fi
		
		checksize=$(( ($cutsize + 32)*8*1024*1024 ))
		
		newfilesize=$(stat -c %s "$dir1"/"$filename")
		mech "$newfilesize"
		if [ ! "$newfilesize" ] || [ "$newfilesize" -ne "$filesize" ] ; then
			end=2
			truncateparam4=2
			mech "ket thuc 2"
		elif [ "$checksize" -ge "$filesize" ] ; then
			end=1
			truncateparam4=1
			mech "ket thuc 1"
		fi
		
		SECONDS=0
		if [ "$newfilesize" -eq "$filesize" ] ; then
			
			loopforcount=0
			while true;
			do	
				loopforcount=$(( $loopforcount + 1 ))
				
				#vuot timeout
				if [ "$loopforcount" -eq 20 ] ;  then
					mech 'uploadfile timeout, nghi dai'
					return 1
				fi
				
				mech 'begin upload partial file'
				mech "cutsize: ""$cutsize"
				
				dd if="$dir1"/"$filename" bs="8M" count=32 skip="$cutsize" | ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "cat - >> ${tempfilename}"
				
				getpipest=( "${PIPESTATUS[@]}" )
				mech "upload file to remote ""${getpipest[0]}"" va ""${getpipest[1]}"
				
				if [ "${getpipest[0]}" -eq 0 ] && [ "${getpipest[1]}" -eq 0 ] ; then
					#thoat vong lap while trong cung
					break
				else
					loopforcount2=0
					while true; do
						loopforcount2=$(( $loopforcount2 + 1 ))
						if [ "$loopforcount2" -eq 16 ] ;  then
							mech 'truncate file while failing timeout, nghi dai'
							return 1
						fi
						result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${tempfilename} ${filenameinhex} 2 ${count}")
						cmd=$?

						mech "run truncate file while failing in remote ""$cmd"
						
						if [ "$cmd" -eq 0 ] ; then
							break
						else
							sleep 1
						fi
					done		
				fi	
			
			done
		fi
		mech "elapsed time (using \$SECONDS): $SECONDS seconds"
		
		count=$(( $count + 1 ))
		
		
		if [ "$end" -eq 1 ] ; then

			SECONDS=0
			loopforcount=0
			
			while true;
			do	
				loopforcount=$(( $loopforcount + 1 ))
				
				#vuot timeout
				if [ "$loopforcount" -eq 20 ] ;  then
					mech 'assign date and time timeout, nghi dai'
					return 1
				fi
								
				dateandtimeinhumanreadable=$(stat -c %y "$dir1"/"$filename")
				mech "assign date and time:""$dateandtimeinhumanreadable"
				result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "touch -d '${dateandtimeinhumanreadable}' ${tempfilename}")						
				cmd=$?
				mech "assign date and time in remote ""$cmd"
				if [ "$cmd" -eq 0 ] ; then
					#thoat vong lap while
					break
				else
					sleep 15			
				fi					
			done

			mtimeafterup=$(stat "$dir1"/"$filename" --printf='%y\n')
			if [ "$mtimeafterup" ] ; then
				mtimeafterup=$(date +'%s' -d "$mtimeafterup")
				if [ "$mtimeafterup" == "$mtimebeforeup" ] ; then
					truncateparam4=1
				else
					mech "mtime ko bang mtimebeforeup 1"
					truncateparam4=2
				fi
			else
				mech "mtime ko bang mtimebeforeup 2"
				truncateparam4=2
			fi
			
			mech "assign datetime elapsed time (using \$SECONDS): $SECONDS seconds"
		fi
		
					
		if [ "$end" -ne 0 ] ; then

			for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
			do	
				#vuot timeout
				if [ "$loopforcount" -eq 20 ] ;  then
					mech 'movement file timeout, nghi dai'
					return 1
				fi
				
				mech 'begin movement file'
				result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${tempfilename} ${filenameinhex} 4 ${truncateparam4}")
				cmd=$?
				mech "movement file in remote ""$cmd"
			
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
				mech 'Notes: original file has been changed'
				return 2
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
	local n
	local m
	
	rm "$memtemp_local"/"$temphashfilename"
	
	tempfilename=$(echo "$param2""/""$filename" | tr -d '\n' | xxd -pu -c 1000000)
	
	for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
	do		
		#vuot timeout
		if [ "$loopforcount" -eq 20 ] ;  then
			mech 'append with hash timeout, nghi dai'
			return 1
		fi
		
		result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${getmd5hash_inremote} ${tempfilename} 0")
		cmd=$?
		mech "get ""$cmd"" md5sum:""$result"
		
		if [ "$cmd" -eq 0 ] ; then
			#thoat vong lap for
			break
		else
			sleep 15			
		fi	
	done
		
	hashremotefile=$(echo "$result" | awk '{ print $1 }')
	filesize=$(stat -c %s "$param1"/"$filename")

	if [ -f "$param1"/"$filename" ] && [ "$filesize" -gt 0 ] ; then
		truncnum=$(( ( $filesize_remote / 500000000 ) + 1 ))
		mech "truncnum ""$truncnum"
		#dd if="$param1"/"$filename" of="$memtemp_local"/"$temphashfilename" bs="500MB" count="$truncnum" skip=0
		
		#if [ -f "$memtemp_local"/"$temphashfilename" ] ; then
			#truncate -s "$filesize_remote" "$memtemp_local"/"$temphashfilename"
			n=$(( $filesize_remote/1000000000 ))
			m=$(( $filesize_remote%1000000000 ))
			hashlocalfile=$("$dir_contains_uploadfiles"/md5 "$param1"/"$filename" n m)
			
			if [ "$hashlocalfile" == "$hashremotefile" ] ; then
				mech 'has same md5hash after truncate-->continue append'
				mtime=$(stat "$param1"/"$filename" --printf='%y\n')
				if [ "$mtime" ] ; then
					mtime=$(date +'%s' -d "$mtime")
					truncate -s 0 "$memtemp_local"/"$stoppedfilelist"
					printf "1\n%s\n%s\n%s\n%s\n%s" "$param1" "$param2" "$filename" "$filesize_remote" "$mtime" >> "$memtemp_local"/"$stoppedfilelist"
					append_native_file "$param1" "$param2" "$filename" "$filesize_remote" "$mtime" 0
					cmd="$?"
					if [ "$cmd" -ne 1 ] ; then
						truncate -s 0 "$memtemp_local"/"$stoppedfilelist"
					fi
					return "$cmd"
				else
					mech 'mtime changed-->can not continue append'
					return 252
				fi
			else
				mech 'no same md5hash after truncate-->copy total file'
				copy_file "$param1" "$param2" "$filename"
				cmd="$?"
				return "$cmd"
			fi
			
		#else
		#	mech 'dd command error, cothe ko thay file'
		#	return 253
		#fi
		
	else
		mech 'big error,ko thay file'
		return 254
	fi
		
}

#----------------------------------------COPY---------------------------------------------

copy_file() {
	local dir1=$1
	local dir2=$2
	local filename=$3
	local mtime
	local cmd
	
	mtime=$(stat "$dir1"/"$filename" --printf='%y\n')
	
	if [ "$mtime" ] ; then
		mtime=$(date +'%s' -d "$mtime")
		truncate -s 0 "$memtemp_local"/"$stoppedfilelist"
		printf "0\n%s\n%s\n%s\n0\n%s" "$dir1" "$dir2" "$filename" "$mtime" >> "$memtemp_local"/"$stoppedfilelist"
		append_native_file "$dir1" "$dir2" "$filename" 0 "$mtime" 0
		cmd="$?"
		if [ "$cmd" -ne 1 ] ; then
			truncate -s 0 "$memtemp_local"/"$stoppedfilelist"
		fi
		return "$cmd"
	else
		mech 'mtime changed-->can not continue copy'
		return 255
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
	
	mech "compare ""$param1"" ""$param2" 
	
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
			echo "p1/diri:""$param1""/""${dirname[$i]}"
			#echo "$param2"/"${dirname[$i]}"
			befDirHash=$(stat "$param1"/"${dirname[$i]}"  -c '%Y')"$befDirHash"
			befDirHash=$(ls -all "$param1"/"${dirname[$i]}" | wc -l)"$befDirHash"
			hashcount=$(($hashcount+1))
			hashcountmodulo=$(($hashcount%10000))
			if [ "$hashcountmodulo" -eq 0 ]; then
				befDirHash=$(echo "$befDirHash" | md5sum | awk '{ print $1 }')
			fi
			sync_dir "$param1"/"${dirname[$i]}" "$param2"/"${dirname[$i]}"
			cmd="$?"
			if [ "$cmd" -eq 1 ] ; then
				return 1
			fi
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
					mech "needappend:""${name[$count]}""-----""${size[$count]}""-----""${md5hash[$count]}""-----""${mtime[$count]}"
					apporcop[$count]=1
					count=$(($count + 1))
				elif [ "$afterslash_2" -eq 4 ] || [ "$afterslash_2" -eq 5 ] ; then
					name[$count]="$afterslash_1"
					size[$count]="$afterslash_4"
					md5hash[$count]="$afterslash_5"
					mtime[$count]="$afterslash_6"
					mtime_local[$count]="$afterslash_7"
					mech "needcopy:""${name[$count]}""-----""${size[$count]}""-----""${md5hash[$count]}""-----""${mtime[$count]}"
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
				mech "--------------------""$total"" files received valid---------------------"
			fi
		done < "$mytemp"/"$outputfile_inremote"
		
		count=0
		for i in "${!nameother[@]}"
		do
			#printf '%s status: %s\n' "${nameother[$i]}" "${statusother[$i]}" 
			count=$(($count + 1))
		done
		mech 'file ko duoc tinh------------'"$count"
		
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
					mech "->append:""mtimelc:""${mtime_local[$i]}"" mtime:""${mtime[$i]}""-""$param1"" ""$param2"" ""${name[$i]}"" ""${size[$i]}"
					append_file_with_hash_checking "$param1" "$param2" "${name[$i]}" "${size[$i]}"
					cmd="$?"
				else
					mech "->copy:""$param1"" ""$param2"" ""${name[$i]}"
					copy_file "$param1" "$param2" "${name[$i]}"
					cmd="$?"
				fi
				
				if [ "$cmd" -eq 1 ] ; then
					#try to stop sync
					return 1
				fi
			#neu ko tim thay
			else
				mech '**********************************file not found'
			fi
			count=$(($count + 1))
		done
		
		mech "--------------------""$count"" files can append hoac copy ---------------------"

	fi
}

#-------------------------------------CHECK FILE STOPPED SUDDENTLY-----------------------------------------

find_stopped_file(){
	local dir_ori="$1"
	local file="$2"
	local pathname
	local kq=1
	local bs
	local workingdir=$(pwd)
	
	for pathname in "$dir_ori"/* ; do
		if [ -f "$pathname" ] ; then 
			bs=$(basename "$pathname")
			if [ "$bs" == "$file" ] ; then
				mech "$dir_ori"
				kq=0
				break
			fi
		fi
	done
	
	return "$kq"
}

check_file_stopped_suddently(){
	local appendorcop
	local foundfile
	local foundfilesize=0
	local dir_local
	local dir_remote
	local old_mtime
	local rs
	local mtime
	local cmd
	local kq=0
	local loopforcount
	local tempfilename="/var/res/backup/.Temp/tempfile.being"
	local filenameinhex
	local filelistsize=$(stat -c %s "$memtemp_local"/"$stoppedfilelist")
	local truncsize
	
	#read file first
	if [ ! -f "$memtemp_local"/"$stoppedfilelist" ] ; then
		return 255
	fi
	
	if [ "$filelistsize" -eq 0 ] ; then
		return 0
	fi
	
	appendorcop=$(head -n 1 "$memtemp_local"/"$stoppedfilelist")
	dir_local=$(head -n 2 "$memtemp_local"/"$stoppedfilelist" | tail -n 1)
	dir_remote=$(head -n 3 "$memtemp_local"/"$stoppedfilelist" | tail -n 1)
	foundfile=$(head -n 4 "$memtemp_local"/"$stoppedfilelist" | tail -n 1)
	
	if [ "$appendorcop" -eq 1 ] ; then
		foundfilesize=$(head -n 5 "$memtemp_local"/"$stoppedfilelist" | tail -n 1)
	else
		foundfilesize=0
	fi
	
	old_mtime=$(head -n 6 "$memtemp_local"/"$stoppedfilelist" | tail -n 1)
	
	mech "$appendorcop"
	mech "$dir_local"
	mech "$dir_remote"
	mech "$foundfile"
	mech "$foundfilesize"
	mech "$old_mtime"

	filenameinhex=$(echo "$dir_remote"/"$foundfile" | tr -d '\n' | xxd -pu -c 1000000)
	
	for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
	do		
		#vuot timeout
		if [ "$loopforcount" -eq 20 ] ;  then
			mech 'check_file_stopped_suddently timeout, nghi dai'
			return 1
		fi
		
		rs=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${tempfilename} ${filenameinhex} 5")
		cmd=$?
		mech "get check_file_stopped_suddently ""$cmd"" rs: ""$rs"
		
		if [ "$cmd" -eq 0 ] ; then
			#thoat vong lap for
			break
		else
			sleep 15			
		fi	
	done
	
	truncsize="$rs"
	
	if [ "$truncsize" ] && [  "$truncsize" -gt "$foundfilesize"  ] ; then
		truncsize=$(( ($truncsize / (8*1024*1024) ) * (8*1024*1024) ))
		truncsize=$(( $truncsize - (8*1024*1024) ))
		if [ "$truncsize" -gt 0 ] ; then
			for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
			do		
				#vuot timeout
				if [ "$loopforcount" -eq 20 ] ;  then
					mech 'check_file_stopped_suddently timeout, nghi dai'
					return 1
				fi
				
				ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${tempfilename} ${filenameinhex} 6 ${truncsize}"
				cmd=$?
				mech "get check_file_stopped_suddently ""$cmd"
				
				if [ "$cmd" -eq 0 ] ; then
					#thoat vong lap for
					break
				else
					sleep 15			
				fi	
			done
		else
			truncsize=0
		fi
	else
		truncsize=0
	fi
	
	mech 'begin search:'
	find_stopped_file "$dir_local" "$foundfile"
	cmd="$?"
	if [ "$cmd" -eq 0 ] ; then
		mtime=$(stat "$dir_local"/"$foundfile" --printf='%y\n')
		
		if [ "$mtime" ] ; then
			mtime=$(date +'%s' -d "$mtime")

			mech "xu ly lai append_native_file ""$truncsize"
			append_native_file "$dir_local" "$dir_remote" "$foundfile" "$foundfilesize" "$mtime" "$truncsize"
			cmd="$?"

			if [ "$cmd" -eq 1 ] ; then
				kq=1
			fi
		fi
	fi
	
	return "$kq"
}

#-------------------------------------GET FILES FROM REMOTE-----------------------------------------

getfiles_firsttime_fromremote(){
	local dir1="$1"
	local dir2="$2"
	local interpath="$3"
	local cmd
	local loopforcount
	local result
	local pathname
	local outputfile="outputfile.txt"
	local beforeslash
	local afterslash_1
	local afterslash_2
	local afterslash_3
	local afterslash_4
	local afterslash_5
	local count
	local tempfilename="tempfile.being"
	local tempfilenameinhex
	local filesize
	local n
	local m
	local hashlocalfile
	local hashremotefile
	
	pathname=$(echo "$dir2""$interpath" | tr -d '\n' | xxd -pu -c 1000000)
	
	local temp_name
	local temp_type
	local temp_headhash
	local temp_mtime
	local temp_size
	
	declare -a name
	declare -a type
	declare -a headhash
	declare -a mtime
	declare -a size

	#mech "---------------------Thong tin thu muc ""$dir2""$interpath""--------------------------------"
	#mech "---------------------Tuong ung thu muc ""$dir1""$interpath""--------------------------------"
	for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
	do		
		#vuot timeout
		if [ "$loopforcount" -eq 20 ] ;  then
			mech 'getfiles_firsttime_fromremote timeout, nghi dai'
			return 1
		fi
		
		result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${getlistdirfiles_remote} ${pathname} ${memtemp_remote}/${outputfile}")
		cmd=$?
		mech "get getfiles_firsttime_fromremote ""$cmd"
		
		if [ "$cmd" -eq 0 ] ; then
			#thoat vong lap for
			break
		else
			sleep 15			
		fi	
	done
	
	for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
	do		
		#vuot timeout
		if [ "$loopforcount" -eq 20 ] ;  then
			mech 'getback getfiles_firsttime_fromremote timeout, nghi dai'
			return 1
		fi
		
		result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$destipv6addr_scp":"$memtemp_remote"/"$outputfile" "$memtemp_local"/"$outputfile")
		cmd=$?
		mech "scp 1 file ""$cmd"
		
		if [ "$cmd" -eq 0 ] ; then
			#thoat vong lap for
			break
		else
			sleep 15			
		fi	
	done
	
	count=0
	while IFS=/ read beforeslash afterslash_1 afterslash_2 afterslash_3 afterslash_4 afterslash_5
	do
		name[$count]="$afterslash_1"
		type[$count]="$afterslash_2"
		mtime[$count]="$afterslash_3"
		size[$count]="$afterslash_4"
		headhash[$count]="$afterslash_5"
		count=$(($count + 1))
	done < "$memtemp_local"/"$outputfile"


	#for i in "${!name[@]}" ; do
	#	mech "name:""${name[$i]}"
	#	mech "type:""${type[$i]}"
	#	mech "mtime:""${mtime[$i]}"
	#	mech "size:""${size[$i]}"
	#	mech "headhash:""${headhash[$i]}"
	#	mech "--------------------------"
	#done

	#for i in "${!name[@]}" ; do
	#	if [ "${type[$i]}" == "d" ] ; then
	#		mech "kiem tra duong dan ton tai khong"
	#		mech "tao thu muc"
	#		mech "thuc hien de quy"
	#	else
	#		mech "kiem tra duong dan ton tai khong"
	#		mech "rsyn vao bo dem"
	#		mech "kiem tra duong dan ton tai khong"
	#		mech "mv vao dung vi tri"
	#	fi
	#	mech "--------------------------"
	#done
	
	for i in "${!name[@]}" ; do
		if [ "${type[$i]}" == "d" ] ; then
			if [ ! -d "$dir1""$interpath""/""${name[$i]}" ] ; then
				if [ -d "$dir1""$interpath" ] ; then
					mkdir "$dir1""$interpath""/""${name[$i]}"
				fi
			fi
			getfiles_firsttime_fromremote "$dir1" "$dir2" "$interpath""/""${name[$i]}"
		else
			if [ ! -f "$dir1""$interpath""/""${name[$i]}" ] ; then
			
				if [ -d "$dir1""$interpath" ] ; then
					if [ -f "$memtemp_local"/"$tempfilename" ] ; then
						filesize=$(stat -c %s "$memtemp_local"/"$tempfilename")
						filesize=$(( ($filesize / (8*1024*1024) ) * (8*1024*1024) ))
						filesize=$(( $filesize - (8*1024*1024) ))
						if [ "$filesize" -lt 0 ] ; then
							filesize=0
						fi
						
						truncate -s "$filesize" "$memtemp_local"/"$tempfilename"
						n=$(( $filesize/1000000000 ))
						m=$(( $filesize%1000000000 ))
						
						if [ "$filesize" -lt 0 ] || [ "$filesize" -gt "${size[$i]}" ] ; then
							rm "$memtemp_local"/"$tempfilename"
						else
							hashlocalfile=$("$dir_contains_uploadfiles"/md5 "$memtemp_local"/"$tempfilename" "$n" "$m")
							tempfilenameinhex=$(echo "$dir2""$interpath""/""${name[$i]}" | tr -d '\n' | xxd -pu -c 1000000)
							mech "hashlocalfile ""$n"" ""$m"" ""$hashlocalfile"
							
							for (( loopforcount=0; loopforcount<21; loopforcount+=1 ));
							do		
								#vuot timeout
								if [ "$loopforcount" -eq 20 ] ;  then
									mech 'get hash remote file timeout, nghi dai'
									return 1
								fi
								
								result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${getmd5hash_inremote} ${tempfilenameinhex} 1 ${n} ${m}")
								cmd=$?
								mech "get hash remote file ""$cmd"" md5sum:""$result"
								
								if [ "$cmd" -eq 0 ] ; then
									#thoat vong lap for
									break
								else
									sleep 15			
								fi	
							done
								
							hashremotefile=$(echo "$result" | awk '{ print $1 }')
							
							
							if [ "$hashremotefile" != "$hashlocalfile" ] ; then
								rm "$memtemp_local"/"$tempfilename"
							else
								mech "hai hash bang nhau"
							fi
						fi
					fi
					
					while true
					do		
						rsync -vah --append --inplace --time-limit=20 --iconv=utf-8,utf-8 --protect-args -e "ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i ${fileprivatekey}" "$destipv6addr_scp":"$dir2""$interpath""/""${name[$i]}" "$memtemp_local"/"$tempfilename"
						cmd=$?
						mech "rsync get file firsttime ""$cmd"
						
						if [ "$cmd" -eq 0 ] ; then
							#thoat vong lap while
							break
						else
							filesize=$(stat -c %s "$memtemp_local"/"$tempfilename")
							filesize=$(( $filesize - 1048576 ))
							if [ "$filesize" -lt 0 ] ; then
								filesize=0
							fi
							truncate -s "$filesize" "$memtemp_local"/"$tempfilename"
							sleep 5			
						fi	
					done
					
					if [ ! -f "$dir1""$interpath""/""${name[$i]}" ] ; then
						mv "$memtemp_local"/"$tempfilename" "$dir1""$interpath""/""${name[$i]}"
					else
						rm "$memtemp_local"/"$tempfilename"
					fi
					
				fi
			fi
		fi
	done
}

#-------------------------------------MAIN-----------------------------------------

get_dir_hash(){
	local dir_ori="$1"
	local pathname
	
	for pathname in "$dir_ori"/* ; do
		if [ -d "$pathname" ] ; then 
			afDirHash=$(stat "$pathname" -c '%Y')"$afDirHash"
			afDirHash=$(ls -all "$pathname" | wc -l)"$afDirHash"
			hashcount=$(($hashcount+1))
			hashcountmodulo=$(($hashcount%10000))
			if [ "$hashcountmodulo" -eq 0 ]; then
				afDirHash=$(echo "$afDirHash" | md5sum | awk '{ print $1 }')
			fi
			get_dir_hash "$pathname"
		fi
	done
}

main(){
	local dir_ori="$1"
	local dir_dest="$2"
	local cmd
	local cmd1
	local cmd2
	local result
	local count
	local kq
	local chdir=0
	
	if [ ! -d "$dir_ori" ] ; then
		mech "###error2###"
		return 2
	fi
	
	if [ ! -d "$memtemp_local" ] ; then
		mkdir "$memtemp_local"
	fi
	
	if [ ! -f "$memtemp_local"/"$stoppedfilelist" ] ; then
		#mech 'create stoppedfile'
		truncate -s 0 "$memtemp_local"/"$stoppedfilelist"
		chdir=1
	fi

	truncate -s 0 "$mainlogfile"
	#truncate -s 0 "$memtemp_local"/"$errorfile"
	prt=3
	
	#add to know_hosts for firsttime
	if [ -f "$fileprivatekey" ] ; then
		cmd=255
		while [ "$cmd" -eq 255 ] ; do
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "mkdir ${memtemp_remote}" 2>&1)
			cmd=$?
			mech "mkdir temp at remote ""$cmd"
			cmd1=$(echo "$result" | grep "Permission denied")
			if [ "$cmd1" ] ; then
				mech "Wrong key, Permission denied"
				mech "###error3###"
				return 3
			fi
			cmd1=$(echo "$result" | grep "No route")
			if [ "$cmd1" ] ; then
				mech "No route to remote"
				mech "###error4###"
				return 4
			fi
			sleep 1
		done
		
		cmd=255
		while [ "$cmd" -eq 255 ] ; do
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "mkdir /var/res/backup/.Temp")
			cmd=$?
			mech "mkdir temp at SyncDir in remote ""$cmd"
			sleep 1
		done
		
		cmd=255
		while [ "$cmd" -eq 255 ] ; do
			result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "mkdir /var/res/backup/SyncDir")
			cmd=$?
			mech "mkdir SyncDir in remote ""$cmd"
			sleep 1
		done
		
		if [ -f "$dir_contains_uploadfiles"/"$truncatefile_inremote" ] ; then
			cmd=255
			while [ "$cmd" -ne 0 ] ; do
				result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$truncatefile_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
				cmd=$?
				mech "scp 1 truncatefile ""$cmd"
				sleep 1
			done
		else
			mech 'error: truncate file  not found, stop!'
			mech "###error###"
			return 1
		fi
		
		if [ -f "$dir_contains_uploadfiles"/"$compare_listfile_inremote" ] ; then
			cmd=255
			while [ "$cmd" -ne 0 ] ; do
				result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$compare_listfile_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
				cmd=$?
				mech "scp 1 comparelist file ""$cmd"
				sleep 1
			done
		else
			mech 'error: comparelist file  not found, stop!'
			mech "###error###"
			return 1
		fi
		
		if [ -f "$dir_contains_uploadfiles"/"$compare_listdir_inremote" ] ; then
			cmd=255
			while [ "$cmd" -ne 0 ] ; do
				result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$compare_listdir_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
				cmd=$?
				mech "scp 1 comparelistdir file ""$cmd"
				sleep 1
			done
		else
			mech 'error: comparelistdir file not found, stop!'
			mech "###error###"
			return 1
		fi
		
		if [ -f "$dir_contains_uploadfiles"/"$getmd5hash_inremote" ] ; then
			cmd=255
			while [ "$cmd" -ne 0 ] ; do
				result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$getmd5hash_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
				cmd=$?
				mech "scp 1 shellmd5hashfile ""$cmd"
				sleep 1
			done
		else
			mech 'error: shellmd5hashfile file not found, stop!'
			mech "###error###"
			return 1
		fi
		
		if [ -f "$dir_contains_uploadfiles"/"$md5_fileC_inremote" ] ; then
			mech 'compile md5 at local'
			gcc -Wall -Wextra -O3 -D_LARGEFILE_SOURCE=1 -D_FILE_OFFSET_BITS=64 -o "$dir_contains_uploadfiles"/"$md5file" "$dir_contains_uploadfiles"/"$md5_fileC_inremote"
			cmd=255
			while [ "$cmd" -ne 0 ] ; do
				result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$md5_fileC_inremote" "$destipv6addr_scp":"$memtemp_remote"/)
				cmd=$?
				mech "scp 1 md5_fileC_inremote ""$cmd"
				sleep 1
			done
		else
			mech 'error: md5_fileC_inremote file not found, stop!'
			mech "###error###"
			return 1
		fi
		
		if [ -f "$dir_contains_uploadfiles"/"$getlistdirfiles_remote" ] ; then
			cmd=255
			while [ "$cmd" -ne 0 ] ; do
				result=$(scp -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" -p "$dir_contains_uploadfiles"/"$getlistdirfiles_remote" "$destipv6addr_scp":"$memtemp_remote"/)
				cmd=$?
				mech "scp 1 getlistdirfiles_remote ""$cmd"
				sleep 1
			done
		else
			mech 'error: getlistdirfiles_remote file not found, stop!'
			mech "###error###"
			return 1
		fi
		
	else
		mech 'error: key not found, stop!'
		mech "###error3###"
		return 3
	fi
	
	if [ "$chdir" -eq 1 ] ; then
		getfiles_firsttime_fromremote "$dir_ori" "$dir_dest" ""
	fi
	

	while true; do
		count=0
		truncate -s 0 "$mainlogfile"
		
		if [ ! -d "$dir_ori" ] ; then
			mech "###error2###"
			return 2
		fi
		
		if [ ! -f "$fileprivatekey" ] ; then
			mech "###error3###"
			return 3
		fi
		
		result=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "ls" 2>&1)
		cmd1=$(echo "$result" | grep "Permission denied")
		if [ "$cmd1" ] ; then
			mech "Wrong key, Permission denied"
			mech "###error3###"
			return 3
		fi
			
		while [ "$count" -lt 3 ] ; do
			check_network
			cmd1=$?
			mech "check network ""$cmd1"
			
			verify_logged
			cmd2=$?
			mech "verify active user ""$cmd2"

			#check if a file is stopped suddently
			if [ "$cmd1" -eq 0 ] && [ "$cmd2" -eq 0 ] ; then
				check_file_stopped_suddently
				cmd=$?
				if [ "$cmd" -eq 0 ] ; then
					break
				elif [ "$cmd" -eq 255 ] ; then
					touch "$memtemp_local"/"$stoppedfilelist"
				else
					count=$(( $count + 1 ))
				fi
			else
				mech 'will sleep 1'
				mech "go to sleep"
				sleep "$sleeptime"
			fi
		done

		truncate -s 0 "$memtemp_local"/"$stoppedfilelist"
		
		check_network
		cmd1=$?
		mech "check network ""$cmd1"
		
		verify_logged
		cmd2=$?
		mech "verify active user ""$cmd2"
		kq=0
		
		if [ "$cmd1" -eq 0 ] && [ "$cmd2" -eq 0 ] ; then
			#mtimedir=$(stat "$dir_ori" --printf='%y\n')
			#mtimedir=$(date +'%s' -d "$mtimedir")
			mech "begin sync dir"
			befDirHash=$(stat "$dir_ori" -c '%Y')
			sync_dir "$dir_ori" "$dir_dest"
			cmd="$?"
			if [ "$cmd" -eq 1 ] ; then
				kq=1
			fi
			mech 'will sleep 2'
		else
			kq=1
			mech 'will sleep 3'
		fi
		
		#cp "$memtemp_local"/"$stoppedfilelist" "$memtemp_local"/"$errorfile"
		befDirHash=$(echo "$befDirHash" | md5sum )
		mech "$befDirHash"
		
		if [ "$kq" -eq 1 ] ; then
			mech "long sleep"
			sleep "$sleeptime"
		else
			mech "###ok###"
			
			while true; do
				if [ -d "$dir_ori" ] ; then
					afDirHash=$(stat "$dir_ori" -c '%Y')
					get_dir_hash "$dir_ori"
				fi
				#mech "$afDirHash"
				afDirHash=$(echo "$afDirHash" | md5sum )
				if [ "$befDirHash" == "$afDirHash" ] ; then
					sleep 20
				else
					break
				fi
			done
		fi
	done
}



main "$1" "/var/res/backup/SyncDir"


#main "/home/dungnt/MySyncDir" "/var/res/backup/SyncDir"
#main "/home/dungnt/ShellScript/MySyncDir/Setup" "/var/res/backup/SyncDir/Setup"

#getfiles_firsttime_fromremote "/home/dungnt/MySyncDir" "/var/res/backup/SyncDir" ""

#mt=$(stat "/home/dungnt/ShellScript/MySyncDir/Setup"/"debian-10.10.0-amd64-netinst.iso" -c '%Y')
#find_list_same_files "/home/dungnt/ShellScript/tối quá" "/home/backup/biết sosanh"
#find_list_same_dirs "/home/dungnt/ShellScript/tối quá2" "/home/backup/so sánh thư mục"
#sync_dir "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục"
#copy_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "file tét.txt"
#append_native_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "file tét.txt" 20000000 "$mainhash"
#copy_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "noi"
#append_native_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "noi" 1 "$mainhash"
#copy_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "file $\`\" 500mb.txt"
#append_native_file "/home/dungnt/ShellScript/tối quá" "/home/backup/so sánh thư mục" "file $\`\" 500mb.txt" 200000000 "$mtime"
#copy_file /home/dungnt/ShellScript /home/backup ubuntu-20.04.2.0-desktop-amd64.iso
#append_native_file /home/dungnt/ShellScript /home/backup ubuntu-20.04.2.0-desktop-amd64.iso 500000000 "$mt"
#filenameinhextest=$(echo "/home/backup/so sánh thư mục"/"file $\`\" 500mb.txt" | tr -d '\n' | xxd -pu -c 1000000)
#ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "bash ${memtemp_remote}/${truncatefile_inremote} ${memtemp_remote}/tempfile.being ${filenameinhextest} 3 2 200000000"
#append_native_file /home/dungnt/ShellScript/MySyncDir/Setup /var/res/backup/SyncDir/Setup debian-10.10.0-amd64-netinst.iso 352 "$mt" 33554432
