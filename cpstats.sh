#!/usr/bin/env bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##
export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

cache_file="/var/cpanel/.cpstats.cache"
cache_timeout=21600
utime_1dago=`date +'%s' -d "1 days ago"`
utime_7dago=`date +'%s' -d "7 days ago"`
utime_30dago=`date +'%s' -d "30 days ago"`
utime_current=`date +'%s'`

getbw_uncached() {
	for user in `egrep home /etc/passwd | awk -F':' '{print$1}'`; do
		sqlfile="/var/cpanel/bandwidth/${user}.sqlite"
		if [ -f "$sqlfile" ]; then
			bwbytes_day=`echo "SELECT unixtime,bytes FROM bandwidth_daily WHERE unixtime >= $utime_1dago AND unixtime <= $utime_current ORDER BY unixtime;" | sqlite3 $sqlfile | cut -d'|' -f2 | paste -sd+ | bc`
			bwbytes_week=`echo "SELECT unixtime,bytes FROM bandwidth_daily WHERE unixtime >= $utime_7dago AND unixtime <= $utime_current ORDER BY unixtime;" | sqlite3 $sqlfile | cut -d'|' -f2 | paste -sd+ | bc`
			bwbytes_month=`echo "SELECT unixtime,bytes FROM bandwidth_daily WHERE unixtime >= $utime_30dago AND unixtime <= $utime_current ORDER BY unixtime;" | sqlite3 $sqlfile | cut -d'|' -f2 | paste -sd+ | bc`
			test -z $bwbytes_day && bwbytes_day=0
			test -z $bwbytes_week && bwbytes_week=0
			test -z $bwbytes_month && bwbytes_month=0
			echo "$user day $bwbytes_day week $bwbytes_week month $bwbytes_month"
		else
			echo "$user day 0 week 0 month 0"
		fi
	done >  ${cache_file}.bandwidth.$$
	mv -f ${cache_file}.bandwidth.$$ ${cache_file}.bandwidth
	cat ${cache_file}.bandwidth
}

bandwidth() {
	if [ -f "/var/cpanel/users/$1" ]; then
		user=$1
		sqlfile="/var/cpanel/bandwidth/${user}.sqlite"
		if [ -f "$sqlfile" ]; then
			bwbytes_day=`echo "SELECT unixtime,bytes FROM bandwidth_daily WHERE unixtime >= $utime_1dago AND unixtime <= $utime_current ORDER BY unixtime;" | sqlite3 $sqlfile | cut -d'|' -f2 | paste -sd+ | bc`
			bwbytes_week=`echo "SELECT unixtime,bytes FROM bandwidth_daily WHERE unixtime >= $utime_7dago AND unixtime <= $utime_current ORDER BY unixtime;" | sqlite3 $sqlfile | cut -d'|' -f2 | paste -sd+ | bc`
			bwbytes_month=`echo "SELECT unixtime,bytes FROM bandwidth_daily WHERE unixtime >= $utime_30dago AND unixtime <= $utime_current ORDER BY unixtime;" | sqlite3 $sqlfile | cut -d'|' -f2 | paste -sd+ | bc`
			test -z $bwbytes_day && bwbytes_day=0
			test -z $bwbytes_week && bwbytes_week=0
			test -z $bwbytes_month && bwbytes_month=0
			echo "$user day $bwbytes_day week $bwbytes_week month $bwbytes_month"
		else
			echo "$user day 0 week 0 month 0"
		fi
	else
		if [ -f "${cache_file}.bandwidth" ]; then
			csize=`stat -c '%s' ${cache_file}.bandwidth`
			ctime=`stat -c '%Z' ${cache_file}.bandwidth`
			cdiff=$[utime_current-ctime]
			if [ "$csize" == "0" ] || [ "$cdiff" -ge "$cache_timeout" ]; then
				getbw_uncached
			else
				cat ${cache_file}.bandwidth
			fi
		else
			getbw_uncached
		fi
	fi
}

diskspace() {
	ishomemnt=`egrep home /etc/fstab`
	if [ "$ishomemnt" ]; then
		repargs="/home"
	else
		repargs="-a"
	fi
	if [ -f "/var/cpanel/users/$1" ]; then
		user=$1
		/usr/sbin/repquota $repargs | sed 's/none //' | grep -w "$user" | awk -vuser=$user '{print user " space",$3,"inode",$6}'
	else
		tmpf="/tmp/.repquota.$$"
		/usr/sbin/repquota $repargs > $tmpf
		for user in `cat /etc/passwd | grep home | awk -F':' '{print$1}'`; do
			if [ -f "/var/cpanel/users/$user" ]; then
				cat $tmpf | sed 's/none //' | grep -w "$user" | awk -vuser=$user '{print user " space",$3,"inode",$6}'
			fi
		done
		rm -f $tmpf
	fi
}

mysqlspace() {
	if [ -f "/var/cpanel/users/$1" ]; then
		user=$1
		find=`which find 2> /dev/null`
		nice -n 19 $find /var/lib/mysql/${user}_* -maxdepth 1 -type d | egrep -v "^/var/lib/mysql$|eximstats|modsec|logaholic" | nice -n 19 xargs du -sk | sed 's_/var/lib/mysql/__' | sort -k1 -n | tac
	else
		if [ -f "${cache_file}.mysqlspace" ]; then
			csize=`stat -c '%s' ${cache_file}.mysqlspace`
			ctime=`stat -c '%Z' ${cache_file}.mysqlspace`
			cdiff=$[utime_current-ctime]
			if [ "$csize" == "0" ] || [ "$cdiff" -ge "$cache_timeout" ]; then
				find=`which find 2> /dev/null`
				nice -n 19 $find /var/lib/mysql/ -maxdepth 1 -type d | sed '/^\/var\/lib\/mysql\/$/d' | egrep -v "eximstats|modsec|logaholic" | nice -n 19 xargs du -sk | awk '$1>=51200' | sed 's_/var/lib/mysql/__' | sort -k1 -n | awk '{print$1,$2}' | tac > ${cache_file}.mysqlspace
				cat ${cache_file}.mysqlspace
			else
				cat ${cache_file}.mysqlspace
			fi
		else
			find=`which find 2> /dev/null`
			nice -n 19 $find /var/lib/mysql/ -maxdepth 1 -type d | sed '/^\/var\/lib\/mysql\/$/d' | egrep -v "eximstats|modsec|logaholic" | nice -n 19 xargs du -sk | awk '$1>=51200' | sed 's_/var/lib/mysql/__' | sort -k1 -n | awk '{print$1,$2}' | tac > ${cache_file}.mysqlspace
			cat ${cache_file}.mysqlspace
		fi
	fi
}

case $1 in
	bandwidth)
		bandwidth $2
	;;
	diskspace)
		diskspace $2
	;;
	mysqlspace)
		mysqlspace $2
	;;
	*)
		echo "usage $0: [bandwidth|diskspace|mysqlspace]"
esac
exit 0

