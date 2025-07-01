#!/bin/bash

validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Erro: IP inválido ($ip)"
        exit 1
    fi
}

validate_range() {
    local range=$1
    if [[ ! $range =~ ^[0-9]+$ || $range -lt 1 || $range -gt 254 ]]; then
        echo "Erro: Valor de range inválido ($range)"
        exit 1
    fi
}

validate_interface() {
    local iface=$1
    if ! ip link show "$iface" &>/dev/null; then
        echo "Erro: Interface $iface não existe"
        exit 1
    fi
}

test_user() {
    if [ "$USERID" -ne "0" ]; then
        echo "Execute como root."
        exit 1
    fi
}

install_update() {
    echo "Atualizando pacotes e instalando o dhcp-server."
    apt update > /tmp/dhcp-install.log 2>&1
    apt install isc-dhcp-server -y >> /tmp/dhcp-install.log 2>&1
    if ! dpkg -l | grep -q isc-dhcp-server; then
        echo "Erro: Falha ao instalar isc-dhcp-server. Verifique /tmp/dhcp-install.log"
        exit 1
    fi
}

cidr_translation() {
    validate_range "$INIT_RANGE"
    validate_range "$END_RANGE"
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
    default-lease-time      28800;
    max-lease-time          86400;
    range                   $INIT_RANGE $END_RANGE;
    option routers          $GATEWAY;
    option domain-name-servers  $DNS;
    option broadcast-address $( echo $SUBNET | sed s/0/255/ );
EOF

    [ "$DOMAIN_ON" = "y" ] && echo "    option domain-name      \"$DOMAIN_NAME\";" >> /etc/dhcp/dhcpd.conf
    [ "$NTP_ON" = "y" ] && echo "    option ntp-servers      $IP_NTP;" >> /etc/dhcp/dhcpd.conf

    echo "}" >> /etc/dhcp/dhcpd.conf

    cat >> /etc/rsyslog.conf << EOF
local7.*        /var/log/dhcpd-server.log
EOF
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
    sleep 1
    systemctl restart named.service
    if [ $? -ne "0" ]; then
        echo "Erro na reinicialização do bind."
        exit 1
    fi
}

sync_on() {
    read -p "O DNS está neste mesmo host?           [y p/ sim] " DNS_IN_HOST
    if [ "$DNS_IN_HOST" = "y" ]; then
        # Verifica se o BIND está instalado
        if ! command -v named &>/dev/null; then
            echo "Erro: BIND não está instalado neste host"
            exit 1
        fi
        [ "$AUTORITY_ON" = "y" ] && sed -i "2s/off/on/" /etc/dhcp/dhcpd.conf && sed -i "3s/none/interim/" /etc/dhcp/dhcpd.conf
        [ "$AUTORITY_ON" != "y" ] && sed -i "1s/off/on/" /etc/dhcp/dhcpd.conf && sed -i "2s/none/interim/" /etc/dhcp/dhcpd.conf
        read -p "Criar uma nova key-rndc?            [y p/ sim] " CREATE_RNDC
        [ "$CREATE_RNDC" = "y" ] && rndc-confgen -a -b 512

        # Backup dos arquivos BIND
        cp /etc/bind/named.conf.options /etc/bind/named.conf.options.bkp
        cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bkp

        grep "^key\b" /etc/bind/named.conf.options &>/dev/null
        KEY_ON=$( echo $? )
        if [ $KEY_ON -eq 0 ]; then
            NUMBER_KEY=$( grep -n "^key\b" /etc/bind/named.conf.options | cut -d ":" -f 1 )
            sed -i "${NUMBER_KEY}d" /etc/bind/named.conf.options    
            sed -i "${NUMBER_KEY}d" /etc/bind/named.conf.options    
            sed -i "${NUMBER_KEY}d" /etc/bind/named.conf.options    
            sed -i "${NUMBER_KEY}d" /etc/bind/named.conf.options    
        fi

        cat /etc/bind/rndc.key >> /etc/dhcp/dhcpd.conf
        cat /etc/bind/rndc.key >> /etc/bind/named.conf.options    

        # Proteger permissões do rndc.key
        chmod 640 /etc/bind/rndc.key
        chown root:bind /etc/bind/rndc.key

        grep "^controls\b" /etc/bind/named.conf.options &>/dev/null
        CONTROL_ON=$( echo $? )
        if [ $CONTROL_ON -eq 0 ]; then
            NUMBER_CONTROL=$( grep -n "^controls\b" /etc/bind/named.conf.options | cut -d ":" -f 1 )
            sed -i "${NUMBER_CONTROL}d" /etc/bind/named.conf.options    
            sed -i "${NUMBER_CONTROL}d" /etc/bind/named.conf.options    
            sed -i "${NUMBER_CONTROL}d" /etc/bind/named.conf.options    
            sed -i "${NUMBER_CONTROL}d" /etc/bind/named.conf.options    
        fi

        cat >> /etc/bind/named.conf.options << EOF
controls {
    inet 127.0.0.1 port 953
    allow { 127.0.0.1; } keys { "rndc-key"; };
};
EOF
        read -p "Nome da zone: " ZONE_NAME
        NUMBER_ZONE=$( grep -n "\"$ZONE_NAME\"" /etc/bind/named.conf.local | cut -d ":" -f 1 )
        grep "allow-update" /etc/bind/named.conf.local &>/dev/null
        ALLOW_UPT_ON=$( echo $?)

        if [ $ALLOW_UPT_ON -eq 0 ]; then
            NUMBER_ALLOW_UPT=$( grep -n "allow-update" /etc/bind/named.conf.local | cut -d ":" -f 1 )
            sed -i "${NUMBER_ALLOW_UPT}s/{ .*; };/{ key rndc-key; };/" /etc/bind/named.conf.local
        else
            sed -i "${NUMBER_ZONE}s/$/\n/" /etc/bind/named.conf.local
            sed -i $(( $NUMBER_ZONE + 1 ))"s/^/\tallow-update { key rndc-key; };/" /etc/bind/named.conf.local
        fi

        cat >> /etc/dhcp/dhcpd.conf << EOF

zone $ZONE_NAME {
    primary 127.0.0.1;
    key rndc-key;
}
EOF
        
        if ! named-checkconf; then
            echo "Erro: Configuração do BIND inválida"
            exit 1
        fi

        restart_bind
    else
        dns_out_host
    fi    
}

dns_out_host() {
    clear
    echo "O servidor DNS está em outro host."
    echo "Consulte as instruções em '/opt/Dhcp-ISC/dns_out.txt' para configurar o DDNS."
    echo
    while true; do
        read -p "Digite [ok] para sair. " OUT
        [ "$OUT" = "ok" ] && break
    done
}

default_cfg() {
    echo "Informe a interface que será utilizada pelo script:"
    echo
    ip l | grep "^[[:digit:]]" | cut -d":" -f 2 | tr "\n" " "
    echo
    echo
    read -p "Interface: " IFACE
    validate_interface "$IFACE"
    sed -i "s/#OPTION=\"\"/OPTION=\"-4\"/" /etc/default/isc-dhcp-server
    sed -i "s/#INTERFACEv4=\"\"/INTERFACEv4=\"$IFACE\"/" /etc/default/isc-dhcp-server
}

menu_main() {
    clear
    echo "Começando a configuração."
    sleep 1
    default_cfg
    echo
    echo "Esse script aplica por padrão o CIDR /24 na subnet."
    sleep 1
    echo
    read -p "subnet:         > " SUBNET
    validate_ip "$SUBNET"
    read -p "gateway:        > " GATEWAY
    validate_ip "$GATEWAY"
    read -p "DNS:            > " DNS
    validate_ip "$DNS"
    echo
    echo "Informe apenas o último octeto do range."
    echo
    read -p "Início do range  > $( echo $SUBNET | sed s/0$//)" INIT_RANGE
    read -p "Fim do range    > $( echo $SUBNET | sed s/0$// )" END_RANGE
    echo
    read -p "Adicionar domínio?              [y p/ sim] " DOMAIN_ON
    read -p "Adicionar ntp-server?           [y p/ sim] " NTP_ON
    echo
    [ "$DOMAIN_ON" = "y" ] && read -p "domain name    > " DOMAIN_NAME
    [ "$NTP_ON" = "y" ] && read -p "ntp-server     > " IP_NTP && validate_ip "$IP_NTP"
    echo
    read -p "Este DHCP terá autoridade na rede?      [y p/ sim] " AUTORITY_ON
    [ "$AUTORITY_ON" = "y" ] && echo "authoritative;" > /etc/dhcp/dhcpd.conf

    cidr_translation
    dhcpd_cfg

    read -p "Ativar integração dinâmica com Bind?     [y p/ sim] " SYNC_ON
    [ "$SYNC_ON" = "y" ] && sync_on

    echo
    clear
    echo "Finalizando a configuração."
    sleep 1
}
