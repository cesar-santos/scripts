#!/bin/bash

TIME=180
CONN_TRIES=3
REDIRECT="/dev/null"

USER="coloca_seu_usuario_aqui"
PASS="coloca_sua_senha_aqui"
VPN="coloca_vpn_aqui"

RESOLV_FILE="/etc/resolv.conf"
DNS_DFLT_1="coloca_dns_aqui"
DNS_DFLT_2="8.8.8.8"

DNS1="coloca_dns_aqui"
DNS2="coloca_dns_aqui"
DNS3="coloca_dns_aqui"

ROUTE1="coloca_rota_aqui"
GW1="coloca_gateway_aqui"

ROUTE2="coloca_rota_aqui"
GW2="coloca_gateway_aqui"

stay-alive()
{
        while true
        do
                ping -c $CONN_TRIES $DNS > $REDIRECT 2>&1
                sleep $TIME
        done
}

connect-vpn()
{
	# Check if can reach VPN
	echo "Checking VPN availability..."
	ping -c $CONN_TRIES $VPN &> $REDIRECT
	if [[ $? != "0" ]]
	then
		# Note to user
		echo "Not yet. Restoring connectivity"

		# Restarting resolv.conf file
		echo "#Restored by wargames script" > $RESOLV_FILE
		echo "search localdomain" >> $RESOLV_FILE
		echo "nameserver $DNS_DFLT_1" >> $RESOLV_FILE
		echo "nameserver $DNS_DFLT_2" >> $RESOLV_FILE
	fi

	# Connecting to VPN and waiting
	echo "Connecting to VPN"
	echo -n $PASS | openconnect -b $VPN -u $USER --passwd-on-stdin
	sleep 5
}

resolve-network()
{
	# Removing old definition
	echo "# Generated by Cyber City script" > /etc/resolv.conf

	# Appending new DNS servers
	echo "nameserver $DNS1" >> $RESOLV_FILE
	echo "nameserver $DNS2" >> $RESOLV_FILE
	echo "nameserver $DNS3" >> $RESOLV_FILE

	# Making sure a good connection route is created
	route add -net $ROUTE1/16 gw $GW1
	route add -net $ROUTE2/16 gw $GW2
}


# Get to Cyber City VPN
connect-vpn

# Setting up routes and DNS
resolve-network

# Keeping connection alive
stay-alive &

# Starting byobu session
byobu
