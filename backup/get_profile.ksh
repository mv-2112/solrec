#!/bin/ksh

# get_profile.ksh
# No rights reserved, Caveat Emptor, tough if it doesn't work for you

# Written by Matt F-V for personal use and by employer.

# This script attempts to rebuild enough of a JET profile for you
# to rebuild a solaris server from a FLAR without using too much brain
# power which will be in short simply when you're in a panic recovery!
# 
# Set this to run on your systems semi regularly and stow the output 
# away for a rainy day. You will need to uncomment the correct line
# for ClientEther and tweak the ClientOS field.
#
# Once those are done, add in the NFS/FTP path to the FLAR.
#
# Merge the output using the rebuild_profile.ksh script to generate
# a default template and merge in the collected data.

function outputconfigline {
	echo "$1=\"$2\""
}

function zfsConfig {
	echo "# - INFO: Getting ZFS setup..."
	rpool=$(df -k / | tail -1 | cut -d/ -f 1)
	for each in $(zdb -C $rpool | grep ' path=' | cut -d= -f2 | tr -d "'")
		do
			disks="$disks $(basename $each)"
		done
	numdisks=$(echo $disks | wc -w | tr -d ' ')
	
	case $numdisks in
		1 | 2)
			outputconfigline base_config_label_disks "$disks"
			outputconfigline base_config_profile_zfs_disk "$disks"
			outputconfigline base_config_profile_zfs_pool $rpool
			
			if [[ $(df -k /var | tail -1 | awk '{print $6}') = "/var" ]];then
				sepVar="true"
			else
				sepVar="false"
			fi
			
			swapSize=$(zfs get volsize rpool/swap | tail -1 | awk '{ print $3 }' | tr -d "G \n")
			dumpSize=$(zfs get volsize rpool/dump | tail -1 | awk '{ print $3 }' | tr -d "G \n")

			swapSize=$(echo $swapSize | awk '{ printf "%.0f", $1*1024 }')
			dumpSize=$(echo $dumpSize | awk '{ printf "%.0f", $1*1024 }')

			outputconfigline base_config_profile_zfs_dump $dumpSize
			outputconfigline base_config_profile_zfs_swap $swapSize
			outputconfigline base_config_profile_zfs_var $sepVar
			;;
		* )
			echo "# - WARNING: This ZFS root appears too complicated. You're on your own with this one"
			;;
	esac

	disk=$(echo $disks | cut -d" " -f1)
	outputconfigline base_config_profile_usedisk $disk
}

function ufsConfig {
	echo "# - INFO: Getting UFS setup..."
	rootDevice=$(df -h / | tail -1 | cut -d/ -f3)
	case $rootDevice in
		md )
			svmrootConfig
			;;
		vx )
			vxrootConfig
			;;
		dsk )
			ctdrootConfig
			;;
	esac
}

function vxrootConfig {
	echo "# - WARNING: You appear to have a Veritas Enscapsulated Root setup. Not handled at this time."
}

function ctdrootConfig {
	
	echo "# - INFO: deriving sliced setup for ctd/ufs..."
	
	# We don't support raidctl at this time...
	if [[ $(raidctl -l | grep Volume | wc -l) -gt 1 ]];then
		echo "# - WARNING: raidctl is detected to be in use, please ensure you confirm raidctl setup and check device names"
	fi

	disk=$(basename $(df -k / | tail -1 | cut -d" " -f1))
	disk6chars=$(echo $disk | cut -c1-6)
	blkSize=$(devinfo -i /dev/rdsk/$disk | awk '{ print $5 }')

	for each in $(prtvtoc -h /dev/rdsk/$disk | tr -s " " ":" | sed 's/^://g')
		do
			slice=$(echo $each | cut -d":" -f1)
			mountpoint=$(echo $each | cut -d":" -f7)
			length=$(echo $each | cut -d":" -f5)
			
			if [[ $mountpoint = "/" && slice -ne 0 ]];then
				echo "# - WARNING: your root slice is not slice0!!"
			fi
			
			if [[ $slice -eq 2 && $mountpoint != "" ]];then
				echo "# - WARNING: mountpoint found on slice2 - illegal config!"
			fi
			
			if [[ $slice -eq 1 && $mountpoint != "" ]];then
				echo "# - WARNING: slice1 is not being used for swap!"
			fi
			
			if [[ $slice -eq 1 ]];then
				disk6chars=$(echo $disk | cut -c1-6)
				if [[ $(swap -l | grep $disk6chars | wc -l) -gt 2 ]];then
				echo "# - INFO: Multiple swap devices found on rootdisk, combining"
				fi
				swapSize=$( swap -l | grep $disk6chars | tr -s " " | cut -d" " -f1,4 | cut -d/ -f4 | awk '{ sum+=$2} END {print sum}')
				swapSize=$(echo $swapSize $blkSize | awk '{ printf "%.0f", $1/(1024/$2)/1024 }')
				outputconfigline base_config_profile_swap $swapSize
			fi
		
			if [[ $slice -eq 0 ]];then
				case $mountpoint in
					/)
						outputconfigline base_config_profile_root $(echo $length $blkSize | awk '{ printf "%.0f", $1/(1024/$2)/1024 }')
						;;
					*)
						echo "# - WARNING: slice 0 is not root - cannot setup root fs size"
						;;
				esac
			fi
			
			if [[ $mountpoint = "/"  && $slice -ne 0 ]];then
				echo "# - WARNING: slice $slice contains a / mountpoint!"
				outputconfigline base_config_profile_root $(echo $length $blkSize | awk '{ printf "%.0f", $1/(1024/$2)/1024 }')
			fi
			
			if [[ $slice -ge 3 && $slice -le 7 ]];then
				outputconfigline base_config_profile_s${slice}_mtpt $mountpoint
				outputconfigline base_config_profile_s${slice}_size $(echo $length $blkSize | awk '{ printf "%.0f", $1/(1024/$2)/1024 }')
			fi
			
			if [[ $slice -gt 7 ]];then
				echo "# - WARNING: slices greater then 7 are not configurable via JET"
			fi
		done


	outputconfigline base_config_profile_usedisk $disk6chars
	outputconfigline base_config_label_disks "$disk6chars"
}



function svmrootConfig {
	# This function derives the sds flags and related base config
	
	echo "# - INFO: Found SVM/SDS metadevices..."
	JETproducts="$JETproducts sds"
	
	echo "# - Assume Solaris 9 or 10 - on your own if on anything earlier"
	outputconfigline sds_product_version default
	rootMetadev=$(df -h / | tail -1 | cut -d/ -f5 | cut -d" " -f1)
	disks=$(metastat -p $rootMetadev | tail +2 | cut -d" " -f4 | cut -c 1-6 | tr -s '\n' ' ')
	numdisks=$(echo $disks | wc -w | tr -d ' ')

	outputconfigline base_config_profile_usedisk "$disks"
	outputconfigline base_config_label_disks "$disks"
	
	if [[ $numdisks -eq 2 ]];then
		echo "# - Setup looks to be a simple mirror"
		outputconfigline sds_simple_mirrors $(echo $disks | sed "s/^ //g;s/ /=/g")
		outputconfigline sds_root_mirror $(echo $disks | awk '{ print $2 }')
		outputconfigline sds_root_alias rootdisk
		outputconfigline sds_root_mirror_devalias_name rootmirror
		outputconfigline sds_use_fmthard yes
		outputconfigline sds_md_tabfiles md.tab
	fi
	
	if [[ $numdisks -eq 1 ]];then
		echo "# - single disk SVM?"
	fi
	
	if [[ $numdisks -gt 2 ]];then
		echo "# - Complex SVM mirror setup detected you're on your own here really"
	fi
	
	metaDBNum=$(metadb -i | grep '/dev/' | sed 's%.*/dev/dsk/%%g'| uniq -c | awk '{ print $1 }' | uniq)
	metaDBSlice=$(metadb -i | grep '/dev/' | sed 's%.*/dev/dsk/%%g'| uniq -c | awk '{ print $2}' | cut -c7-8 | uniq)
	
	#Get metadb slice
	for each in $(echo $disks)
		do
			metaDBSliceSize=$(prtvtoc -h /dev/rdsk/${each}s2 | tr -s " " | grep '^ 7 ' | awk '{ printf "%.0f", $5/(1024/512)/1024 }')
		done
	
	disk=$(echo $disks | cut -d" " -f1)
	disk6chars=$disk
	blkSize=$(devinfo -i /dev/rdsk/${disk}s2 | awk '{ print $5 }')
	
	outputconfigline base_config_profile_usedisk $disk6chars
	outputconfigline base_config_label_disks "$disks"
	
	
	for each in $disks
		do
				metaDBlocs="$metaDBlocs ${each}$metaDBSlice:$metaDBNum"
		done
	
	outputconfigline sds_database_locations "$metaDBlocs"
	
	outputconfigline sds_database_partition "$metaDBSlice:$metaDBSliceSize"
	
	for eachMetaDev in $(df -k | grep md | awk '{ print $1":"$6 }')
			do
				mountpoint=$(echo $eachMetaDev | cut -d: -f2)
				md=$(echo $eachMetaDev | cut -d: -f1)
				slice=$(metastat -p $md | tail -1 | cut -ds -f2)
				size=$(prtvtoc -h $md | tr -s " " ":" | cut -d: -f6 | awk '{ printf "%.0f", $1/(1024/512)/1024 }')
				
				if [[ $mountpoint = "/" && slice -ne 0 ]];then
					echo "# - WARNING: your root slice is not slice0!!"
				elif [[ $slice -eq 0 ]];then
					outputconfigline base_config_profile_root $size
				fi
				
				if [[ $slice -eq 2 && $mountpoint != "" ]];then
					echo "# - WARNING: mountpoint found on slice2 - illegal config!"
				fi
				
				if [[ $slice -ge 3 && $slice -le 7 ]];then
					outputconfigline base_config_profile_s${slice}_mtpt $mountpoint
					outputconfigline base_config_profile_s${slice}_size $size
				fi
				
				if [[ $slice -gt 7 ]];then
					echo "# - WARNING: slices greater then 7 are not configurable via JET"
				fi 
			done	

	swapDev=$(grep "^/.*swap" /etc/vfstab | awk '{ print $1 }')
	swapSlice=$(metastat -p $swapDev | tail -1 | cut -ds -f2)
	if [[ $swapSlice -ne 1 ]]; then
		echo "# - WARNING: slice1 is not being used for swap!"
	fi
        swapSize=$(prtvtoc -h $swapDev | tr -s " " ":" | cut -d: -f6 | awk '{ printf "%.0f", $1/(1024/512)/1024 }')
	if [[ $(swap -l | grep $disk6chars | wc -l) -gt 2 ]];then
                echo "# - INFO: Multiple swap devices found on rootdisk - cannot combine SVM swap"
        fi
	outputconfigline base_config_profile_swap $swapSize
}

function sys {
	# This function retrieves basic system config

	arch=$(arch -k)
	outputconfigline base_config_ClientArch $arch

	echo "# You may wish to override the client allocation... top is preferred for your arch."
	if [[ $arch = "i86pc" ]]; then
		outputconfigline '#base_config_client_allocation' "dhcp"
		outputconfigline '#base_config_client_allocation' "bootp"
	else
		outputconfigline '#base_config_client_allocation' "bootp"
		outputconfigline '#base_config_client_allocation' "dhcp"
	fi
	
	
	echo "# - Chances are this isn't going to be spot on... edit or cheat and use Latest."
	outputconfigline '#base_config_ClientOS' "$(echo $(head -1 /etc/release))"
	outputconfigline '#base_config_ClientOS' "Solaris_Latest" 
	
	outputconfigline base_config_sysidcfg_system_locale $(locale | grep CTYPE | cut -d= -f2)
	outputconfigline base_config_sysidcfg_system_timezone $(egrep "TZ+=" /etc/default/init | cut -d= -f2)
	outputconfigline base_config_sysidcfg_root_password $(grep ^root: /etc/shadow | cut -d: -f2)
	
	echo "# - Working out nameservice type. By default we make life easy and set to none"
	typeset -u ns
	ns=$(cat /etc/nsswitch.conf | grep ^hosts: | cut -d: -f2 | sed "s/.*files//" | tr -d " ")
	outputconfigline base_config_sysidcfg_nameservice "NONE"
	outputconfigline 'base_config_dns_disableforbuild' "yes"
	outputconfigline '#base_config_sysidcfg_nameservice' $ns
	outputconfigline '#base_config_dns_nameservers' ""
	outputconfigline '#base_config_dns_domain' ""
	outputconfigline '#base_config_dns_searchpath' ""
	
	echo "# If more than one line appears below you need to 'guess' the correct one."
	echo "# Its normally the one on the same subnet as your Jumpstart server."
	
for each_interface in $(ifconfig -a | grep ": " | cut -d: -f1 | sort -u | grep -v ^lo0)
	do
	 MAC=$(ifconfig $each_interface | grep ether | awk '{ print $2 }')
	 IP=$(ifconfig $each_interface | grep inet | awk '{ print $2 }')
	 NMH=$(ifconfig $each_interface | grep inet | awk '{ print $4 }')
	 # Split NMH
	 nm1d=$(printf "%d\n" 0x$(echo $NMH | cut -c1-2))
	 nm2d=$(printf "%d\n" 0x$(echo $NMH | cut -c3-4))
	 nm3d=$(printf "%d\n" 0x$(echo $NMH | cut -c5-6))
	 nm4d=$(printf "%d\n" 0x$(echo $NMH | cut -c7-8))
	 netmask="$nm1d.$nm2d.$nm3d.$nm4d"
	 echo "# For interface $each_interface use the below"
	 outputconfigline '#base_config_ClientEther' "$MAC"
	 outputconfigline '#base_config_sysidcfg_netmask' "$netmask"
	 outputconfigline '#base_config_sysidcfg_ip_address' "$IP"
	done
	
	outputconfigline base_config_nodename $(cat /etc/nodename)
}

function remnants {
	# Trawl through the innards and see whats laying around
	if [[ -f /etc/sysidcfg ]];then
		echo "# - INFO: Found an old sysidcfg"
		while read line
			do
				if [[ $(echo $line | cut -c 1-18) = "network_interface=" ]];then
					newline=$(echo $line | tr -d "{}")
					for each in $newline
						do
							echo base_config_sysidcfg_$each
						done
				else
					echo base_config_sysidcfg_$line
				fi
			done </etc/sysidcfg
	fi	
}

function disk_cfg {
	# Do the best job you can of figuring out the disk config
	if [[ $(df -k / | tail +2 | cut -c1) = '/' ]];then
		ufsConfig
	else
		zfsConfig
	fi
}

function pkgs {
	if [[ -f "/var/sadm/system/admin/CLUSTER" ]];then
		cluster=$(cut -d= -f2 /var/sadm/system/admin/CLUSTER)
	else
		cluster="SUNWCreq"
		pkgs_installed=$(pkginfo | awk '{ print $2 }' | tr -s "\n" " ")
		outputconfigline base_config_profile_add_packages "$pkgs_installed"
	fi
	outputconfigline base_config_profile_cluster $cluster
}

function flasharchive {
	JETproducts="$JETproducts flash"
	outputconfigline flash_archive_locations 'nfs://<yourJSserver>/path/to/flar'
	outputconfigline flash_skip_recommended_patches yes
}

function JETproducts {
	outputconfigline base_config_products "$JETproducts"
}

# Main execution starts here.

# Get remnants first incase we don't find something later
remnants

# Now get current stuff
sys
disk_cfg
pkgs
flasharchive
JETproducts
