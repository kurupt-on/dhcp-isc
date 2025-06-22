#!/bin/bash

USERID=$( id -u )
NETMASK="255.255.255.0"

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
	cat > /etc/dhcp/dhcpd.conf << EOF
ddns-updates off;
ddns-update-style none;

subnet $SUBNET netmask $NETMASK {
	range				$INIT_RANGE $END_RANGE;
	option routers			$GATEWAY;
	option domain-name-servers	$DNS;
}

EOF
}

restart_dhcpd() {
	echo "Reinicializando o serviço."
	systemctl restart isc-dhcp-server.service
	if [ $? -ne "0" ]; then
		echo "Erro na reinicialização."
		exit 1
	fi
}

menu_main() {
	echo "Começando a comfiguração."
	sleep 1
	echo "Esse script aplica por padrão o CIDR /24 na subnet."
	echo
	read -p "subnet:	" SUBNET
	read -p "gateway:	" GATEWAY
	read -p "DNS:		" DNS
	echo
	echo "Informe apenas o último octeto."
	read -p "Incio do range :" INIT_RANGE
	read -p "Fim do range :" END_RANGE
	cidr_translation
	dhcpd_cfg
	
}

test_user
menu_main
restart_dhcpd

