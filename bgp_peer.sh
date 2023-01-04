#!/bin/bash

function valid_ip()
{
	local  ip=$1
	local  stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
			&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi
	return $stat
}

declare -a dependencies=(/usr/bin/timeout /usr/bin/sshpass /usr/bin/ssh)
for dependency in ${dependencies[@]}; do
	if [ ! -x "$dependency" ]; then 
			echo "Please install: $dependency which is required for this script to work!" 
	    exit 1
	  fi
done

if [ $# -lt 4 ];
then
	echo -e "Wrong usage!\n\nUse:\n\t$0 state <hostname|ip> <ssh-port> <username> <password> <name>\nor\n\t$0 names <hostname|ip> <ssh-port> <username> <password>"
	exit 1
fi

querytype=$1
hostname=$2
if [ ! -z "$sshport" ]
then
      sshport=22
else sshport=$3
fi
username=$4
password=$5
peername=$6

if [ $querytype = "state" -o $querytype = "uptime" ]; then
	/usr/bin/timeout --kill-after 25.0s 20.0s \
		/usr/bin/sshpass -p "$password" \
			/usr/bin/ssh \
			-o logLevel=Error \
			-o ConnectTimeout=5 \
			-o ConnectionAttempts=3 \
			-o StrictHostKeyChecking=no \
			$username@$hostname -p $sshport "/routing/bgp/session print" | sed -z 's/\r//g;s/\n\n/\n;/g;s/\n//g;s/;/\n/g' > /usr/share/zabbix/bgp-peer-all-status

	if [ $querytype = "state" ]; then
		grep -c " E name=\"$peername" /usr/share/zabbix/bgp-peer-all-status 
	elif [ $querytype = "uptime" ]; then
		raw_time=$( grep "name=\"$peername" --color=never /usr/share/zabbix/bgp-peer-all-status | grep -Po " uptime=\K[^ ]+" )
		finalTime=0

		for time in `echo $raw_time | grep -Po --color=never '[0-9]{1,3}[a-z]{1,2}'`
		do
			weeks=${weeks:-0}
			days=${days:-0}
			hours=${hours:-0}
			minutes=${minutes:-0}
			seconds=${seconds:-0}

			timeUnit=$( echo $time | grep -Eo --color=never "[a-z]{1,2}" )
			timeCounter=$( echo $time | grep -Eo --color=never "[0-9]+" )

			case $timeUnit in
				w)
					(( weeks += timeCounter*604800 ))
					;;
				d)
					(( days += timeCounter*86400 ))
					;;
				h)
					(( hours += timeCounter*3600 ))
					;;
				m)
					(( minutes = timeCounter*60 ))
					;;			
				s)
					(( seconds= timeCounter ))
					;;
				*)
					;;
			esac
			
		done

    ### Calculate uptime
    finalTime=$(echo $weeks + $days + $hours + $minutes + $seconds|bc)
  
    ### OUTPUT - write out the uptime
    echo $finalTime
	fi
elif [ $querytype = "names" ]; then
	/usr/bin/timeout --kill-after 25.0s 20.0s \
		/usr/bin/sshpass -p "$password" \
			/usr/bin/ssh \
			-o logLevel=Error \
			-o ConnectTimeout=5 \
			-o ConnectionAttempts=3 \
			-o StrictHostKeyChecking=no \
			$username@$hostname -p $sshport "/routing/bgp/export" | sed -z 's/\r//g;s/\\\n    //g' | grep -v " disabled=yes " | grep -E -o "name=[^ ]+" | cut -d "=" -f 2  > /usr/share/zabbix/bgp-peer-statuses

	out="{\"data\": ["
	while read name;
	do
		out="$out{\"{#BGP_PEER_NAME}\": \"$name\"}, "

	done < /usr/share/zabbix/bgp-peer-statuses

  if [ $(wc -l /usr/share/zabbix/bgp-peer-statuses | cut -f1 -d' ')  -gt 0 ]; then
    echo "${out::-2}]}"
  else
    echo "${out}]}"
  fi
else
	ERROR_MESSAGE="The <querytype> isn´t correct. It should be \"state\" or \"names\"!\n" \
	&& exit 2
fi
