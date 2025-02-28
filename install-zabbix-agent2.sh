#!/bin/bash
#
# autor: marcilio ramos
# data: 12-02-2025
# finalidade: automatizar instalação do agente linux zabbix
# comando para executar o script: 
# curl -o z.sh https://codesilo.dimenoc.com/-/snippets/41/raw/main/install_zabbix_agente2.sh ; chmod +x z.sh ; ./z.sh
#

# Função para verificar se o comando existe
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Instalar wget se não estiver presente
  if command_exists yum; then
    yum install -y wget smartmontools sudo 
    echo "zabbix ALL=(ALL) NOPASSWD:/usr/sbin/smartctl" | sudo tee /etc/sudoers.d/zabbix-smartctl
  elif command_exists apt; then
    apt update && sudo apt install -y wget smartmontools sudo
    echo "zabbix ALL=(ALL) NOPASSWD:/usr/sbin/smartctl" | sudo tee /etc/sudoers.d/zabbix-smartctl
  else
    echo "Gerenciador de pacotes não suportado. Instale o wget manualmente."
    exit 1
  fi

# Solicitar dados ao usuário
read -p "Digite o HDNUMBER: " HDNUMBER
read -p "Digite o NOMEDOCLIENTE: " NOMEDOCLIENTE
read -p "Digite o DC (JPA ou SPO): " DC
read -p "Digite o HOSTNAME: " HOSTNAME
read -p "Tipo de HOST (VM ou NODE): " TIPO

# Transformar inputs em maiúsculas
HDNUMBER=$(echo "$HDNUMBER" | tr '[:lower:]' '[:upper:]')
NOMEDOCLIENTE=$(echo "$NOMEDOCLIENTE" | tr '[:lower:]' '[:upper:]')
DC=$(echo "$DC" | tr '[:lower:]' '[:upper:]')
HOSTNAME=$(echo "$HOSTNAME" | tr '[:lower:]' '[:upper:]')
TIPO=$(echo "$TIPO" | tr '[:lower:]' '[:upper:]')

# Listar sistemas operacionais suportados
echo "Selecione o sistema operacional:"
echo "1) Red Hat Enterprise Linux 9 / CentOS Stream 9 / Oracle Linux 9 / Rocky Linux 9 / AlmaLinux 9"
echo "2) Red Hat Enterprise Linux 8 / CentOS 8 / Oracle Linux 8 / Rocky Linux 8 / AlmaLinux 8"
echo "3) Red Hat Enterprise Linux 7 / CentOS 7 / Oracle Linux 7"
echo "4) Debian 12 (Bookworm)"
echo "5) Debian 11 (Bullseye)"
echo "6) Debian 10 (Buster)"
echo "7) Ubuntu 22.04 LTS (Jammy Jellyfish)"
echo "8) Ubuntu 20.04 LTS (Focal Fossa)"
echo "9) Ubuntu 18.04 LTS (Bionic Beaver)"
echo "10) SUSE Linux Enterprise Server 15"
echo "11) Raspbian 11 (Bullseye) para Raspberry Pi"
read -p "Digite o número correspondente: " OS_CHOICE

# Determinar a URL e o instalador com base na escolha do usuário
case $OS_CHOICE in
  1)
    URL="https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-agent2-7.0.8-release1.el9.x86_64.rpm"
    INSTALLER="yum"
    ;;
  2)
    URL="https://repo.zabbix.com/zabbix/7.0/rhel/8/x86_64/zabbix-agent2-7.0.8-release1.el8.x86_64.rpm"
    INSTALLER="yum"
    ;;
  3)
    URL="https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/zabbix-agent2-7.0.8-release1.el7.x86_64.rpm"
    INSTALLER="yum"
    ;;
  4)
    URL="https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix/zabbix-agent2_7.0.8-1+debian12_amd64.deb"
    INSTALLER="dpkg"
    ;;
  5)
    URL="https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix/zabbix-agent2_7.0.8-1+debian11_amd64.deb"
    INSTALLER="dpkg"
    ;;
  6)
    URL="https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix/zabbix-agent2_7.0.8-1+debian10_amd64.deb"
    INSTALLER="dpkg"
    ;;
  7)
    URL="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.0.8-1+ubuntu22.04_amd64.deb"
    INSTALLER="dpkg"
    ;;
  8)
    URL="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.0.8-1+ubuntu20.04_amd64.deb"
    INSTALLER="dpkg"
    ;;
  9)
    URL="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix/zabbix-agent2_7.0.8-1+ubuntu18.04_amd64.deb"
    INSTALLER="dpkg"
    ;;
  10)
    URL="https://repo.zabbix.com/zabbix/7.0/sles/15/x86_64/zabbix-agent2-7.0.8-release1.sles15.x86_64.rpm"
    INSTALLER="yum"
    ;;
  11)
    URL="https://repo.zabbix.com/zabbix/7.0/raspbian/pool/main/z/zabbix/zabbix-agent2_7.0.8-1+raspbian11_armhf.deb"
    INSTALLER="dpkg"
    ;;
  *)
    echo "Opção inválida. Saindo."
    exit 1
    ;;
esac

# Baixar o arquivo
TEMP_FILE="/tmp/zabbix-agent2-package"
TEMP_FILE_RPM="/tmp/zabbix-agent2-package.rpm"

# Instalar o pacote
if [ "$INSTALLER" = "yum" ]; then
  echo "Baixando o pacote do Zabbix Agent 2..."
  wget -O "$TEMP_FILE_RPM" "$URL"
  sudo yum install -y "$TEMP_FILE_RPM"
elif [ "$INSTALLER" = "dpkg" ]; then
  echo "Baixando o pacote do Zabbix Agent 2..."
  wget -O "$TEMP_FILE" "$URL"
  sudo dpkg -i "$TEMP_FILE"
  sudo apt-get install -f -y
fi

# Configurar o arquivo zabbix_agent2.conf
CONFIG_FILE="/etc/zabbix/zabbix_agent2.conf"
HOSTNAME_FORMAT="${TIPO}.${HDNUMBER}.${DC}.${NOMEDOCLIENTE}.${HOSTNAME}.LINUX"
echo "Criando arquivo de configuração do Zabbix Agent 2..."
sudo mkdir -p /etc/zabbix
sudo bash -c "cat > $CONFIG_FILE <<EOF
PidFile=/var/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
Server=127.0.0.1
ServerActive=cm.hostdime.com.br:10083
Hostname=${HOSTNAME_FORMAT}
HostMetadata=dimenoc##1223##HDBRASIL
Include=/etc/zabbix/zabbix_agent2.d/*.conf
PluginSocket=/run/zabbix/agent.plugin.sock
ControlSocket=/run/zabbix/agent.sock
Include=/etc/zabbix/zabbix_agent2.d/plugins.d/*.conf
EOF"

# Reiniciar o serviço do Zabbix Agent 2
echo "Reiniciando o serviço do Zabbix Agent 2..."
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2 --now

# Limpar o arquivo temporário
rm -f "$TEMP_FILE"

echo "Instalação e configuração concluídas."

rm z.sh
