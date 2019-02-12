#!/usr/bin/env bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##
export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
source="https://raw.githubusercontent.com/rfxn/TimThumb/master/timthumb.php"
log_file="/var/log/update_timthumb"

eout() {
        msg="$1"
        opt="$2"
	proj="update_timethumb"
        if [ "$opt" ]; then
                echo "$(date +"%b %e %H:%M:%S") $(hostname -s) $proj[$$]: $msg" >> $log_file
                echo "$(date +"%b %e %H:%M:%S") $(hostname -s) $proj[$$]: $msg"
        else
                echo "$(date +"%b %e %H:%M:%S") $(hostname -s) $proj[$$]: $msg" >> $log_file
        fi
}


latest=`/usr/bin/wget -qO- $source | grep "define ('VERSION'" $file |cut -f4 -d"'"`
retval=$?
if [ -z "$latest" ] && [ ! "$retval" == "0" ]; then
	eout "could not get latest timthumb release from '$source'." 1
	exit 1
fi

if [ "$1" == "--force" ]; then
	update=1
	rnd=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head --bytes $(echo $RANDOM | cut -c1-2)`
	tt_tmp="/var/tmp/$rnd"
        /usr/bin/wget -nv -t3 $source -O "$tt_tmp" && retval=$?
	if [ ! "$retval" == "0" ]; then
		eout "could not download timethumb release from '$source'." 1
		exit 1
	fi
else
	unset update
fi

for user in `awk -F':' '{ if ($3 >= 500) print $0 }' /etc/passwd | egrep home | cut -d':' -f1`; do
	IFS=$(echo -en "\n\b")
	for file in `nice -n 19 find /home*/$user/public_html/ -maxdepth 8 -type f \( -name 'thumb.php' -o -name 'timthumb.php' \) 2>/dev/null`; do
		# validate the file is in fact timthumb
		check=`egrep "code.google.com/p/timthumb" "$file"`
		if [ -z "$check" ]; then
			break
		fi
		if [ "$check" ]; then
			version=`grep "define ('VERSION'" "$file" | cut -f4 -d"'" | egrep '^[0-9]'`
			if [ "$version" ] && [ "$version" != "$latest" ] && [ "$update" == "1" ]; then
				eout "OUTDATED: found timthumb $version < $latest at '$file'" 1
				file_owner=`$stat -c '%U' "$file"`
				file_group=`$stat -c '%G' "$file"`
				file_mode=`$stat -c '%a' "$file"`
				if [ "$file_owner" ] && [ "$file_group" ] && [ "$file_mode" ]; then
					cp -f $tt_tmp "$file"
					chown ${file_owner}.${file_group} "$file"
					chmod $file_mod "$file"
					eout "OK: updated timthumb $version to $latest at '$file'" 1
				else
					eout "FAILED: unable to update timthumb $version to $latest at '$file' (undef file_owner, file_group or file_mode)" 1
				fi
			elif [ "$version" ] && [ "$version" != "$latest" ] && [ -z "$update" ]; then
				eout "OUTDATED: found timthumb $version < $latest at '$file'" 1
			else
				if [ -z "$version" ]; then
					eout "OK: evaluated but discarded as not timthumb at '$file'" 1
				else
					eout "OK: found timthumb $version = $latest at '$file'" 1
				fi
			fi
		fi
		unset version file_owner file_group file_mode
	done
done
