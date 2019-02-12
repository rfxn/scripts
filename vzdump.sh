#!/usr/bin/env bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##

vzhost=`hostname`
if [ -z "$1" ]; then
        echo "vzhost vzid hostname ipaddr state template memory(mb) assigned_disk(mb) used_disk(mb)" > /tmp/.vzd.$$
else
        echo "vzhost vzid hostname ipaddr state template memory(mb) assigned_disk(mb) used_disk(mb) cpanel_ver cpanel_users php_ver php_hand mysql_ver" > /tmp/.vzd.$$
fi
for vz in `vzlist -a | egrep -vE "ServiceCT|HOSTNAME" | tr ' ' '%'`; do
        id=`echo $vz | tr '%' ' ' | awk '{print$1}'`
        if [ "$id" != "1" ]; then
         state=`echo $vz | tr '%' ' ' | awk '{print$3}'`
         ip=`echo $vz | tr '%' ' ' | awk '{print$4}'`
         if [ -z "$ip" ]; then
                ip="-"
         fi
         file="/etc/vz/conf/$id.conf"
         if [ -f "$file" ]; then
                name=`cat $file | egrep -w HOSTNAME | cut -d'=' -f2 | tr -d '"'`
                if [ -z "$name" ]; then
			if [ -f "/vz/root/$id/etc/sysconfig/network" ]; then
				name=`egrep HOSTNAME /vz/root/$id/etc/sysconfig/network | cut -d'=' -f2 | tr -d '"'`
				if [ -z "$name" ]; then
					name="unknown"
				fi
			else
	                        name="unknown"
			fi
                fi
                dist=`cat $file | egrep -w DISTRIBUTION | cut -d'=' -f2 | tr -d '"'`
                templ=`cat $file | egrep -w OSTEMPLATE | cut -d '=' -f2 | tr -d '".'`
                if [ -z "$templ" ]; then
                        templ="unknown"
                fi
                arch=`cat $file | egrep -w ARCH | cut -d'=' -f2 | tr -d '"'`
                mem=`cat $file | egrep -w SLMMEMORYLIMIT | cut -d'=' -f2 | tr '":' ' ' | awk '{print$2}'`
                if [ -z "$mem" ]; then
                        mem=`cat $file | egrep -w KMEMSIZE | cut -d'=' -f2 | tr '":' ' ' | awk '{print$1}'`
                fi
                mem=`echo "scale=0; $mem / 1048000" | bc`
                disk=`cat $file | egrep -w DISKSPACE | cut -d'=' -f2 | tr '":' ' ' | awk '{print$1}'`
                disk=`echo "scale=0; $disk / 1000" | bc`
                if [ -z "$mem" ]; then
                        mem=0
                fi
                chpfx="chroot /vz/root/$id"
                if [ -d "/vz/root/$id" ]; then
                        diskuse=`$chpfx df -m / | egrep dev | awk '{print$3}'`
			if [ -z "$diskuse" ]; then
				diskuse="-"
			fi
                fi
                if [ "$1" == "cpinfo" ]; then
			if [ -d "/vz/root/$id/var/cpanel/users" ]; then
	                        cpv=`$chpfx /usr/local/cpanel/cpanel -V | awk '{print$1}'`
				if [ -z "$cpv" ]; then
					cpz="-"
				fi
        	                phpv=`$chpfx /usr/local/bin/php -v | head -n1 | awk '{print$2}'`
				if [ -z "$phpv" ]; then
					phpv="-"
				fi
                	        mysqlv=`$chpfx mysql -V | awk '{print$5}' | tr -d ','`
				if [ -z "$mysqlv" ]; then
					mysqlv="-"
				fi
	                        phphandler=`egrep suphp /vz/root/$id/usr/local/apache/conf/php.conf`
        	                if [ -z "$phphandler" ]; then
                	                phphandler="dso"
                        	else
                                	phphandler="suphp"
	                        fi
        	                cpusers=`ls /vz/root/$id/var/cpanel/users | wc -l`
				if [ -z "$cpusers" ]; then
					cpusers="-"
				fi
			fi
                	echo "$vzhost $id $name $ip $state $templ $mem $disk $diskuse $cpv $cpusers $phpv $phphandler $mysqlv" >> /tmp/.vzd.$$
                else
                        echo "$vzhost $id $name $ip $state $templ $mem $disk $diskuse" >> /tmp/.vzd.$$
                fi
         fi
        fi
done

cat /tmp/.vzd.$$ | column -t
rm -f /tmp/.vzd.$$

