#!/usr/bin/env bash
##
#             (C) 2002-2019, R-fx Networks <proj@rfxn.com>
#             (C) 2019, Ryan MacDonald <ryan@rfxn.com>
# This program may be freely redistributed under the terms of the GNU GPL v2
##
# call create_gretun from /etc/apf/gre.conf, kthxbye.

create_gretun() {
 linkid="$1"
 if [ "$linkid" == "0" ]; then
	linkid="1"
 elif [ -z "$linkid" ]; then
	echo "no linkid set or invalid arguments passed to create_gretun()"
	exit 1
 fi
 routefrom="$2"
 routeto="$3"
 if [ -z "$routefrom" ] || [ -z "$routeto" ]; then
	echo "invalid arguments passed to create_gretun()"
	exit 1
 fi
 ipfile="$4"
 tunmode=gre
 linkname="${tunmode}${linkid}"
 greip_src="192.168.${linkid}.1"
 greip_dst="192.168.${linkid}.2"

 if [ "$role" == "source" ]; then
	routedif=`route -n | grep -w UG | egrep -vE '^10\.|^192\.|^172\.' | awk '{print$8}'`
	routedgw=`route -n | grep -w UG | egrep -vE '^10\.|^192\.|^172\.' | awk '{print$2}'`
	allowf="/etc/apf/allow_hosts.rules"
	if [ -f "$allowf" ]; then
		val=`grep $routeto $allowf`
		if [ -z "$val" ]; then
			echo -e "# gre tunnel to $routeto\n$routeto" >> $allowf
		fi
	fi
	ip tunnel add $linkname mode $tunmode remote $routeto local $routefrom ttl 255
	ip link set $linkname up
	ifconfig $linkname arp
	ifconfig $linkname $greip_src
	ip route add 192.168.${linkid}.0/24 dev $linkname
	iptables -A INPUT -i $linkname -j ACCEPT
	iptables -A OUTPUT -o $linkname -j ACCEPT
	sysctl -w net.ipv4.conf.${routedif}.proxy_arp=1
	sysctl -w net.ipv4.ip_forward=1

	if [ -f "$ipfile" ]; then
		arpfile="/tmp/.sentarps.${linkid}"
		arptimeout=3600
		if [ -f "$arpfile" ]; then
			arpfile_utime=`stat -c '%Z' $arpfile`
			current_utime=`date +'%s'`
			diff_utime=$[current_utime-arpfile_utime]
			if [ "$diff_utime" -ge "$arptimeout" ]; then
				rm -f $arpfile
			fi
		else
			echo "setting gre routed ips and sending arp updates, this might take a minute...."
			doarp=1
			touch $arpfile
		fi
		for routedip in `cat $ipfile`; do
			if [ "$doarp" ]; then
				echo "    routing/sending arp for address $routedip on behalf of gre${linkid} $routeto"
				ifconfig $linkname:arp $routedip >> /dev/null 2>&1
				arping -I $routedif -s $routedip $routedgw -c1 >> /dev/null 2>&1
				ifconfig $linkname:arp down >> /dev/null 2>&1
			fi
			route add -host $routedip gw $greip_dst >> /dev/null 2>&1
		done
		unset doarp
	fi
 elif [ "$role" == "target" ]; then
        allowf="/etc/apf/allow_hosts.rules"
        if [ -f "$allowf" ]; then
                val=`grep $routefrom $allowf`
                if [ -z "$val" ]; then
                        echo -e "# gre tunnel from $routefrom\n$routefrom" >> $allowf
                fi
        fi
	ip tunnel add $linkname mode $tunmode local $routeto remote $routefrom ttl 255
	ip link set $linkname up
	ifconfig $linkname arp
	ifconfig $linkname $greip_dst
	ip route add 192.168.${linkid}.0/24 dev $linkname
	iptables -A INPUT -i $linkname -j ACCEPT
	iptables -A OUTPUT -o $linkname -j ACCEPT
	sysctl -w net.ipv4.conf.all.rp_filter=0
	sysctl -w net.ipv4.conf.$linkname.rp_filter=0
        if [ -f "$ipfile" ]; then
                cnt=0
                for routedip in `cat $ipfile`; do
                        ((cnt++))
                        ifconfig $linkname:$cnt $routedip
                done
        fi
 fi
}

if [ -f "/etc/apf/gre.conf" ]; then
	. /etc/apf/gre.conf
fi
