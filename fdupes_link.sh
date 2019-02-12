#!/bin/bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##

fd=`which fdupes`
if [ ! -f "$fd" ]; then
	echo "error: fdupes not found, aborting!"
	exit 1
fi


if [[ "$@" =~ "--force" ]]; then
	force=1
fi

if [ "$1" ]; then
	users=$1
else
	users=`cat /etc/passwd | awk -F':' '$3>=500' | cut -d':' -f1`
fi

eout() {
        string="$1"
        log_maxlines="1000000"
	fdupes_log="/var/log/fdupes.log"
	app="fdupes"
	host=`hostname -s`
        if [ -f "$fdupes_log" ]; then
                log_lines=`wc -l $fdupes_log | awk '{print$1}'`
                if [ "$log_lines" -ge "$log_maxlines" 2> /dev/null ]; then
                        trim=$[log_maxlines/10]
                        printf "%s\n" "$trim,${log_lines}d" w | ed -s $fdupes_log
                fi
        else
                touch $fdupes_log
                chmod 640 $fdupes_log
        fi
        echo "$(date +"%Y-%m-%d %H:%M:%S%z") $host $app[$$]: $string" >> $fdupes_log
	if [ "$2" ]; then
		echo "$app[$$]: $string"
	fi

}

fdout="/tmp/.fd$$"
saved_total=0 ; links_total=0
for user in `echo $users`; do
        homedir=`egrep ^HOMEDIRPATHS /var/cpanel/users/$user | cut -d'=' -f2`
        if [ -z "$homedir" ]; then
                homedir="$(egrep ^HOMEDIR /etc/wwwacct.conf | awk '{print$2}')/$user"
        fi

	if [ -d "$homedir/public_html" ]; then
		cnt=0 ; cntlinks=0 ; size_saved=0
		eout "[$user] searching for duplicate files under $homedir/public_html" 1
		timeout 900 nice -n 19 $fd -1 -qpnr $homedir/public_html/ | tr ' ' ',' > $fdout
		for i in `cat $fdout`; do
			files=`echo $i | tr ',' ' '`
			for file in `echo $files`; do
				if [ -L "$file" ] || [ ! -f "$file" ] || [ ! -f "$file" ]; then
					skip=1
				fi
				if [ ! "$skip" ]; then
					sinfo=`stat -c '%s %i' $file`
					fsize=`echo $sinfo | awk '{print$1}'`
					finode=`echo $sinfo | awk '{print$2}'`
					if [ ! "$fsize" == "0" ] && [ ! "$finode" == "$orig_inode" ]; then
						((cnt++))
						if [ "$cnt" -eq "1" ]; then
							orig_file="$file"
							orig_inode="$finode"
						elif [ "$cnt" -gt "1" ]; then
							size_saved=$[fsize+size_saved]
							((cntlinks++))
							if [ "$force" ]; then
								ln -f $orig_file $file
								eout "[$user] linked $orig_file to $file"
							fi
						fi
					fi
				fi
			done
			unset orig_file skip
			cnt=0
		done
		size_saved=$[size_saved/1024]
		if [ -z "$force" ]; then
			eout "[$user] found $cntlinks duplicate files that can be hardlinked to save $(echo $size_saved | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')kB of disk space; use --force to apply changes" 1
		else
			eout "[$user] hard linked $cntlinks duplicate files and saved $(echo $size_saved | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')kB of disk space" 1
		fi
		saved_total=$[size_saved+saved_total]
		links_total=$[cntlinks+links_total]
		((usercnt++))
		rm -f $fdout
	fi
done

if [ "$usercnt" -gt 2> /dev/null "1" ]; then
	eout "users: $usercnt files-linked: $links_total space-saved: $(echo $saved_total | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')kB" 1
fi
rm -f $fdout
