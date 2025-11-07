# 🚀 Instalador Automático Docker Swarm

<p align="center">
  <img src="https://raw.githubusercontent.com/DinastIA-UK/use-dinastiapi/main/dinastiapi.svg" alt="DinastiAPI" width="120" height="120">
</p>

<p align="center">
  <strong>Instalador completo e automatizado de cluster Docker Swarm com Traefik e Portainer</strong>
</p>

---

## 📋 Sobre o Instalador

Este é um instalador completo e interativo que configura automaticamente um ambiente Docker Swarm pronto para produção em sua VPS. O script foi desenvolvido para simplificar o processo de configuração de clusters Docker, incluindo todas as ferramentas necessárias para gerenciamento e deploy de aplicações.

### ✨ Recursos Incluídos

- ✅ **Docker Engine** - Instalação completa do Docker CE
- ✅ **Docker Swarm** - Configuração de cluster (Manager/Worker/Database)
- ✅ **Traefik v3** - Proxy reverso com SSL automático (Let's Encrypt)
- ✅ **Portainer CE** - Interface web para gerenciamento do Swarm
- ✅ **Firewall** - Configuração automática de portas necessárias
- ✅ **Permissões** - Configuração de usuário para uso do Docker
- ✅ **Labels** - Sistema de labels para orquestração de serviços
- ✅ **Network Overlay** - Rede overlay para comunicação entre containers
- ✅ **State Management** - Sistema de estado para instalação retomável

---

## 🖥️ Sistemas Operacionais Suportados

- **Debian 11/12**
- **Ubuntu 20.04 LTS**
- **Ubuntu 22.04 LTS**
- **Ubuntu 24.04 LTS**
- **Oracle Linux 8**

---

## 📱 Passo 1: Conectar à VPS usando Terminus

### Baixar e Instalar o Terminus

1. **Download do Terminus:**
   - 🍎 **macOS**: [Download para Mac](https://github.com/Eugeny/tabby/releases)
   - 🪟 **Windows**: [Download para Windows](https://github.com/Eugeny/tabby/releases)
   - 🐧 **Linux**: [Download para Linux](https://github.com/Eugeny/tabby/releases)

2. **Instalar o aplicativo** seguindo as instruções do seu sistema operacional

### Configurar Conexão SSH

1. Abra o **Terminus (Tabby)**
2. Clique em **"+ New Profile"** ou pressione `Ctrl+T` (Windows/Linux) ou `Cmd+T` (Mac)
3. Selecione **"SSH"**
4. Preencha os dados da sua VPS:

```
Host: seu-servidor.com (ou IP: 192.168.1.100)
Port: 22
User: root (ou seu usuário)
```

5. Escolha o método de autenticação:
   - **Password**: Digite sua senha
   - **SSH Key**: Selecione sua chave privada (recomendado)

6. Clique em **"Save"** e depois **"Connect"**

### Exemplo de Conexão Manual via Terminal

Se preferir usar o terminal nativo:

```bash
# Conectar via SSH
ssh root@seu-servidor.com

# Ou com IP
ssh root@192.168.1.100

# Com porta customizada
ssh -p 2222 root@seu-servidor.com
```

---

## 🚀 Passo 2: Executar o Instalador

### Instalação com Um Comando (Recomendado)

Após conectar à VPS via SSH, execute o comando abaixo:

```bash
curl -fsSL https://raw.githubusercontent.com/DinastIA-UK/use-dinastiapi/main/VPS/instalar-docker-swarm.sh | bash
```

### Instalação Manual (Alternativa)

Se preferir revisar o script antes de executar:

```bash
# 1. Baixar o script
curl -fsSL https://raw.githubusercontent.com/DinastIA-UK/use-dinastiapi/main/VPS/instalar-docker-swarm.sh -o instalar-docker-swarm.sh

# 2. Dar permissão de execução
chmod +x instalar-docker-swarm.sh

# 3. Executar o instalador
./instalar-docker-swarm.sh
```

---

## 📖 Processo de Instalação

O instalador é **interativo** e guiará você através das seguintes etapas:

### 1️⃣ Seleção do Sistema Operacional
```
Escolha a opção correspondente:
1 - Debian 11/12
2 - Ubuntu 20.04/22.04
3 - Oracle Linux 8
4 - Ubuntu 24.04
```

### 2️⃣ Atualização do Sistema
```
Deseja atualizar e fazer upgrade dos pacotes do sistema? (y/n):
```

### 3️⃣ Instalação do Docker
O script instalará automaticamente o Docker CE compatível com seu sistema

### 4️⃣ Configuração de Permissões
```
Deseja configurar as permissões do Docker para o usuário? (y/n):
```

### 5️⃣ Configuração de Firewall
```
Deseja configurar as regras de firewall para Docker Swarm? (y/n):
Qual tipo de nodo você está configurando? (manager/worker/database):
```

**Portas abertas automaticamente:**

**Para todos os nodos (Swarm):**
- `2377/tcp` - Comunicação do cluster
- `7946/tcp` - Descoberta de nodos
- `7946/udp` - Descoberta de nodos
- `4789/udp` - Rede overlay

**Apenas para Manager:**
- `80/tcp` - HTTP (Traefik)
- `443/tcp` - HTTPS (Traefik)
- `8080/tcp` - Dashboard Traefik
- `9000/tcp` - Portainer UI
- `9001/tcp` - Portainer Agent

### 6️⃣ Inicialização do Swarm
```
Deseja configurar este nodo como parte de um Docker Swarm? (y/n):
Este nodo será um manager, um worker ou um database? (manager/worker/database):
Digite o endereço IP para anunciar no Swarm (ex: 192.168.1.100):
```

**Para Workers/Database:**
```
Digite o comando completo de join fornecido pelo Manager:
docker swarm join --token SWMTKN-1-xxx... 192.168.1.100:2377
```

### 7️⃣ Configuração de Labels
```
Deseja adicionar ou configurar labels no nodo? (y/n):
Digite a função do nodo (ex: backend, frontend, database):
Digite o ambiente do nodo (ex: production, staging, development):
Digite a tier do nodo (ex: backend, frontend):
Digite a região do nodo (ex: us-east, eu-central):
```

### 8️⃣ Criação de Rede Overlay
```
Deseja criar uma rede overlay para o Swarm? (y/n):
Digite o nome da rede (deixe em branco para usar 'network_public'):
```

### 9️⃣ Instalação do Traefik (apenas Manager)
```
Deseja instalar e configurar o Traefik como proxy reverso com Let's Encrypt? (y/n):
Digite o e-mail para usar com Let's Encrypt:
Deseja habilitar o dashboard do Traefik? (y/n):
```

### 🔟 Instalação do Portainer (apenas Manager)
```
Deseja instalar e configurar o Portainer para gerenciamento do Docker Swarm? (y/n):
Digite o domínio para acessar o Portainer (ex: portainer.meudominio.com):
```

---

## ✅ Pós-Instalação

### Verificar Instalação do Docker

```bash
# Verificar versão do Docker
docker --version

# Verificar status do Docker
sudo systemctl status docker

# Testar Docker (sem sudo se configurou permissões)
docker ps
```

### Verificar Status do Swarm

```bash
# Ver informações do Swarm
docker info | grep Swarm

# Listar nodos (apenas no Manager)
docker node ls

# Ver detalhes do nodo atual
docker node inspect self --pretty
```

### Verificar Serviços (apenas no Manager)

```bash
# Listar stacks
docker stack ls

# Listar serviços
docker service ls

# Ver logs do Traefik
docker service logs traefik_traefik

# Ver logs do Portainer
docker service logs portainer_portainer
```

### Acessar Interfaces Web

**Traefik Dashboard** (se habilitado):
```
http://seu-ip-ou-dominio:8080/dashboard/
```

**Portainer**:
```
https://portainer.seudominio.com
```

⚠️ **IMPORTANTE**: Você tem **5 minutos** após a instalação do Portainer para criar as credenciais de administrador. Após esse tempo, será necessário reinstalar.

---

## 🔧 Arquivos de Estado e Logs

O instalador mantém um sistema de estado que permite retomar a instalação caso seja interrompida:

```bash
# Diretório de estado
~/.setup_state/

# Arquivo de configuração
~/.setup_state/installation_state.conf

# Logs da instalação
~/.setup_state/setup.log
```

### Ver Logs em Tempo Real

```bash
tail -f ~/.setup_state/setup.log
```

### Resetar Estado (Reinstalar do Zero)

```bash
rm -rf ~/.setup_state/
```

---

## 🆘 Troubleshooting

### Docker não inicia após instalação

```bash
# Verificar status
sudo systemctl status docker

# Reiniciar Docker
sudo systemctl restart docker

# Ver logs
sudo journalctl -u docker -n 50
```

### Permissões negadas ao executar Docker

```bash
# Fazer logout e login novamente
exit
# Reconectar via SSH

# Ou forçar atualização de grupos
newgrp docker
```

### Swarm não inicializa

```bash
# Verificar se já existe um Swarm ativo
docker info | grep "Swarm: active"

# Se necessário, sair do Swarm
docker swarm leave --force

# Reiniciar o processo
./instalar-docker-swarm.sh
```

### Traefik não está respondendo

```bash
# Verificar se o serviço está rodando
docker service ls | grep traefik

# Ver logs
docker service logs traefik_traefik --tail 100

# Verificar se as portas estão abertas
sudo netstat -tlnp | grep -E '80|443|8080'
```

### Portainer não acessível

```bash
# Verificar serviço
docker service ls | grep portainer

# Ver logs
docker service logs portainer_portainer --tail 100

# Remover e reinstalar se necessário
docker stack rm portainer
# Aguardar 30 segundos
sleep 30
# Executar novamente a parte do Portainer no script
```

### Firewall bloqueando portas

```bash
# Ubuntu/Debian com UFW
sudo ufw status
sudo ufw allow 2377/tcp
sudo ufw allow 7946/tcp
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp
sudo ufw reload

# Oracle Linux com firewalld
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-port=2377/tcp
sudo firewall-cmd --reload
```

---

## 🔐 Comandos Úteis do Docker Swarm

### Gerenciamento de Nodos

```bash
# Listar nodos
docker node ls

# Promover Worker para Manager
docker node promote <node-id>

# Rebaixar Manager para Worker
docker node demote <node-id>

# Remover nodo
docker node rm <node-id>

# Atualizar labels de um nodo
docker node update --label-add role=backend <node-id>
```

### Gerenciamento de Stacks

```bash
# Deploy de uma stack
docker stack deploy -c docker-compose.yml minha-stack

# Listar stacks
docker stack ls

# Listar serviços de uma stack
docker stack services minha-stack

# Remover stack
docker stack rm minha-stack
```

### Obter Token de Join

```bash
# Token para Manager
docker swarm join-token manager

# Token para Worker
docker swarm join-token worker
```

---

## 📚 Próximos Passos

Após a instalação bem-sucedida:

1. **Configure seu DNS** apontando para o IP da VPS
2. **Acesse o Portainer** e configure seus repositórios
3. **Deploy suas aplicações** usando Docker Compose/Stack
4. **Configure backups** dos volumes Docker
5. **Monitore** os logs e métricas das aplicações

---

## 🤝 Suporte

- 📧 **Email**: suporte@dinastiapi.com
- 🌐 **Website**: https://dinastiapi.com
- 📖 **Documentação**: https://api.dinastiapi.com/api

---

## 📝 Licença

Este instalador é fornecido pela **DinastiAPI** e está disponível para uso em ambientes de produção.

---

<p align="center">
  Desenvolvido com ❤️ por <strong>Guilherme Jansen</strong> | DinastiAPI
</p>
