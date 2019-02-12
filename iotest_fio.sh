#!/usr/bin/env bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
fio=`which fio 2> /dev/null`
mount=/home
outpath=$mount/fio
if [ -z  "$fio" ]; then
        echo "fio not installed, available from dag & epel repos, bye."
        exit 1
fi

if [ -f "$filename" ]; then
  rm -f $filename
fi

if [ ! -d "$outpath" ]; then
        mkdir $outpath
fi

dsync() {
        sync ; echo 3 > /proc/sys/vm/drop_caches ; sleep 5
}

echo "rwmode opmode blksize MB/s IOPS Msec" > $outpath/fio_results.txt

fiorun() {
 # fiorun fsize blksize depth jobs rwmode rread rwrite
 file_size="$1"
 fio_blocksize="$2"
 iodepth="$3"
 numjobs="$4"
 rwmode="$5"
 rread="$6"
 rwrite="$7"

 if [ -z "$fio_blocksize" ]; then
        fio_blocksize="4K"
 fi
 if [ -z "$file_size" ]; then
        file_size="2G"
 fi
 if [ -z "$iodepth" ]; then
        iodepth="4"
 fi
 if [ -z "$numjobs" ]; then
        numjobs="4"
 fi
 if [ -z "$rwmode" ]; then
        rwmode=rw
 fi
 if [ -z "$rread" ]; then
        rread=50
 fi
 if [ -z "$rwrite" ]; then
        rwrite=50
 fi
 filename="$mount/.fio.test"

 otheropts="--invalidate=1 --direct=1"
 echo "fio rwmode=$rwmode blksize=$fio_blocksize datasize=$file_size iodepth=$iodepth jobs=$numjobs"
 outfile="$outpath/${rwmode}_${fio_blocksize}.txt"
 fio $otheropts --size=100% --filesize=${file_size} --blocksize=${fio_blocksize} --ioengine=libaio --rw=$rwmode --rwmixread=${rread} --rwmixwrite=${rwrite} --iodepth=${iodepth} --numjob=${numjobs} --group_reporting --filename=$filename --name=${hit}_Hit_${fio_blocksize}  --output="$outfile" >> /dev/null
 rm -f $filename
 echo
 tmpf=/tmp/.$$.fio
 echo "rwmode opmode blksize MB/s IOPS Msec" > $tmpf

 read_stats=`cat $outfile | egrep 'read.*io=.*' | tr ':,=' ' ' | sed -e 's_msec__' -e 's_KB/s__' | awk '{print$5,$7,$9}'`
 if [ "$read_stats" ]; then
        rtp=`echo $read_stats | awk '{print$1}' | grep MB`
        if [ "$rtp" ]; then
                rtp=`echo $rtp | sed 's_MB/s__'`
        else
                rtp=`echo "scale=2; $(echo $read_stats | awk '{print$1}' | tr -d '[:alpha:]') / 1024" | bc`
        fi
        riops=`echo $read_stats | awk '{print$2}'`
        rtime=`echo $read_stats | awk '{print$3}'`
        echo "$rwmode read $fio_blocksize ${rtp} ${riops} $rtime" >> $tmpf
        echo "$rwmode read $fio_blocksize ${rtp} ${riops} $rtime" >> $outpath/fio_results.txt
 fi

 write_stats=`cat $outfile | egrep 'write.*io=.*' | tr ':,=' ' ' | sed -e 's_msec__' -e 's_KB/s__'  | awk '{print$5,$7,$9}'`
 if [ "$write_stats" ]; then
        wtp=`echo $write_stats | awk '{print$1}' | grep MB`
        if [ "$wtp" ]; then
                wtp=`echo $wtp | sed 's_MB/s__'`
        else
                wtp=`echo "scale=2; $(echo $write_stats | awk '{print$1}' | tr -d '[:alpha:]') / 1024" | bc`
        fi
        wiops=`echo $write_stats | awk '{print$2}'`
        wtime=`echo $write_stats | awk '{print$3}'`
        echo "$rwmode write $fio_blocksize ${wtp} ${wiops} $wtime" >> $tmpf
        echo "$rwmode write $fio_blocksize ${wtp} ${wiops} $wtime" >> $outpath/fio_results.txt
 fi

 cat $tmpf | column -t
 rm -f $tmpf
 echo
}

runopt="750M 4K 16 8"
fiorun $runopt read
fiorun $runopt write
fiorun $runopt rw
fiorun $runopt randread
fiorun $runopt randwrite
fiorun $runopt randrw

#runopt="1536M 8K 4 4"
#fiorun $runopt read
#fiorun $runopt write
#fiorun $runopt rw
#fiorun $runopt randread
#fiorun $runopt randwrite
#fiorun $runopt randrw
