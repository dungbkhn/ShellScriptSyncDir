#!/bin/bash

shopt -s dotglob
shopt -s nullglob

appdir_local=/home/dungnt/ShellScript/sshsyncapp
memtemp_local="$appdir_local"/.temp
stoppedfilelist=stoppedfilelist.txt
destipv6addr="backup@192.168.1.158"
fileprivatekey=/home/dungnt/.ssh/id_ed25519_privatekey


if [ "$1" -eq 0 ] ; then
	password="$2"
	newpassword="$3"
	rs=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "echo -e '${password}\n${newpassword}\n${newpassword}' | passwd 2>&1 > /dev/null" 2>&1)
	echo "$rs"
elif [ "$1" -eq 1 ] ; then
	rs=$(ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -i "$fileprivatekey" "$destipv6addr" "lsblk")

	if [ "$?" -ne 0 ] ; then
		echo "Error while get info from remote machine"
		exit 0
	fi

	mystr=""
	#echo $?
	share=$(echo "$rs" | grep "/var/res/share" | awk '{ print $4 }')
	backup=$(echo "$rs" | grep "/var/res/backup" | awk '{ print $4 }')
	lastchar=$(echo "${share: -1}")
	lastcharbackup=$(echo "${backup: -1}")
	fail=0

	if [ "$lastchar" == "G" ] && [ "$share" ] ; then
		share=${share::-1}
		#echo "$share"
		# Set comma as delimiter
		IFS='.'

		#Read the split words into an array based on comma delimiter
		read -a strarr <<< "$share"

		share="${strarr[0]}"

		totalshare="$share"
		share=$(( $share - 16 ))
		
		if [ "$share" -gt 0 ] ; then
			mystr="Share Folder Size (Total): ""$totalshare""G"
			mystr="$mystr""
Share Folder Size (Avaiable): ""$share""G"
			mystr="$mystr""
Max File Size Support: ""$share""G"
			mystr="$mystr""
--------------------------"
		else
			fail=$(( $fail + 1 ))
		fi
	else
		fail=$(( $fail + 1 ))
	fi

	if [ "$lastcharbackup" == "G" ] && [ "$backup" ] ; then
		backup=${backup::-1}
		#echo "$share"
		# Set comma as delimiter
		IFS='.'

		#Read the split words into an array based on comma delimiter
		unset strarr
		read -a strarr <<< "$backup"

		backup="${strarr[0]}"

		totalbackup="$backup"
		backup=$(( $backup - 16 ))
		
		if [ "$backup" -gt 0 ] ; then
			mystr="$mystr""
Backup Folder Size (Total): ""$totalbackup""G"
			mystr="$mystr""
Backup Folder Size (Avaiable): ""$backup""G"
			mystr="$mystr""
Max File Size Support: 16G"
			mystr="$mystr""
--------------------------"
		else
			fail=$(( $fail + 100 ))
		fi
	else
		fail=$(( $fail + 100 ))
	fi

	if [ "$fail" -eq 0 ] ; then
		echo "$mystr"
	else
		echo "Error while get info from remote machine"
	fi
else
	newdir="$2"
	if [ -d "$newdir" ] ; then
		childindir=$(ls -A "$newdir" | wc -l)
		if [ "$childindir" -eq 0 ] ; then
			rm "$memtemp_local"/"$stoppedfilelist"
			echo "Ok..."
		else
			echo "Error, selected dir is not empty"
		fi
	else
		echo "Error, selected dir is not found"
	fi
fi

