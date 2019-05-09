#!/bin/bash

TIME=180
USER="coloca_seu_usuario_aqui"
PASS="coloca_sua_senha_aqui"
DNS="coloca_dns_aqui"
VPN="coloca_vpn_aqui"

stay-alive()
{
        while true
        do
                ping -c 1 $DNS
                sleep $TIME
        done
}

echo -n $PASS | openconnect -b $VPN -u $USER --passwd-on-stdin                                  
stay-alive &
byobu
