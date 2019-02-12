#!/usr/bin/env bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##
tmpf=/var/tmp/.satrend.$$
run() {
        file=$1
        if [ -f "$file" ]; then
         date=`stat -c '%z' $file | awk '{print$1}'`
         loadavg=`sar -q -f $file  | grep Average | awk '{print"load "$4}' | tail -n1`
	 load95=`LC_TIME=posix sar -q -f $file | awk '{print$4}' | egrep '^[0-9]+\.[0-9]+$' | sort -n | awk 'BEGIN{c=0} length($0){a[c]=$0;c++}END{p5=(c/100*5); p5=p5%1?int(p5)+1:p5; print a[c-p5-1]}'`
         tpsavg=`sar -b -f $file  | grep Average | awk '{print"tps "$2" rtps "$3" wtps " $4}' | tail -n1`
         cpuavg=`sar -f $file | grep Average | awk '{print"cpuidle "$8" iowait "$6}' | tail -n1`
         echo "$date $loadavg load95 $load95 $cpuavg $tpsavg" >> $tmpf
        fi
}

for file in `ls /var/log/sa/ -rt | egrep "sa[0-9]+"`; do
        run /var/log/sa/$file
done
today=`date +"%Y-%m-%d"`
histl=`wc -l $tmpf | awk '{print$1}'`

avgload=`echo 'scale=2;' $(cat $tmpf | awk '{print$3}'  | paste -sd+ | bc) / $histl | bc`
avgload95=`echo 'scale=2;' $(cat $tmpf | awk '{print$5}'  | paste -sd+ | bc) / $histl | bc`
avgcpui=`echo 'scale=2;' $(cat $tmpf | awk '{print$7}'  | paste -sd+ | bc) / $histl | bc`
avgiow=`echo 'scale=2;' $(cat $tmpf  | awk '{print$9}'  | paste -sd+ | bc) / $histl | bc`
avgtps=`echo 'scale=2;' $(cat $tmpf  | awk '{print$11}'  | paste -sd+ | bc) / $histl | bc`
avgrtps=`echo 'scale=2;' $(cat $tmpf  | awk '{print$13}'  | paste -sd+ | bc) / $histl | bc`
avgwtps=`echo 'scale=2;' $(cat $tmpf  | awk '{print$15}'  | paste -sd+ | bc) / $histl | bc`
echo "average load $avgload load95 $avgload95 cpuidle $avgcpui iowait $avgiow tps $avgtps rtps $avgrtps wtps $avgwtps"  >> $tmpf

cat $tmpf | sed "s/$today/today/" | column -t
rm -f $tmpf


