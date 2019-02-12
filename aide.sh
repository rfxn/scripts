#!/bin/bash
##
# 	(C) 2002-2014, R-fx Networks <proj@rfxn.com>
# 	(C) 2014, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##
# Generate change logs with comparative execution against
# last execution database. This can be resource intensive
# and is best performed on remote systems with remotely
# stored database.
compare="0"

# E-mail addresses (comma spaced) for change reports, these can
# be very large; requires compare=1.
email=""

# max age of local logs and databases in days
# default 90 days which results in ~1GB data path
maxage_days=90

# data path for aide databases
data=/var/lib/aide

# path to aide binary
aide=`which aide 2> /dev/null`

# timeout in seconds as maximum execution time for aide
runtime_timeout="14400"

####
nice=`which nice 2> /dev/null`
timeout=`which timeout 2> /dev/null`
move_file_timestamp() {
	file="$1"
	cp="$2"
	if [ -f "$file" ]; then
		size=`stat -c '%s' "$file"`
		if [ "$size" == "0" ]; then
			rm -f "$file"
			deleted=1
		fi
		if [ ! "$deleted" ]; then
			tstamp=`stat -c "%y" "$file" | tr '.' ' ' | tr -d ':-' | awk '{print$1"-"$2}'`
			if [ "$tstamp" ] && [ ! -f "${file}.${tstamp}" ]; then
                                fname=`echo "$file" | sed 's/.new//'`
				if [ "$cp" ]; then
					cp "$file" "${fname}.${tstamp}"
				else
					mv "$file" "${fname}.${tstamp}"
				fi
				chmod 600 "${fname}.${tstamp}"
				echo "${fname}.${tstamp}"
			fi
		fi
	fi
	unset deleted sil file tstamp
}

if [ -f "$aide" ]; then
	dstamp=`date +"%H%M-%m%d%Y"`
	log=$data/aide.log
	cur_db=$data/aide.db
	new_db=$data/aide.db.new

	if [ ! -d "$data" ]; then
		mkdir -p $data
		chmod 700 $data
	else
		chmod 700 $data
	fi

	# if we find an existing aide.db, move it to time stamped file and gzip
	gzip_curdb=`move_file_timestamp "$cur_db"`
	test "$gzip_curdb" && gzip -f "$gzip_curdb" && md5sum "${gzip_curdb}.gz" > "${gzip_curdb}.gz.md5"

	# do the same with aide.log
	gzip_curlog=`move_file_timestamp "$log"`
	test "$gzip_curlog" && gzip -f "$gzip_curlog" && md5sum "${gzip_curlog}.gz" > "${gzip_curlog}.gz.md5"

	# is there a previous run aide.db.new? are we comparing?
	# if compare=1 then move it to current, otherwise timestamp
	# it and get it out of the way
	if [ -f "$data/aide.db.gz.last" ] && [ "$compare" == "1" ]; then
		cp "$data/aide.db.gz.last" "${cur_db}.gz"
		gunzip "${cur_db}.gz"
	else
		gzip_file=`move_file_timestamp "$new_db" `
		test "$gzip_file" && gzip -f "$gzip_file" && md5sum "${gzip_file}.gz" > "${gzip_file}.gz.md5"
	fi

	# generate new database (aide.db.new)
	$timeout $runtime_timeout $nice -n 19 $aide --init >> /dev/null 2>&1

	if [ "$compare" == "1" ]; then
		# perform comparative execution (aide.db & aide.db.new)
		$timeout $runtime_timeout $nice -n 19 $aide --compare >> /dev/null 2>&1
		rm -f $cur_db

		# move the new aide.db.new to timestamped file
		gzip_file=`move_file_timestamp "$new_db"`
		test "$gzip_file" && gzip -f "$gzip_file" && md5sum "${gzip_file}.gz" > "${gzip_file}.gz.md5"
		ln -fs "${gzip_file}.gz" $data/aide.db.gz.last
	else
		# move the new aide.db.new to timestamped file
		gzip_file=`move_file_timestamp "$new_db"`
		test "$gzip_file" && gzip -f "$gzip_file" && md5sum "${gzip_file}.gz" > "${gzip_file}.gz.md5"
		ln -fs "${gzip_file}.gz" $data/aide.db.gz.last

		# no comparison done, no need for log file
		rm -f $log
	fi

	if [ "$compare" == "1" ] && [ "$email" ] && [ -f "$log" ]; then
		cat $log | mail -s "AIDE change report on $HOSTNAME" $email
		# move aide.log to timestamped file
		gzip_file=`move_file_timestamp "$log"`
		test "$gzip_file" && gzip -f "$gzip_file" && md5sum "${gzip_file}.gz" > "${gzip_file}.gz.md5"
	fi

	# delete files older than $maxage_days from aide data path
	find=`which find 2> /dev/null`
	if [ -f "$find" ] && [ "$data" ] && [ "$maxage_days" ]; then
		$find ${data} -type f -mtime +${maxage_days} -print0 | xargs -0 rm -f
	fi
fi
