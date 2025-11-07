#!/bin/bash

# Instalador Completo de Cluster Docker Swarm - PT-BR
# Criado por: Guilherme Jansen

STATE_DIR="$HOME/.setup_state"
STATE_FILE="$STATE_DIR/installation_state.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
PURPLE='\033[1;35m'
NC='\033[0m'

log() {
    echo -e "${GREEN}$(date +'%d-%m-%Y %H:%M:%S') - $1${NC}"
    echo "$(date +'%d-%m-%Y %H:%M:%S') - $1" >> "$STATE_DIR/setup.log"
}

log_error() {
    echo -e "${RED}$(date +'%d-%m-%Y %H:%M:%S') - ERRO: $1${NC}"
    echo "$(date +'%d-%m-%Y %H:%M:%S') - ERRO: $1" >> "$STATE_DIR/setup.log"
}

log_warning() {
    echo -e "${YELLOW}$(date +'%d-%m-%Y %H:%M:%S') - AVISO: $1${NC}"
    echo "$(date +'%d-%m-%Y %H:%M:%S') - AVISO: $1" >> "$STATE_DIR/setup.log"
}

initialize.environment() {

    if [ ! -d "$STATE_DIR" ]; then
        mkdir -p "$STATE_DIR"
    fi

    touch "$STATE_DIR/setup.log"

    if [ ! -f "$STATE_FILE" ]; then
        echo "# Estado da instalação - Criado em $(date)" > "$STATE_FILE"
        echo "OS_CHOICE=0" >> "$STATE_FILE"
        echo "SYSTEM_USER=" >> "$STATE_FILE"
        echo "DOCKER_INSTALLED=false" >> "$STATE_FILE"
        echo "DOCKER_PERMISSIONS_CONFIGURED=false" >> "$STATE_FILE"
        echo "FIREWALL_CONFIGURED=false" >> "$STATE_FILE"
        echo "SWARM_INITIALIZED=false" >> "$STATE_FILE"
        echo "SWARM_LABELS_CONFIGURED=false" >> "$STATE_FILE"
        echo "NETWORK_CREATED=false" >> "$STATE_FILE"
        echo "NETWORK_NAME=" >> "$STATE_FILE"
        echo "TRAEFIK_INSTALLED=false" >> "$STATE_FILE"
        echo "PORTAINER_INSTALLED=false" >> "$STATE_FILE"
        echo "KERNEL_NOTIFICATIONS_DISABLED=false" >> "$STATE_FILE"
        echo "NODE_TYPE=" >> "$STATE_FILE"
    fi

    sed -i 's/\r$//' "$0"

    source "$STATE_FILE"
}

update_state() {
    local key="$1"
    local value="$2"

    sed -i "s/^$key=.*/$key=$value/" "$STATE_FILE"

    export "$key"="$value"

    log "Estado atualizado: $key = $value"
}

check_step() {
    local step_var="$1"
    local step_name="$2"
    local force_var="${3:-false}"

    source "$STATE_FILE"

    if [ "${!step_var}" = "true" ] && [ "$force_var" = "false" ]; then
        echo -e "${YELLOW}O passo '$step_name' já foi concluído.${NC}"
        echo -n "Deseja executar novamente? (y/n): "
        read -r redo_choice

        if [[ "$redo_choice" =~ ^[Nn]$ ]]; then
            return 1
        else
            return 0
        fi
    fi

    return 0
}

show_logo() {
    echo ""
    echo -e "${PURPLE}███████╗██╗   ██╗██╗     ██╗         ███████╗████████╗ █████╗  ██████╗██╗  ██╗"
    echo -e "${PURPLE}██╔════╝██║   ██║██║     ██║         ██╔════╝╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝"
    echo -e "${PURPLE}█████╗  ██║   ██║██║     ██║         ███████╗   ██║   ███████║██║     █████╔╝ "
    echo -e "${PURPLE}██╔══╝  ██║   ██║██║     ██║         ╚════██║   ██║   ██╔══██║██║     ██╔═██╗ "
    echo -e "${PURPLE}██║     ╚██████╔╝███████╗███████╗    ███████║   ██║   ██║  ██║╚██████╗██║  ██╗"
    echo -e "${PURPLE}╚═╝      ╚═════╝ ╚══════╝╚══════╝    ╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝"
    echo ""
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════════════════════════"
    echo -e "                        ${NC}💻 Setup Automatizado LTDA 🤖"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo -e "${YELLOW}🚀 Docker Swarm - Instalador Completo de Cluster"
    echo -e "${NC}📋 Versão: 1.0 | Criado por: Guilherme Jansen"
    echo -e "${NC}"
    echo ""
}

disable_kernel_notifications() {
    if check_step "KERNEL_NOTIFICATIONS_DISABLED" "Desabilitar notificações de kernel"; then
        log "Desabilitando notificações de atualização do kernel..."

        case $OS in
            debian|ubuntu)

                if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
                    sudo sed -i 's/^APT::Periodic::Update-Package-Lists "1";/APT::Periodic::Update-Package-Lists "0";/' /etc/apt/apt.conf.d/20auto-upgrades
                    sudo sed -i 's/^APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/20auto-upgrades
                else
                    sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF'
                fi

                if [ -f /etc/default/grub ]; then
                    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
                    sudo update-grub
                fi

                if [ -d /etc/update-motd.d ]; then
                    sudo chmod -x /etc/update-motd.d/*-updates-available 2>/dev/null
                    sudo chmod -x /etc/update-motd.d/*-release-upgrade 2>/dev/null
                    sudo chmod -x /etc/update-motd.d/*-reboot-required 2>/dev/null
                fi
                ;;

            ol|centos|rhel)

                if [ -f /etc/dnf/automatic.conf ]; then
                    sudo sed -i 's/^apply_updates = yes/apply_updates = no/' /etc/dnf/automatic.conf
                    sudo sed -i 's/^emit_via = .*/emit_via = none/' /etc/dnf/automatic.conf
                    sudo systemctl disable --now dnf-automatic.timer 2>/dev/null
                fi
                ;;

            *)
                log_warning "Sistema operacional não suportado para desabilitar notificações de kernel automaticamente"
                ;;
        esac

        update_state "KERNEL_NOTIFICATIONS_DISABLED" "true"
        log "Notificações de kernel desabilitadas com sucesso"
    else
        log "Pulando etapa de desabilitar notificações de kernel"
    fi
}

update_upgrade() {
    log "Atualizando os pacotes do sistema..."

    case $OS in
        debian|ubuntu)

            export DEBIAN_FRONTEND=noninteractive

            sudo apt-get update -y || {
                log_warning "Erro ao atualizar os pacotes, mas continuando..."
                true
            }

            sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || {
                log_warning "Erro ao fazer upgrade dos pacotes, mas continuando..."
                true
            }
            ;;

        ol|centos|rhel)
            sudo dnf check-update -y || {
                log_warning "Erro ao verificar atualizações, mas continuando..."
                true
            }

            sudo dnf upgrade -y --nobest || {
                log_warning "Erro ao fazer upgrade dos pacotes, mas continuando..."
                true
            }
            ;;

        *)
            log_warning "Sistema operacional não suportado para update/upgrade automatizado"
            return 1
            ;;
    esac

    log "Atualização e upgrade concluídos com sucesso"
    return 0
}

install_docker_debian() {
    log "Iniciando instalação do Docker no Debian..."

    cat > "$STATE_DIR/docker_install_debian.sh" <<'EOF'
#!/bin/bash

set -e

# Atualizar pacotes
apt-get update -y
apt-get install -y sudo gnupg2 wget ca-certificates apt-transport-https curl gnupg nano htop

# Adicionar o repositório Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Adicionar repositório ao sources.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

# Atualizar pacotes e instalar Docker
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Iniciar e habilitar serviços
systemctl enable --now docker
systemctl enable --now containerd
EOF

    chmod +x "$STATE_DIR/docker_install_debian.sh"

    sudo bash "$STATE_DIR/docker_install_debian.sh" || {
        log_error "Falha na instalação do Docker no Debian. Tentando recuperar..."

        if sudo which docker > /dev/null 2>&1; then
            log "Docker já está instalado, verificando se está funcionando..."
            if sudo docker version > /dev/null 2>&1; then
                log "Docker está funcionando corretamente"
                update_state "DOCKER_INSTALLED" "true"
                return 0
            else
                log "Docker está instalado mas não está funcionando. Tentando reparar..."
                sudo systemctl restart docker || {
                    log_error "Não foi possível reiniciar o Docker"
                    return 1
                }
            fi
        else
            log_error "Docker não está instalado. É necessário corrigir os erros manualmente."
            return 1
        fi
    }

    if sudo docker version > /dev/null 2>&1; then
        log "Docker instalado com sucesso no Debian"
        update_state "DOCKER_INSTALLED" "true"
        return 0
    else
        log_error "Docker não está funcionando após a instalação"
        return 1
    fi
}

install_docker_ubuntu() {
    log "Iniciando instalação do Docker no Ubuntu 20.04/22.04..."

    cat > "$STATE_DIR/docker_install_ubuntu.sh" <<'EOF'
#!/bin/bash

set -e

# Atualizar pacotes
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Adicionar chave GPG do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Adicionar repositório Docker ao sources.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Atualizar pacotes e instalar Docker
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Iniciar e habilitar serviços
systemctl enable --now docker
systemctl enable --now containerd
EOF

    chmod +x "$STATE_DIR/docker_install_ubuntu.sh"

    sudo bash "$STATE_DIR/docker_install_ubuntu.sh" || {
        log_error "Falha na instalação do Docker no Ubuntu. Tentando recuperar..."

        if sudo which docker > /dev/null 2>&1; then
            log "Docker já está instalado, verificando se está funcionando..."
            if sudo docker version > /dev/null 2>&1; then
                log "Docker está funcionando corretamente"
                update_state "DOCKER_INSTALLED" "true"
                return 0
            else
                log "Docker está instalado mas não está funcionando. Tentando reparar..."
                sudo systemctl restart docker || {
                    log_error "Não foi possível reiniciar o Docker"
                    return 1
                }
            fi
        else
            log_error "Docker não está instalado. É necessário corrigir os erros manualmente."
            return 1
        fi
    }

    if sudo docker version > /dev/null 2>&1; then
        log "Docker instalado com sucesso no Ubuntu 20.04/22.04"
        update_state "DOCKER_INSTALLED" "true"
        return 0
    else
        log_error "Docker não está funcionando após a instalação"
        return 1
    fi
}

install_docker_ubuntu24() {
    log "Iniciando instalação do Docker no Ubuntu 24.04..."

    cat > "$STATE_DIR/docker_install_ubuntu24.sh" <<'EOF'
#!/bin/bash

set -e

# Atualizar pacotes
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Adicionar chave GPG do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Adicionar repositório Docker ao sources.list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Atualizar pacotes e instalar Docker
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Iniciar e habilitar serviços
systemctl enable --now docker
systemctl enable --now containerd
EOF

    chmod +x "$STATE_DIR/docker_install_ubuntu24.sh"

    sudo bash "$STATE_DIR/docker_install_ubuntu24.sh" || {
        log_error "Falha na instalação do Docker no Ubuntu 24.04. Tentando recuperar..."

        if sudo which docker > /dev/null 2>&1; then
            log "Docker já está instalado, verificando se está funcionando..."
            if sudo docker version > /dev/null 2>&1; then
                log "Docker está funcionando corretamente"
                update_state "DOCKER_INSTALLED" "true"
                return 0
            else
                log "Docker está instalado mas não está funcionando. Tentando reparar..."
                sudo systemctl restart docker || {
                    log_error "Não foi possível reiniciar o Docker"
                    return 1
                }
            fi
        else
            log_error "Docker não está instalado. É necessário corrigir os erros manualmente."
            return 1
        fi
    }

    if sudo docker version > /dev/null 2>&1; then
        log "Docker instalado com sucesso no Ubuntu 24.04"
        update_state "DOCKER_INSTALLED" "true"
        return 0
    else
        log_error "Docker não está funcionando após a instalação"
        return 1
    fi
}

install_docker_oracle() {
    log "Iniciando instalação do Docker no Oracle Linux 8..."

    cat > "$STATE_DIR/docker_install_oracle.sh" <<'EOF'
#!/bin/bash

set -e

# Instalar dependências
dnf -y install dnf-utils device-mapper-persistent-data lvm2

# Adicionar repositório Docker
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

# Instalar Docker
dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Iniciar e habilitar serviços
systemctl enable --now docker
systemctl enable --now containerd
EOF

    chmod +x "$STATE_DIR/docker_install_oracle.sh"

    sudo bash "$STATE_DIR/docker_install_oracle.sh" || {
        log_error "Falha na instalação do Docker no Oracle Linux. Tentando recuperar..."

        if sudo which docker > /dev/null 2>&1; then
            log "Docker já está instalado, verificando se está funcionando..."
            if sudo docker version > /dev/null 2>&1; then
                log "Docker está funcionando corretamente"
                update_state "DOCKER_INSTALLED" "true"
                return 0
            else
                log "Docker está instalado mas não está funcionando. Tentando reparar..."
                sudo systemctl restart docker || {
                    log_error "Não foi possível reiniciar o Docker"
                    return 1
                }
            fi
        else
            log_error "Docker não está instalado. É necessário corrigir os erros manualmente."
            return 1
        fi
    }

    if sudo docker version > /dev/null 2>&1; then
        log "Docker instalado com sucesso no Oracle Linux 8"
        update_state "DOCKER_INSTALLED" "true"
        return 0
    else
        log_error "Docker não está funcionando após a instalação"
        return 1
    fi
}

setup_docker_permissions() {
    if check_step "DOCKER_PERMISSIONS_CONFIGURED" "Configuração de permissões do Docker"; then
        log "Configurando permissões do Docker para o usuário $SYSTEM_USER..."

        if ! sudo which docker > /dev/null 2>&1; then
            log_error "Docker não está instalado. Não é possível configurar permissões."
            return 1
        fi

        sudo groupadd docker 2>/dev/null || true

        sudo usermod -aG docker "$SYSTEM_USER" || {
            log_error "Falha ao adicionar usuário $SYSTEM_USER ao grupo docker"
            return 1
        }

        sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
        sudo chmod 660 /var/run/docker.sock 2>/dev/null || true

        if [ -d /var/lib/docker/volumes ]; then
            sudo chown -R root:docker /var/lib/docker/volumes || true
            sudo chmod -R 777 /var/lib/docker/volumes || true
        fi

        sudo systemctl restart docker || {
            log_error "Falha ao reiniciar o serviço Docker"
            return 1
        }

        update_state "DOCKER_PERMISSIONS_CONFIGURED" "true"
        log "Permissões do Docker configuradas com sucesso para o usuário $SYSTEM_USER."
        log "Para que as alterações tenham efeito, faça logout/login ou reinicie a sessão."
    else
        log "Pulando etapa de configuração de permissões do Docker"
    fi
}

setup_firewall() {
    if check_step "FIREWALL_CONFIGURED" "Configuração de firewall"; then
        log "Configurando regras de firewall com base no tipo de nodo..."

        swarm_ports=("2377/tcp" "7946/tcp" "7946/udp" "4789/udp")

        manager_ports=("9000/tcp" "9001/tcp" "80/tcp" "443/tcp" "8080/tcp")

        source "$STATE_FILE"

        if [ -z "$NODE_TYPE" ]; then
            echo -n "Qual tipo de nodo você está configurando? (manager/worker/database): "
            read -r node_type

            if [[ ! "$node_type" =~ ^(manager|worker|database)$ ]]; then
                log_error "Tipo de nodo inválido. Deve ser 'manager', 'worker' ou 'database'."
                return 1
            fi

            update_state "NODE_TYPE" "$node_type"
        else
            node_type="$NODE_TYPE"
        fi

        ports=("${swarm_ports[@]}")

        # Se for manager, adiciona as portas do Traefik e Portainer
        if [ "$node_type" = "manager" ]; then
            ports+=("${manager_ports[@]}")
            log "Configurando firewall para nodo manager com portas adicionais para Traefik e Portainer"
        else
            log "Configurando firewall para nodo $node_type apenas com portas do Swarm"
        fi

        if command -v ufw > /dev/null 2>&1; then

            ufw_status=$(sudo ufw status | grep "Status: " | awk '{print $2}')

            if [ "$ufw_status" = "inactive" ]; then
                log_warning "UFW está inativo. Para aplicar as regras, é necessário ativá-lo."
                echo -n "Deseja ativar o UFW após aplicar as regras? (y/n): "
                read -r activate_ufw
            fi

            for port in "${ports[@]}"; do
                sudo ufw allow "$port" || {
                    log_warning "Erro ao permitir a porta $port via ufw"
                    continue
                }
            done

            if [[ "$activate_ufw" =~ ^[Yy]$ ]]; then

                sudo ufw allow ssh
                sudo ufw --force enable
            fi

            log "Regras adicionadas via ufw."
        elif command -v firewall-cmd > /dev/null 2>&1; then

            firewalld_active=$(sudo systemctl is-active firewalld)

            if [ "$firewalld_active" != "active" ]; then
                log_warning "Firewalld não está ativo. Tentando iniciar..."
                sudo systemctl start firewalld || {
                    log_error "Não foi possível iniciar o firewalld"
                }
            fi

            for port in "${ports[@]}"; do
                sudo firewall-cmd --permanent --add-port="$port" || {
                    log_warning "Erro ao adicionar a porta $port via firewall-cmd"
                    continue
                }
            done

            sudo firewall-cmd --reload || {
                log_warning "Erro ao recarregar as regras do firewall-cmd"
            }

            log "Regras adicionadas via firewall-cmd."
        else

            for entry in "${ports[@]}"; do
                port=$(echo "$entry" | cut -d'/' -f1)
                proto=$(echo "$entry" | cut -d'/' -f2)
                sudo iptables -I INPUT -p "$proto" --dport "$port" -j ACCEPT || {
                    log_warning "Erro ao adicionar a regra iptables para a porta $port/$proto"
                    continue
                }
            done

            log "Regras adicionadas via iptables. Note que estas regras não são persistentes após reboot."

            if command -v apt-get > /dev/null 2>&1; then
                echo -n "Deseja instalar iptables-persistent para tornar as regras permanentes? (y/n): "
                read -r install_iptables_persistent

                if [[ "$install_iptables_persistent" =~ ^[Yy]$ ]]; then
                    export DEBIAN_FRONTEND=noninteractive
                    sudo apt-get update
                    sudo apt-get install -y iptables-persistent
                    sudo netfilter-persistent save
                    sudo netfilter-persistent reload
                    log "Regras de firewall salvas permanentemente com iptables-persistent."
                else
                    log_warning "Regras de firewall não serão persistentes após reinicialização."
                fi
            elif command -v dnf > /dev/null 2>&1 || command -v yum > /dev/null 2>&1; then
                echo -n "Deseja salvar as regras de iptables? (y/n): "
                read -r save_iptables

                if [[ "$save_iptables" =~ ^[Yy]$ ]]; then
                    sudo bash -c "iptables-save > /etc/sysconfig/iptables"
                    log "Regras de firewall salvas em /etc/sysconfig/iptables."
                else
                    log_warning "Regras de firewall não serão persistentes após reinicialização."
                fi
            fi
        fi

        update_state "FIREWALL_CONFIGURED" "true"
    else
        log "Pulando etapa de configuração de firewall"
    fi
}

setup_docker_swarm() {
    if check_step "SWARM_INITIALIZED" "Inicialização do Docker Swarm"; then
        log "Configurando o Docker Swarm..."

        swarm_active=$(sudo docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)

        if [ "$swarm_active" = "active" ]; then
            log "Docker Swarm já está ativo neste nodo."

            node_role=$(sudo docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)

            if [ "$node_role" = "true" ]; then
                log "Este nodo é um Manager no Swarm."
                update_state "SWARM_INITIALIZED" "true"
                return 0
            else
                log "Este nodo é um Worker no Swarm."
                update_state "SWARM_INITIALIZED" "true"
                return 0
            fi
        fi

        echo -n "Deseja configurar este nodo como parte de um Docker Swarm? (y/n): "
        read -r swarm_choice

        if [[ "$swarm_choice" =~ ^[Yy]$ ]]; then

            echo -n "Este nodo será um manager, um worker ou um database? (manager/worker/database): "
            read -r node_type

            if [[ ! "$node_type" =~ ^(manager|worker|database)$ ]]; then
                log_error "Tipo de nodo inválido. Deve ser 'manager', 'worker' ou 'database'."
                return 1
            fi

            update_state "NODE_TYPE" "$node_type"

            echo -n "Digite o endereço IP para anunciar no Swarm (ex: 192.168.1.100): "
            read -r advertise_addr

            if ! [[ $advertise_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_warning "Endereço IP não parece válido. Deseja continuar mesmo assim? (y/n): "
                read -r continue_anyway

                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    log_error "Configuração do Swarm cancelada."
                    return 1
                fi
            fi

            if [[ "$node_type" == "manager" ]]; then

                sudo docker swarm init --advertise-addr="$advertise_addr" || {
                    log_error "Falha ao inicializar o Swarm como Manager."
                    return 1
                }

                log "Swarm inicializado como Manager."
            else

                echo -n "Digite o comando completo de join fornecido pelo Manager (ex: docker swarm join --token ...): "
                read -r join_command

                eval sudo "$join_command" || {
                    log_error "Falha ao juntar-se ao Swarm. Verifique o comando de join."
                    return 1
                }

                log "Nodo $node_type juntou-se ao Swarm com sucesso."
            fi

            update_state "SWARM_INITIALIZED" "true"
        else
            log "Pulando inicialização do Docker Swarm."
        fi
    else
        log "Pulando etapa de inicialização do Docker Swarm"
    fi
}

setup_swarm_labels() {
    if check_step "SWARM_LABELS_CONFIGURED" "Configuração de labels no Docker Swarm"; then

        swarm_active=$(sudo docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)

        if [ "$swarm_active" != "active" ]; then
            log_warning "Docker Swarm não está ativo. Não é possível configurar labels."
            return 1
        fi

        node_role=$(sudo docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)

        if [ "$node_role" != "true" ]; then
            log_warning "Este nodo não é um Manager. As labels devem ser configuradas em um nodo Manager."
            echo -n "Deseja continuar mesmo assim? (y/n): "
            read -r continue_anyway

            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                log "Pulando configuração de labels."
                return 0
            fi
        fi

        echo -n "Deseja adicionar ou configurar labels no nodo? (y/n): "
        read -r add_labels

        if [[ "$add_labels" =~ ^[Yy]$ ]]; then

            echo -n "Digite a função do nodo (ex: backend, frontend, database): "
            read -r custom_role

            echo -n "Digite o ambiente do nodo (ex: production, staging, development): "
            read -r node.env

            echo -n "Digite a tier do nodo (ex: backend, frontend): "
            read -r node_tier

            echo -n "Digite a região do nodo (ex: us-east, eu-central): "
            read -r node_region

            current_node_id=$(sudo docker info --format '{{.Swarm.NodeID}}')

            if [ -z "$current_node_id" ]; then
                log_error "Não foi possível obter o ID do nodo atual."
                return 1
            fi

            log "ID do nodo atual: $current_node_id"

            sudo docker node update --label-add role="$custom_role" "$current_node_id" || {
                log_warning "Falha ao adicionar label 'role'"
            }

            sudo docker node update --label-add env="$node.env" "$current_node_id" || {
                log_warning "Falha ao adicionar label 'env'"
            }

            sudo docker node update --label-add tier="$node_tier" "$current_node_id" || {
                log_warning "Falha ao adicionar label 'tier'"
            }

            sudo docker node update --label-add region="$node_region" "$current_node_id" || {
                log_warning "Falha ao adicionar label 'region'"
            }

            log "Labels configuradas: role=$custom_role, env=$node.env, tier=$node_tier, region=$node_region"
            update_state "SWARM_LABELS_CONFIGURED" "true"
        else
            log "Pulando configuração de labels."
        fi
    else
        log "Pulando etapa de configuração de labels no Docker Swarm"
    fi
}

create_overlay_network() {
    if check_step "NETWORK_CREATED" "Criação de rede overlay para o Swarm"; then

        swarm_active=$(sudo docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)

        if [ "$swarm_active" != "active" ]; then
            log_warning "Docker Swarm não está ativo. Não é possível criar rede overlay."
            return 1
        fi

        node_role=$(sudo docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)

        if [ "$node_role" != "true" ]; then
            log_warning "Este nodo não é um Manager. A rede overlay deve ser criada em um nodo Manager."
            echo -n "Deseja continuar mesmo assim? (y/n): "
            read -r continue_anyway

            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                log "Pulando criação de rede overlay."
                return 0
            fi
        fi

        echo -n "Deseja criar uma rede overlay para o Swarm? (y/n): "
        read -r network_choice

        if [[ "$network_choice" =~ ^[Yy]$ ]]; then

            echo -n "Digite o nome da rede (deixe em branco para usar 'network_public' como padrão): "
            read -r network_name

            if [ -z "$network_name" ]; then
                network_name="network_public"
            fi

            if sudo docker network ls --format "{{.Name}}" | grep -q "^$network_name$"; then
                log "Rede '$network_name' já existe."
            else

                sudo docker network create --driver=overlay "$network_name" || {
                    log_error "Falha ao criar a rede overlay '$network_name'."
                    return 1
                }

                log "Rede '$network_name' criada com sucesso."
            fi

            update_state "NETWORK_CREATED" "true"
            update_state "NETWORK_NAME" "$network_name"
        else
            log "Pulando criação de rede overlay."
            update_state "NETWORK_NAME" "network_public"
        fi
    else
        log "Pulando etapa de criação de rede overlay para o Swarm"
    fi
}

install_traefik() {
    if check_step "TRAEFIK_INSTALLED" "Instalação do Traefik"; then

        swarm_active=$(sudo docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)

        if [ "$swarm_active" != "active" ]; then
            log_warning "Docker Swarm não está ativo. Não é possível instalar o Traefik como um serviço do Swarm."
            return 1
        fi

        node_role=$(sudo docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)

        if [ "$node_role" != "true" ]; then
            log_warning "Este nodo não é um Manager. O Traefik deve ser instalado em um nodo Manager."
            echo -n "Deseja continuar mesmo assim? (y/n): "
            read -r continue_anyway

            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                log "Pulando instalação do Traefik."
                return 0
            fi
        fi

        source "$STATE_FILE"

        if [ -z "$NETWORK_NAME" ]; then
            NETWORK_NAME="network_public"
            log_warning "Nome da rede não definido, usando '$NETWORK_NAME' como padrão."
        fi

        if ! sudo docker network ls --format "{{.Name}}" | grep -q "^$NETWORK_NAME$"; then
            log_warning "Rede '$NETWORK_NAME' não existe. Tentando criar..."
            sudo docker network create --driver=overlay "$NETWORK_NAME" || {
                log_error "Falha ao criar a rede overlay '$NETWORK_NAME'."
                return 1
            }
        fi

        echo -n "Deseja instalar e configurar o Traefik como um proxy reverso com Let's Encrypt no Swarm? (y/n): "
        read -r traefik_choice

        if [[ "$traefik_choice" =~ ^[Yy]$ ]]; then
            echo -n "Digite o e-mail para usar com Let's Encrypt: "
            read -r traefik_email

            if ! [[ "$traefik_email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                log_warning "O e-mail não parece válido. Deseja continuar mesmo assim? (y/n): "
                read -r continue_anyway

                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    log_error "Instalação do Traefik cancelada."
                    return 1
                fi
            fi

            echo -n "Qual nodo deve rodar o Traefik? (manager): "
            read -r traefik_node

            if [[ ! "$traefik_node" =~ ^(manager)$ ]]; then
                log_error "Tipo de nodo inválido. Deve ser 'manager'."
                return 1
            fi

            echo -n "Deseja habilitar o dashboard do Traefik? (y/n): "
            read -r enable_dashboard

            if ! sudo docker volume ls --format "{{.Name}}" | grep -q "^volume_certificates$"; then
                sudo docker volume create volume_certificates || {
                    log_error "Falha ao criar o volume 'volume_certificates'."
                    return 1
                }
                log "Volume 'volume_certificates' criado com sucesso."
            else
                log "Volume 'volume_certificates' já existe."
            fi

            if [[ "$enable_dashboard" =~ ^[Yy]$ ]]; then
                cat > "$STATE_DIR/traefik.yaml" <<EOF
version: '3.7'
services:
  traefik:
    image: traefik:v3.0.1
    hostname: "{{.Service.Name}}.{{.Task.Slot}}"
    command:
      - "--api.dashboard=true"
      - "--api.insecure=true"
      - "--providers.swarm.endpoint=unix:///var/run/docker.sock"
      - "--providers.swarm.exposedByDefault=false"
      - "--providers.swarm.network=${NETWORK_NAME}"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencryptresolver.acme.email=${traefik_email}"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--log.level=DEBUG"
      - "--log.format=common"
      - "--log.filePath=/var/log/traefik/traefik.log"
      - "--accesslog=true"
      - "--accesslog.filepath=/var/log/traefik/access-log"
    deploy:
      placement:
        constraints:
          - "node.role == ${traefik_node}"
      labels:
        - traefik.enable=true
        - traefik.http.middlewares.gzip.compress=true
        - traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
        - traefik.http.routers.http-catchall.rule=hostregexp(\`{host:.+}\`)
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-https@docker
        - traefik.http.routers.http-catchall.priority=1
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "volume_certificates:/etc/traefik/letsencrypt"
    networks:
      - ${NETWORK_NAME}
    ports:
      - target: 80
        published: 80
        mode: host
      - target: 443
        published: 443
        mode: host
      - target: 8080
        published: 8080
        mode: host
volumes:
  volume_certificates:
    external: true
    name: volume_certificates
networks:
  ${NETWORK_NAME}:
    external: true
    name: ${NETWORK_NAME}
EOF
            else
                cat > "$STATE_DIR/traefik.yaml" <<EOF
version: '3.7'
services:
  traefik:
    image: traefik:v3.0.1
    hostname: "{{.Service.Name}}.{{.Task.Slot}}"
    command:
      - "--api.dashboard=false"
      - "--providers.swarm.endpoint=unix:///var/run/docker.sock"
      - "--providers.swarm.exposedByDefault=false"
      - "--providers.swarm.network=${NETWORK_NAME}"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencryptresolver.acme.email=${traefik_email}"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--log.level=DEBUG"
      - "--log.format=common"
      - "--log.filePath=/var/log/traefik/traefik.log"
      - "--accesslog=true"
      - "--accesslog.filepath=/var/log/traefik/access-log"
    deploy:
      placement:
        constraints:
          - "node.role == ${traefik_node}"
      labels:
        - traefik.enable=true
        - traefik.http.middlewares.gzip.compress=true
        - traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
        - traefik.http.routers.http-catchall.rule=hostregexp(\`{host:.+}\`)
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-https@docker
        - traefik.http.routers.http-catchall.priority=1
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "volume_certificates:/etc/traefik/letsencrypt"
    networks:
      - ${NETWORK_NAME}
    ports:
      - target: 80
        published: 80
        mode: host
      - target: 443
        published: 443
        mode: host
volumes:
  volume_certificates:
    external: true
    name: volume_certificates
networks:
  ${NETWORK_NAME}:
    external: true
    name: ${NETWORK_NAME}
EOF
            fi

            log "Implantando o Traefik no Docker Swarm..."
            log "Arquivo de configuração: $STATE_DIR/traefik.yaml"

            if [ ! -f "$STATE_DIR/traefik.yaml" ]; then
                log_error "Arquivo traefik.yaml não foi criado."
                return 1
            fi

            sudo docker stack deploy --prune --resolve-image always -c "$STATE_DIR/traefik.yaml" traefik || {
                log_error "Falha ao implantar o Traefik."
                log_error "Verifique o arquivo $STATE_DIR/traefik.yaml para possíveis erros de sintaxe."
                return 1
            }

            if sudo docker service ls --format "{{.Name}}" | grep -q "^traefik_traefik$"; then
                log "Traefik implantado com sucesso."
                update_state "TRAEFIK_INSTALLED" "true"

                if [[ "$enable_dashboard" =~ ^[Yy]$ ]]; then
                    log "Para acessar o dashboard do Traefik, navegue para http://<Seu_Domain_ou_IP_Publico>:8080/dashboard/ em seu navegador."
                fi
            else
                log_error "Falha ao verificar o serviço do Traefik após implantação."
                return 1
            fi
        else
            log "Pulando instalação do Traefik."
        fi
    else
        log "Pulando etapa de instalação do Traefik"
    fi
}

install_portainer() {
    if check_step "PORTAINER_INSTALLED" "Instalação do Portainer"; then
        swarm_active=$(sudo docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)

        if [ "$swarm_active" != "active" ]; then
            log_warning "Docker Swarm não está ativo. Não é possível instalar o Portainer como um serviço do Swarm."
            return 1
        fi

        node_role=$(sudo docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)

        if [ "$node_role" != "true" ]; then
            log_warning "Este nodo não é um Manager. O Portainer deve ser instalado em um nodo Manager."
            echo -n "Deseja continuar mesmo assim? (y/n): "
            read -r continue_anyway

            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                log "Pulando instalação do Portainer."
                return 0
            fi
        fi

        source "$STATE_FILE"

        if [ -z "$NETWORK_NAME" ]; then
            NETWORK_NAME="network_public"
            log_warning "Nome da rede não definido, usando '$NETWORK_NAME' como padrão."
        fi

        if ! sudo docker network ls --format "{{.Name}}" | grep -q "^$NETWORK_NAME$"; then
            log_warning "Rede '$NETWORK_NAME' não existe. Tentando criar..."
            sudo docker network create --driver=overlay "$NETWORK_NAME" || {
                log_error "Falha ao criar a rede overlay '$NETWORK_NAME'."
                return 1
            }
        fi

        echo -n "Deseja instalar e configurar o Portainer para gerenciamento do Docker Swarm? (y/n): "
        read -r portainer_choice

        if [[ "$portainer_choice" =~ ^[Yy]$ ]]; then
            echo -n "Qual nodo deve rodar o Portainer? (manager): "
            read -r portainer_node

            if [[ ! "$portainer_node" =~ ^(manager)$ ]]; then
                log_error "Tipo de nodo inválido. Deve ser 'manager'."
                return 1
            fi

            echo -n "Digite o domínio para acessar o Portainer (ex: portainer.meudominio.com): "
            read -r portainer_domain

            if ! [[ "$portainer_domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                log_warning "O domínio não parece válido. Deseja continuar mesmo assim? (y/n): "
                read -r continue_anyway

                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    log_error "Instalação do Portainer cancelada."
                    return 1
                fi
            fi

            if ! sudo docker volume ls --format "{{.Name}}" | grep -q "^portainer_data$"; then
                sudo docker volume create portainer_data || {
                    log_error "Falha ao criar o volume 'portainer_data'."
                    return 1
                }
                log "Volume 'portainer_data' criado com sucesso."
            else
                log "Volume 'portainer_data' já existe."
            fi

            cat > "$STATE_DIR/portainer.yaml" <<EOF
version: "3.7"
services:
  agent:
    image: portainer/agent:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks:
      - ${NETWORK_NAME}
    deploy:
      mode: global
      placement:
        constraints: [node.platform.os == linux]
  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://tasks.agent:9001 --tlsskipverify
    volumes:
      - portainer_data:/data
    networks:
      - ${NETWORK_NAME}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: ["node.role == ${portainer_node}"]
      labels:
        - "traefik.enable=true"
        - "traefik.docker.network=${NETWORK_NAME}"
        - "traefik.http.routers.portainer.rule=Host(\`${portainer_domain}\`)"
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.priority=1"
        - "traefik.http.routers.portainer.tls.certresolver=letsencryptresolver"
        - "traefik.http.routers.portainer.service=portainer"
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"
networks:
  ${NETWORK_NAME}:
    external: true
    name: ${NETWORK_NAME}
volumes:
  portainer_data:
    external: true
    name: portainer_data
EOF

            log "Implantando o Portainer no Docker Swarm..."
            log "Arquivo de configuração: $STATE_DIR/portainer.yaml"

            if [ ! -f "$STATE_DIR/portainer.yaml" ]; then
                log_error "Arquivo portainer.yaml não foi criado."
                return 1
            fi

            sudo docker stack deploy --prune --resolve-image always -c "$STATE_DIR/portainer.yaml" portainer || {
                log_error "Falha ao implantar o Portainer."
                log_error "Verifique o arquivo $STATE_DIR/portainer.yaml para possíveis erros de sintaxe."
                return 1
            }

            if sudo docker service ls --format "{{.Name}}" | grep -q "^portainer_portainer$"; then
                log "Portainer implantado com sucesso e acessível através de https://${portainer_domain}"
                log "Acesse o Portainer em até 5 minutos para criar as credenciais de acesso. Caso contrário, será necessário reinstalar o Portainer, removendo o volume antes de instalar novamente."
                update_state "PORTAINER_INSTALLED" "true"
            else
                log_error "Falha ao verificar o serviço do Portainer após implantação."
                return 1
            fi
        else
            log "Pulando instalação do Portainer."
        fi
    else
        log "Pulando etapa de instalação do Portainer"
    fi
}

main() {
    initialize.environment

    show_logo

    echo "Digite o nome do usuário do sistema para configurar as permissões do Docker (deixe em branco para detectar automaticamente):"
    read -r system_user_input

    if [ -z "$system_user_input" ]; then
        if [ -n "$SUDO_USER" ]; then
            SYSTEM_USER="$SUDO_USER"
        else
            SYSTEM_USER="$USER"
        fi
    else
        SYSTEM_USER="$system_user_input"
    fi

    update_state "SYSTEM_USER" "$SYSTEM_USER"
    log "Usuário do sistema selecionado: $SYSTEM_USER"

    log "Detectando o sistema operacional..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        OS=$(uname -s)
    fi

    echo "Sistema operacional detectado: $OS"
    if [ "$OS" == "ubuntu" ]; then
        echo "Versão do Ubuntu: $VERSION"
    fi

    show_logo
    echo -n "Deseja desabilitar as notificações de atualização do kernel? (y/n): "
    read -r disable_notifications

    if [[ "$disable_notifications" =~ ^[Yy]$ ]]; then
        disable_kernel_notifications
    else
        log "Pulando desativação de notificações de kernel."
    fi

    show_logo
    if [ "$OS_CHOICE" -eq 0 ]; then
        log "Iniciando a seleção do sistema operacional para instalação do Docker."
        echo "Escolha a opção correspondente:"
        echo "1 - Debian 11/12"
        echo "2 - Ubuntu 20.04/22.04"
        echo "3 - Oracle Linux 8"
        echo "4 - Ubuntu 24.04"
        read -r os_choice

        if [[ "$os_choice" =~ ^[1-4]$ ]]; then
            update_state "OS_CHOICE" "$os_choice"
        else
            log_error "Opção inválida. Saindo..."
            exit 1
        fi
    else
        os_choice=$OS_CHOICE
        log "Usando escolha de sistema operacional armazenada: $os_choice"
    fi

    show_logo
    echo -n "Deseja atualizar e fazer upgrade dos pacotes do sistema? (y/n): "
    read -r update_choice

    if [[ "$update_choice" =~ ^[Yy]$ ]]; then
        update_upgrade
    else
        log "Pulando atualização e upgrade de pacotes."
    fi

    show_logo
    if ! check_step "DOCKER_INSTALLED" "Instalação do Docker"; then
        log "Docker já está instalado. Pulando instalação."
    else
        case $os_choice in
            1)
                log "Instalando o Docker no Debian 11/12..."
                install_docker_debian
                ;;
            2)
                log "Instalando o Docker no Ubuntu 20.04/22.04..."
                install_docker_ubuntu
                ;;
            3)
                log "Instalando o Docker no Oracle Linux 8..."
                install_docker_oracle
                ;;
            4)
                log "Instalando o Docker no Ubuntu 24.04..."
                install_docker_ubuntu24
                ;;
            *)
                show_logo
                log_error "Opção inválida. Saindo..."
                exit 1
                ;;
        esac
    fi

    show_logo
    echo -n "Deseja configurar as permissões do Docker para o usuário $SYSTEM_USER? (y/n): "
    read -r docker_perm_choice

    if [[ "$docker_perm_choice" =~ ^[Yy]$ ]]; then
        setup_docker_permissions
    else
        log "Pulando configuração de permissões do Docker."
    fi

    show_logo
    echo -n "Deseja configurar as regras de firewall para Docker Swarm? (y/n): "
    read -r firewall_choice

    if [[ "$firewall_choice" =~ ^[Yy]$ ]]; then
        setup_firewall
    else
        log "Pulando configuração das regras de firewall."
    fi

    show_logo
    setup_docker_swarm

    source "$STATE_FILE"
    if [ "$SWARM_INITIALIZED" = "true" ]; then
        show_logo
        setup_swarm_labels

        show_logo
        create_overlay_network

        node_role=$(sudo docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)

        if [ "$node_role" = "true" ]; then
            show_logo
            install_traefik

            show_logo
            install_portainer
        else
            log "Este nodo não é um Manager. Pulando instalação de Traefik e Portainer."
        fi
    fi

    show_logo
    log "Instalação concluída com sucesso!"
    log "Resumo:"
    log "- Docker instalado: $DOCKER_INSTALLED"
    log "- Permissões configuradas: $DOCKER_PERMISSIONS_CONFIGURED"
    log "- Firewall configurado: $FIREWALL_CONFIGURED"
    log "- Swarm inicializado: $SWARM_INITIALIZED"

    if [ "$SWARM_INITIALIZED" = "true" ]; then
        log "- Labels configuradas: $SWARM_LABELS_CONFIGURED"
        log "- Rede configurada: $NETWORK_CREATED (Nome: $NETWORK_NAME)"
        log "- Traefik instalado: $TRAEFIK_INSTALLED"
        log "- Portainer instalado: $PORTAINER_INSTALLED"
    fi

    log "Para verificar ou modificar o estado da instalação, verifique o arquivo $STATE_FILE"

    if [ "$DOCKER_PERMISSIONS_CONFIGURED" = "true" ]; then
        log_warning "Lembre-se de fazer logout/login para que as permissões do Docker tenham efeito."
    fi
}

main
