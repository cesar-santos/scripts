#!/bin/bash

# HINT
#
# For an IP filter file, you may want to scan only a few IPs. So, it may work better to generate a HUGE list of IPs
# and then removing manually the ones you wanna scan.
#
# For such, this command may serve:
#     for i in $(seq 0 255) ; do echo "192.168.10.$i" >> nmap_filter_file.txt ; done
#
# Adapt it at your own will.


# Constants
FIRST_IP=1
LAST_IP=255
FIRST_PORT=1
LAST_PORT=65535
FILTER_FILE="/tmp/ports.txt"
LOG_FOLDER="nmap_logs"
DATE=$(date +%s)

# Arguments
ip_range=""
start_ip=""
end_ip=""
filter_ports=""
filter_file=""
args=""

# Help function
help()
{
	echo ""
	echo "    nmap-horizontal ip [-efsp] [args]"
	echo "        ip is for a range of IPs, so for instance 192.168.10, then this script will hover over from 1 to 255."
	echo ""
	echo "        middle arguments are optional. They are meant to include defined ranges, if you wish to start, let's say, from 30 to 100, or on ports 80 and 445. Then, you'd type -s 30 -e 100 -p PORTS.txt, considering PORTS.txt file will contain lines \"80\" and \"445\". -f if you want to filter undesired IP address, like gateways (let's say 192.168.10.2 or 192.168.10.255). For such, it will look for a filter file on this very folder, and on each line it will look for IP addresses that won't be checked by this tool."
	echo ""
	echo "        args is optional too. It is for anything extra you want NMAP to do like \"script smb-os-discovery script-args vulns.short\""
	echo ""
	echo "    EXAMPLE: nmap-horizontal 10.20.30 -s 50 -e 70 -f nmap-filter.txt -p ports.txt script smb-os-discovery script-args vulns.short"
	echo ""
}

# Sanitize IP address format
sanitize()
{
    oct1=$(echo $ip_range | tr "." " " | awk '{print $1}')
    oct2=$(echo $ip_range | tr "." " " | awk '{print $2}')
    oct3=$(echo $ip_range | tr "." " " | awk '{print $3}')

    if [[ $oct1 -ge $FIRST_IP && $oct1 -le $LAST_IP ]]
    then
        if [[ $oct2 -ge $FIRST_IP && $oct2 -le $LAST_IP ]]
        then
            if [[ $oct3 -ge $FIRST_IP && $oct3 -le $LAST_IP ]]
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
        if test -d $LOG_FOLDER
        then
            : # Do nothing
        else
            mkdir $LOG_FOLDER
        fi
    fi
}

do-nmap()
{
	#echo "nmap -v -n -Pn -sS -sV -p $port $ip_range.$ip $args | tee -a $LOG_FOLDER/log_$DATE.txt"
	nmap -v -n -Pn -sS -sV -p $port $ip_range.$ip -D10.3.1.11,10.3.1.12 $args | tee -a $LOG_FOLDER/log_$DATE.txt
}

nmap-no-filters()
{
    for port in `cat $filter_ports`
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
	for port in $(cat $filter_ports)
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


# Just some credits. Feel free to remove this
echo "Made by dev.cmsantos (dev.cmsantos@gmail.com)"
echo "MIT License, use at your own risk."
echo -n "Configuring environment"

# Remove old garbage
rm $filter_ports 2>/dev/null

# If no inputs, help user to use it :)
if [ $# -eq 0 ]
then
	help
	exit
fi
echo -n "."

# Save first argument and test it
ip_range=$1
shift
sanitize
if [ $# -ne 0 ]
then
	# Verify if there are extra arguments
	for i in $(seq 1 4)
	do
		if [ $# -eq 0 ]
		then
			break
		else
			if [ $1 == "-s" ]
			then
				shift
				if [ $1 -ge $FIRST_IP ] && [ $1 -le $LAST_IP ]
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
				if [ $1 -ge $FIRST_IP ] && [ $1 -le $LAST_IP ]
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
			elif [ $1 == "-p" ]
			then
				shift
				filter_ports=$1
				shift
			fi
		fi
	done
fi
echo -n "."

# Check if starting and ending IP's were set
if test -z $start_ip
then
	start_ip=$FIRST_IP
fi
if test -z $end_ip
then
	end_ip=$LAST_IP
fi
echo -n "."

# Make sure IP addresses are possible
if [ $start_ip -gt $end_ip ]
then
	help
	exit
fi
echo -n "."

# Check if a port list will be used
if test -z $filter_ports
then
	filter_ports=$FILTER_FILE
	touch $filter_ports
	for i in $(seq $FIRST_PORT $LAST_PORT)
	do
		echo $i >> $filter_ports
	done
fi
echo -n "."

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
echo -n "."

# Check if NMAP exists
nmap-check
echo -n "."

# Is there a filter? Horizontal NMAP will execute differently then.
echo ""
if [ -e "$filter_file" ] && [ -s $filter_file ]
then
	nmap-filtered
else
	echo "Filter file does not exist or is empty. Executing non-filtered NMAP"
	nmap-no-filters
fi
rm $filter_ports

echo ""
echo "Results are in $LOG_FOLDER/log_$DATE.txt"
echo ""
