#!/bin/bash

# Constants
DATE=$(date +%s)
FOLDER="nmap_logs"

# Arguments
ip_range=""
start_ip=""
end_ip=""
filter_file=""
args=""

# Help function
help()
{
    echo "Made by dev.cmsantos (dev.cmsantos@gmail.com)"
    echo "MIT License, use at your own risk."
    echo ""
    echo "    nmap-horizontal ip [-efs] [args]"
    echo "        ip is for a range of IPs, so for instance 192.168.10, then this script will hover over from 1 to 255."
    echo ""
	echo "        middle argument is to include defined ranges, if you wish to start, let's say, from 30 to 100. Then, you'd type -s 30 -e 100. -f if you want to filter undesired IP address, like gateways (let's say 192.168.10.2 or 192.168.10.255). For such, it will look for a filter file on this very folder, and on each line it will look for IP addresses that won't be checked by this tool."
	echo ""
    echo "        args is optional. It is for anything extra you want NMAP to do like \"script smb-os-discovery script-args vulns.short\""
    echo ""
	echo "    EXAMPLE: nmap-horizontal 10.20.30 -s 50 -e 70 -f nmap-filter.txt script smb-os-discovery script-args vulns.short"
	echo ""
}

# Sanitize IP address format
sanitize()
{
    oct1=$(echo $ip_range | tr "." " " | awk '{print $1}')
    oct2=$(echo $ip_range | tr "." " " | awk '{print $2}')
    oct3=$(echo $ip_range | tr "." " " | awk '{print $3}')

    if [[ $oct1 -gt 0 && $oct1 -lt 256 ]]
    then
        if [[ $oct2 -gt 0 && $oct2 -lt 256 ]]
        then
            if [[ $oct3 -gt 0 && $oct3 -lt 256 ]]
            then
                : # Do nothing
            else
                help
                exit
            fi
        else
            help
            exit
        fi
    else
        help
        exit
    fi
}

# Check if NMAP exists and create a log folder
nmap-check()
{
    if [ $(dpkg-query -W -f='${Status}' nmap 2>/dev/null | grep -c "ok installed") -eq 0 ]
    then
        echo "NMAP package not found. Please do install it:"
        echo "    apt install nmap"
        echo ""
        exit
    else
        if test -d $FOLDER
        then
            : # Do nothing
        else
            mkdir $FOLDER
        fi
    fi
}

do-nmap()
{
	echo "nmap -v -n -Pn -sS -sV -p $port $ip_range.$ip $args | tee -a $FOLDER/log_$DATE.txt"
	nmap -v -n -Pn -sS -sV -p $port $ip_range.$ip $args | tee -a $FOLDER/log_$DATE.txt
}

nmap-no-filters()
{
    for port in {1..65535}
    do
        for ip in $(seq $start_ip $end_ip)
        do
            do-nmap
        done
    done
}

nmap-filtered()
{
	# This is a boolean flag to skip NMAP on certain IP addresses
	ignore=""

	# Loop through ports
	for port in {1..65535}
	do
		# Loop through IP addresses
		for ip in $(seq $start_ip $end_ip)
		do
			ignore="false"
			for reject in $(cat $filter_file)
			do
				# Is the current IP to be rejected?
				if [[ $reject == $ip_range.$ip ]]
				then
					ignore="true"
					break
				fi
			done

		if [[ $ignore == "true" ]]
		then
			# If current IP to be reject, loop to next IP
			continue
		else
			# Otherwise, NMAP it!
			do-nmap
		fi
		done
	done
}



# MAIN


# If no inputs, help user to use it :)
if [ $# -eq 0 ]
then
	help
	exit
fi

# Save first argument and test it
ip_range=$1
shift
sanitize
if [ $# -ne 0 ]
then
	# Verify if there are extra arguments
	for i in {1..3}
	do
		if [ $# -eq 0 ]
		then
			break
		else
			if [ $1 == "-s" ]
			then
				shift
				if [ $1 -ge 1 ] && [ $1 -le 255 ]
				then
					start_ip=$1
					shift
				else
					help
					exit
				fi
			elif [ $1 == "-e" ]
			then
				shift
				if [ $1 -ge 1 ] && [ $1 -le 255 ]
				then
					end_ip=$1
					shift
				else
					help
					exit
				fi
			elif [ $1 == "-f" ]
			then
				shift
				filter_file=$1
				shift
			fi
		fi
	done
fi

# Check if starting and ending IP's were set
if test -z $start_ip
then
	start_ip=0
fi
if test -z $end_ip
then
	end_ip=255
fi
if [ $start_ip -gt $end_ip ]
then
	help
	exit
fi

# Verify if there are additional arguments for NMAP
while true
do
	if [ $# -eq 0 ]
	then
		break
	else
		if test -z "$args"
		then
			args=$1
		else
			args="$args $1"
		fi
		shift
	fi
done

# Check if NMAP exists
nmap-check

# Just some credits. Feel free to remove this
echo "Made by dev.cmsantos (dev.cmsantos@gmail.com)"
echo "MIT License, use at your own risk."

# Is there a filter? Horizontal NMAP will execute differently then.
if [ -e "$filter_file" ] && [ -s $filter_file ]
then
	nmap-filtered
else
	echo "Filter file does not exist or is empty. Executing non-filtered NMAP"
	nmap-no-filters
fi

echo ""
echo "Results are in $FOLDER/log_$DATE.txt"
echo ""
