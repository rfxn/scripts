#!/usr/bin/env bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##
export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# minimum etime between apache restarts (hh:mm:ss)
apache_min_etime="5:00"

# files to hash for changes
files="/usr/local/apache/conf/httpd.conf /etc/localdomains"

# lock file timeout in seconds
lock_timeout="300"

# temporary md5 validation file
md5_file="/root/.cpusercheck.md5"

# unix time for lock tracking
current_utime=`date +"%s"`

# lock file path
lock_file="/root/.cpusercheck.lock"

# lock routine to prevent toe-stepping from multiple instances
if [ -f "$lock_file" ]; then
        old_locktime=`cat $lock_file`
        diff_locktime=$[current_utime-old_locktime]
        if [ "$diff_locktime" -ge "$lock_timeout" ]; then
             echo "$current_utime" > $lock_file
	     msg="cleared stale lock file at $lock_file (>${lock_timeout}s)."
             echo "$msg" && logger -t info -t "cpusercheck[$$]" "$msg"
        else
	     msg="locked subsystem, already running? ($lock_file is $diff_locktime seconds old)."
             echo "$msg" && logger -t info -t "cpusercheck[$$]" "$msg"
             exit 1
        fi
else
        echo "$current_utime" > $lock_file
fi


# check if httpdconf is broken
/etc/init.d/httpd -t 2> /dev/null &&  RETVAL=$?
if [ "$RETVAL" != "0" ]; then
	/scripts/rebuildhttpdconf
	httpd=`ps -U nobody | grep httpd`
	if [ -z "$httpd" ]; then
		/etc/init.d/httpd startssl
	fi
	msg="found and fixed broken httpdconf"
	echo "$msg" && logger -t info -t "cpusercheck[$$]" "$msg"
fi

# check for and gracefully handle user domain changes
if [ -f "$md5_file" ]; then
        currenthash=`md5sum $files | md5sum`
        lasthash=`cat $md5_file`
        md5sum $files | md5sum > $md5_file
        if [ ! "$lasthash" == "$currenthash" ]; then
                psval=`nice -n 19 ps auxww | grep rebuildhttpdconf | grep -v grep`
                if [ "$psval" ]; then
                        # currently running rebuildhttpdconf, lets not step on our own or other toes
			msg="user configuration mappings changed but detected a running rebuildhttpdconf, exiting with no action taken."
			echo "$msg" && logger -t info -t "cpusercheck[$$]" "$msg"
                        rm -f $lock_file
                        exit 1
                fi
		apache_etime=`nice -n 19 ps -U nobody -o 'user ppid pid etime cmd' --no-headers | grep httpd | tr -d ':' | sort -n -k4  | tail -n1 | awk '{print$4}'`
		apache_min_etime=`echo $apache_min_etime | tr -d ':'`
		if [ -z "$apache_etime" ]; then
			apache_etime="100"
		fi
		msg="user configuration mappings changed, forcing rebuild of apache virtualhost configurations."
		echo "$msg" && logger -t info -t "cpusercheck[$$]" "$msg"
                /scripts/rebuildhttpdconf >> /dev/null 2>&1
		if [ "$apache_etime" -le "$apache_min_etime" ]; then
			msg="completed virtualhost configuration rebuild but queued SIGHUP to apache as it was recently restarted"
			echo "$msg" && logger -t info -t "cpusercheck[$$]" "$msg"
			touch /tmp/.cpuc.pendinghup
		else
               		killall -HUP httpd 2> /dev/null
			if [ -f "/usr/local/sbin/nginxctl" ]; then
				/usr/local/sbin/nginxctl -c >> /dev/null 2>&1
			fi
			msg="completed virtualhost configuration rebuild and sent SIGHUP to apache."
			echo "$msg" && logger -t info -t "cpusercheck[$$]" "$msg"
		fi
        fi
	if [ -f "/tmp/.cpuc.pendinghup" ]; then
		apache_etime=`nice -n 19 ps -U nobody -o 'user ppid pid etime cmd' --no-headers | grep httpd | tr -d ':' | sort -n -k4  | tail -n1 | awk '{print$4}'`
                apache_min_etime=`echo $apache_min_etime | tr -d ':'`
                if [ -z "$apache_etime" ]; then
                        apache_etime="500"
                fi
                if [ "$apache_etime" -ge "$apache_min_etime" ]; then
                	msg="found pending apache SIGHUP from previously detected user configuration mapping changes, sent apache SIGHUP."
                	echo "$msg" && logger -t info -t "cpusercheck[$$]" "$msg"
                	killall -HUP httpd 2> /dev/null
			rm -f /tmp/.cpuc.pendinghup
		fi
	fi
else
        md5sum $files | md5sum > $md5_file
fi

rm -f $lock_file
