#!/bin/bash

USERID=$( id -u )
NETMASK="255.255.255.0"
DOMAIN_ON=""
NTP_ON=""

test_user() {
	if [ "$USERID" -ne "0" ]; then
		echo "Execute como root."
		exit 1
	fi
}

install_update() {
	echo "Atualizando pacotes e instalando o dhcp-server."
	apt update &>/dev/null
	apt install isc-dhcp-server -y &>/dev/null
}

cidr_translation() {
	CIDR=$( echo $SUBNET | sed s/0/$INIT_RANGE/ )
	INIT_RANGE=$CIDR
	CIDR=$( echo $SUBNET | sed s/0/$END_RANGE/ )
	END_RANGE=$CIDR
}

dhcpd_cfg() {
	cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bkp

	[ "$AUTORITY_ON" = "y" ] || > /etc/dhcp/dhcpd.conf
	cat >> /etc/dhcp/dhcpd.conf << EOF
ddns-updates off;
ddns-update-style none;
log-facility local7;

subnet $SUBNET netmask $NETMASK {
	default-lease-time		28800;
	max-lease-time			86400;
	range				$INIT_RANGE $END_RANGE;
	option routers			$GATEWAY;
	option domain-name-servers	$DNS;
	option broadcast-address	$( echo $SUBNET | sed s/0/255/ );
EOF

	[ "$DOMAIN_ON" = "y" ] && echo "	option domain-name		\"$DOMAIN_NAME\";" >> /etc/dhcp/dhcpd.conf
	[ "$NTP_ON" = "y" ] && echo "	option ntp-servers		$IP_NTP;" >> /etc/dhcp/dhcpd.conf

	echo "}" >> /etc/dhcp/dhcpd.conf

	cat >> /etc/rsyslog.conf << EOF
local7.*		/var/log/dhcpd-server.log
EOF
	echo
	clear
	echo "Finalizando a configuração."
	sleep 1
}

restart_dhcpd() {
	echo
	echo "Reinicializando o serviço."
	systemctl restart isc-dhcp-server.service
	if [ $? -ne "0" ]; then
		echo "Erro na reinicialização."
		exit 1
	fi
}

restart_bind() {
	echo
	echo "Reinicializando o bind."
	systemctl restart named
	if [ $? -ne "0" ]; then
		echo "Erro na reinicialização do bind."
		exit 1
	fi
}

sync_on() {
	sed -i "1s/off/on/" /etc/dhcp/dhcpd.conf
	sed -i "2s/none/interim/" /etc/dhcp/dhcpd.conf

	read -p "O DNS está neste mesmo host?" DNS_IN_HOST
	if [ "$DNS_IN_HOST" = "y" ]; then
		read -p "Criar uma nova key-rndc? 	[y p/ sim] " CREATE_RNDC
		[ "$CREATE_RNDC" = "y" ] && rndc-confgen -a -b 512

		cat /etc/bind/rndc.key >> /etc/dhcp/dhcpd.conf
		cat /etc/bind/rndc.key >> /etc/bind/named.conf.options	

		cat >> /etc/bind/named.conf.options << EOF
controls {
	inet 127.0.0.1 port 953
	allow { 127.0.0.1; } keys { "rndc-key"; };
};
EOF

		read -p "Nome da zone: " ZONE_NAME
		NUMBER_ZONE=$( grep -n "\"$ZONE_NAME\"" /etc/bind/named.conf.local | cut -d ":" -f 1 )
		sed -i ""$NUMBER_ZONE"s/$/\n/" /etc/bind/named.conf.local
		sed -i $(( $NUMBER_ZONE + 1 ))"s/^/\tallow-update { key rndc-key; };/" /etc/bind/named.conf.local

		>> /etc/dhcp/dhcpd.conf

		cat >> /etc/dhcp/dhcpd.conf << EOF

zone $ZONE_NAME {
	primary 127.0.0.1;
	key rndc-key;
}
EOF
		
	fi	
}

menu_main() {
	clear
	echo "Começando a comfiguração."
	sleep 1
	echo
	read -p "Este DHCP terá autóridade na rede?		[y p/ sim] " AUTORITY_ON
	[ "$AUTORITY_ON" = "y" ] && echo "authoritative;" > /etc/dhcp/dhcpd.conf
	echo
	echo "Esse script aplica por padrão o CIDR /24 na subnet."
	sleep 1
	echo
	read -p "subnet:		>" SUBNET
	read -p "gateway:	>" GATEWAY
	read -p "DNS:		>" DNS
	echo

	read -p "Adcionar domínio?	[y p/ sim] " DOMAIN_ON
	read -p "Adcionar ntp-server?	[y p/ sim] " NTP_ON
	echo
	[ "$DOMAIN_ON" = "y" ] && read -p "domain name	>" DOMAIN_NAME
	[ "$NTP_ON" = "y" ] && read -p "ntp-server	>" IP_NTP

	echo
	echo "Informe apenas o último octeto."
	read -p "Incio do range 	$( echo $SUBNET | sed s/0//)" INIT_RANGE
	read -p "Fim do range	$( echo $SUBNET | sed s/0// )" END_RANGE

	cidr_translation
	dhcpd_cfg

	read -p "Ativar integração dinâmica com Bind?	[y p/ sim] " SYNC_ON
	[ "$SYNC_ON" = "y" ] && sync_on
}

test_user
menu_main
restart_bind
restart_dhcpd

