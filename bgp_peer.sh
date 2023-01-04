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
	[ ! -x $dependency ] \
		&& ERROR_MESSAGE="ERROR: Missing $dependency" \
		&& exit 100
done

if [ $# -lt 4 ];
then
	echo -e "Wrong usage!\n\nUse:\n\t$0 state <hostname|ip> <username> <password> <name>\nor\n\t$0 names <hostname|ip> <username> <password>"
	exit 1
fi

querytype=$1
hostname=$2
username=$3
password=$4
peername=$5

if [ $querytype = "state" -o $querytype = "uptime" ]; then
	/usr/bin/timeout --kill-after 25.0s 20.0s \
		/usr/bin/sshpass -p "$password" \
			/usr/bin/ssh \
			-o logLevel=Error \
			-o ConnectTimeout=5 \
			-o ConnectionAttempts=3 \
			-o StrictHostKeyChecking=no \
			$username@$hostname "/routing/bgp/session print" | sed -z 's/\r//g;s/\n\n/\n;/g;s/\n//g;s/;/\n/g' > /tmp/bgp-peer-all-status

	if [ $querytype = "state" ]; then
		grep -c " E name=\"$peername" /tmp/bgp-peer-all-status 
	elif [ $querytype = "uptime" ]; then
		raw_time=$( grep "name=\"$peername" --color=never /tmp/bgp-peer-all-status | grep -Po " uptime=\K[^ ]+" )
		finalTime=0

		for time in `echo $raw_time | grep -Po --color=never '[0-9]{1,2}[a-z]{1,2}'`
		do
			timeUnit=$( echo $time | grep -Eo --color=never "[a-z]" )
			timeCounter=$( echo $time | grep -Eo --color=never "[0-9]+" )

			case $timeUnit in
				s)
					(( finalTime += timeCounter ))
					;;
				m)
					(( finalTime += timeCounter*60 ))
					;;
				h)
					(( finalTime += timeCounter*3600 ))
					;;
				d)
					(( finalTime += timeCounter*86400 ))
					;;
				w)
					(( finalTime += timeCounter*604800 ))
					;;
				*)
					;;
			esac
			
		done

    ### add it to convert finaltime to number
    finalTime+=0
  
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
			$username@$hostname "/routing/bgp/export" | sed -z 's/\r//g;s/\\\n    //g' | grep -v " disabled=yes " | grep --color=never -Po "name=\K[0-9a-z-]*" > /tmp/bgp-peer-statuses

	out="{\"data\": ["
	while read name;
	do
		out="$out{\"{#BGP_PEER_NAME}\": \"$name\"}, "

	done < /tmp/bgp-peer-statuses

  if [ $(wc -l /tmp/bgp-peer-statuses | cut -f1 -d' ')  -gt 0 ]; then
    echo "${out::-2}]}"
  else
    echo "${out}]}"
  fi
else
	ERROR_MESSAGE="The <querytype> isn´t correct. It should be \"state\" or \"names\"!\n" \
	&& exit 2
fi
