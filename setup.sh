#!/bin/bash

USERID=$( id -u )
NETMASK="255.255.255.0"
DOMAIN_ON=""
DOMAIN_NAME=""
IP_NTP=""
DNS_IN_HOST=""
CREATE_RNDC=""
CONTROL_ON=""
NUMBER_CONTROL=""
NUMBER_ZONE=""
ZONE_NAME=""
ALLOW_UPT_ON=""
KEY_ON=""
NUMBER_KEY=""
NTP_ON=""
CIDR=""
INIT_RANGE=""
END_RANGE=""
AUTORITY_ON=""
SUBNET=""
GATEWAY=""
DNS=""
NUMBER_ALLOW_UPT=""
OUT=""
SYNC_ON=""	


. functions.sh

install_update
test_user
menu_main
restart_dhcpd

