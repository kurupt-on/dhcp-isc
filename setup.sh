#!/bin/bash

USERID=$( id -u )

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

dhcpd_cfg() {
	cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bkp
	cat > /etc/dhcp/dhcpd.cof << EOF
ddns-updates off;
ddns-update-style none;

subnet $SUBNET netmask $NETMASK {
	range				"$INIT_RANGE" "$END_RANGE";
	optionl routers			"$GATEWAY";
	optinal domain-name-servers	"$DNS";
}

EOF

}

restart_dhcpd() {
	echo "Reinicializando o serviço."
	systemctl restart isc-dhcpd-server.service
	if [ $? -ne "0" ]; then
		echo "Erro na reinicialização."
		exit 1
	fi
}

menu_main() {
	echo "Começando a comfiguração de seu DHCP."
	echo
	read -p "subnet :" SUBNET
	read -p "netmask :" NETMASK
	read -p "Incio do range :" INIT_RANGE
	read -p "Fim do range :" END_RANGE
	read -p "gateway :" GATEWAY
	read -p "DNS :" DNS

	dhcpd_cfg
	
}

test_user
menu_main
restart_dhcpd

