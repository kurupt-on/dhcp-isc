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

menu_select() {
	read -p ""
}

test_user

