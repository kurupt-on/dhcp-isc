# dhcp-isc

Um script Bash para configurar servidores ISC DHCP em sistemas baseados em Debian, com suporte a alocação dinâmica de IPs, integração com DNS Dinâmico (DDNS) e configurações personalizáveis de sub-rede, gateway, DNS e NTP. **Este projeto não é destinado para ambientes de produção.**

## Como Usar

### Pré-requisitos

- Debian 11 ou superior (testado no Debian 12).
- Acesso root para executar o script.
- Conexão à internet para instalar pacotes.
- Opcional: Servidor BIND9 (local ou remoto) para integração com DNS Dinâmico.
- Recomendado: Testar em uma máquina virtual.

### 1. Clone o Repositório

```bash
git clone https://github.com/kurupt-on/Dhcp-ISC
cd Dhcp-ISC
```

### 2. Configurar o Servidor DHCP

```bash
sudo ./setup.sh
```

- Forneça as informações solicitadas:
  - **Interface**: Interface que o DHCP utilizará (ex.: `enp0s3`).
  - **Sub-rede**: Ex.: `192.168.1.0` (assume máscara /24).
  - **Gateway**: Ex.: `192.168.1.1`.
  - **DNS**: Endereço do servidor DNS (ex.: `192.168.1.2`).
  - **Domínio**: (Opcional) Nome do domínio local (ex.: `exemplo.com`).
  - **NTP**: (Opcional) Endereço do servidor NTP.
  - **Intervalo de IPs**: Último octeto inicial e final (ex.: `100` e `200` para `192.168.1.100-200`).
  - **Modo autoritativo**: Escolha se o servidor será autoritativo na rede.
  - **Integração com DDNS**: Ative para configurar DNS Dinâmico com BIND (local ou remoto).

- Para DDNS com DNS em outro host, siga as instruções em `dns_out.txt`.

### 3. Testar

Verifique se o serviço DHCP está funcionando:

```bash
systemctl status isc-dhcp-server
```

Teste a alocação de IPs em um cliente na rede:

```bash
# Em um cliente (Windows)
ipconfig /renew

# Em um cliente (Linux)
dhclient -r && dhclient
```

**Saída esperada**: O cliente recebe um IP no intervalo configurado (ex.: `192.168.1.100-200`), com gateway e DNS corretos.

Para DDNS (se configurado):

```bash
dig @<IP_DO_DNS> <nome_do_cliente>.exemplo.com
```

**Saída esperada** (exemplo para `cliente1.exemplo.com`):

```
;; ANSWER SECTION:
cliente1.exemplo.com. 28800 IN A 192.168.1.100
```

Verifique os logs do DHCP:

```bash
cat /var/log/dhcpd-server.log
```

## Solução de Problemas

- Verifique o status do serviço:

  ```bash
  systemctl status isc-dhcp-server
  ```

- Consulte os logs:

  ```bash
  journalctl -r -u isc-dhcp-server
  ```

- Valide a configuração do DHCP:

  ```bash
  dhcpd -t -cf /etc/dhcp/dhcpd.conf
  ```

- Para DDNS com BIND local, valide a configuração do BIND:

  ```bash
  named-checkconf
  ```

- Certifique-se de que os IPs fornecidos (sub-rede, gateway, DNS) são válidos e que o servidor DNS está acessível.

- Se o DNS está em outro host, siga as instruções em `dns_out.txt` cuidadosamente.

## Arquivos

- `setup.sh`: Script principal que realiza a configuração.
- `functions.sh`: Contém funções reutilizáveis.
- `dns_out.txt`: Instruções para configurar DDNS com o servidor DNS em outro host.
- `LICENSE`: Licença do projeto (MIT).
- `README.md`: Este arquivo de documentação.

## Licença

Este projeto está licenciado sob a Licença MIT.
