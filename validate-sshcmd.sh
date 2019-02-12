#!/bin/bash
export PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
logger=`which logger 2> /dev/null`
ssh_from=`echo $SSH_CLIENT | awk '{print$1}'`
ssh_to=`echo $SSH_CONNECTION | awk '{print$4}'`

eout() {
 appn="sshcmd"
 string="$1"
        if [ ! -z "$string" ]; then
		$logger -t "${appn}[$$]" "$string"
                if [ "$2" == "1" ]; then
                        echo "$appn($$): $string"
                fi
        fi
}

case "$SSH_ORIGINAL_COMMAND" in
*\&*)
        eout "ssh command rejected from $ssh_from: $SSH_ORIGINAL_COMMAND" 1
        ;;
*\;*)
        eout "ssh command rejected from $ssh_from: $SSH_ORIGINAL_COMMAND" 1
        ;;
scp*)
        eout "ssh command accepted from $ssh_from: $SSH_ORIGINAL_COMMAND"
        $SSH_ORIGINAL_COMMAND
        ;;
*)
        if [ -z "$SSH_ORIGINAL_COMMAND" ]; then
                eout "interactive shell rejected from $ssh_from" 1
        else
                eout "ssh command rejected from $ssh_from: $SSH_ORIGINAL_COMMAND" 1
        fi
        ;;
esac
