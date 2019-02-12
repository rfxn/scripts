#!/usr/bin/env bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##
export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
fsize="1G"
syncopt="-I -e"
testopt="-i 0 -i 1 -i 2"
otheropt="-O -+n"
testpath="/home/iotest"

iozone=`which iozone 2> /dev/null`
if [ ! -f "$iozone" ]; then
	yum install -y iozone
	iozone=`which iozone 2> /dev/null`
	if [ ! -f "$iozone" ]; then
		echo "iozone not installed, aborting!"
		exit 1
	fi
fi

if [ -d "$testpath" ]; then
        rm -rf $testpath

fi
mkdir $testpath
alias dsync="sync ; echo 3 > /proc/sys/vm/drop_caches ; sleep 10"

bench() {
 iosize=$1
 if [ -z "$iosize" ]; then
        iosize=8K
 fi
 dsync
 cd $testpath
 rstart=`date +"%s"`
 $iozone -Rb $testpath/sproutput_$iosize.wks $syncopt $testopt $otheropt -r $iosize -s $fsize > $testpath/output_$iosize.txt
 rend=`date +"%s"`
 rtime=$[rend-rstart]
 echo "runtime: ${rtime}s" >> $testpath/output_$iosize.txt
 rm -f iozone.tmp
}

bench 4K
bench 8K
#bench 16K
#bench 32K
rm -f /tmp/.ioout ; for i in `ls $testpath/output_*`; do iops=`cat $i  | grep -A1 "freread" | awk '{print"write: "$3,"read: "$5,"ranwrite: "$8,"ranread: "$7}' | tail -n1`; size=`echo $i | tr '_.' ' ' | awk '{print$2}'`; runt=`cat $i | grep runtime | awk '{print$1,$2}'`; echo "$size $runt $iops" >> /tmp/.ioout; done ; cat /tmp/.ioout | sort -n -k1  |column -t
