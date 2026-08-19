#!/usr/bin/env bash
# ============================================================================
#  Setup Automatizado — Instalador Completo de Cluster Docker Swarm
# ============================================================================
#  Autor:    Guilherme Jansen  ·  Setup Automatizado LTDA
#  Versão:   3.0.0
#  Licença:  MIT
#
#  COMPATIBILIDADE (detecção automática, sem menu de SO):
#    • Debian        11 bullseye · 12 bookworm · 13 trixie · testing/sid
#    • Ubuntu        20.04 focal → 26.04 resolute (todas as intermediárias)
#    • Derivados deb Linux Mint · Pop!_OS · Zorin · elementary · KDE neon ·
#                    Kali · Raspberry Pi OS · Devuan · MX Linux
#    • RHEL family   RHEL/CentOS/Rocky/AlmaLinux/Oracle Linux 8 · 9 · 10
#    • Fedora        38 → 44
#    • Amazon Linux  2023 (repo próprio da AWS)
#    • SUSE          SLES 15 (repo Docker) · openSUSE Leap/Tumbleweed (repo distro)
#    • Arch family   Arch · Manjaro · EndeavourOS
#    • Alpine        3.x (OpenRC, sem systemd)
#    • Qualquer outro → fallback para o script oficial https://get.docker.com
#
#  COMO A COMPATIBILIDADE É GARANTIDA (sem lista estática a apodrecer):
#    O instalador NÃO adivinha o codename do repositório. Ele monta uma lista
#    ordenada de candidatos a partir de /etc/os-release e SONDA o índice real
#    em download.docker.com (HTTP HEAD no arquivo Release / no diretório da
#    major). O primeiro que responder 200 é usado. Quando o Docker publicar o
#    Debian 14 "forky" ou o Ubuntu 26.10, este script passa a funcionar neles
#    sem nenhuma alteração de código.
#
#  USO:
#    sudo bash instalar-docker-swarm.sh              # interativo (recomendado)
#    sudo bash instalar-docker-swarm.sh --status     # só mostra o estado
#    sudo bash instalar-docker-swarm.sh --doctor     # diagnóstico do cluster
#    sudo bash instalar-docker-swarm.sh --help       # todas as flags
#    curl -fsSL <url> | sudo bash                    # suportado (lê do /dev/tty)
#
#  ARQUIVOS:
#    ~/.setup_state/installation_state.conf   estado (retomável)
#    ~/.setup_state/setup.log                 log completo
#    ~/.setup_state/swarm-tokens.txt          tokens de join (chmod 600)
#
# ----------------------------------------------------------------------------
#  CHANGELOG
# ----------------------------------------------------------------------------
#  v3.0.0
#    ── Correções de bugs que quebravam a execução ──
#    - FIX CRÍTICO: `[ "$OS_CHOICE" -eq 0 ]` estourava
#      `integer expression expected` quando OS_CHOICE vinha vazio de um
#      state file antigo; o `else` era tomado, os_choice ficava vazio e o
#      `case` caía no `*)` → "Opção inválida. Saindo...". O menu manual de SO
#      foi REMOVIDO por completo: a detecção agora é automática.
#    - FIX CRÍTICO: `update_state()` usava `sed s/^KEY=.*/KEY=v/` e virava
#      no-op silencioso quando a chave não existia no arquivo (origem do
#      OS_CHOICE vazio). Agora faz append-se-ausente e escapa o valor.
#    - FIX: `read -r node.env` — `node.env` não é identificador válido em
#      bash; o read falhava e a label virava `env=.env`. Renomeado.
#    - FIX: `initialize.environment` → `initialize_environment`.
#    - FIX: `sed -i 's/\r$//' "$0"` reescrevia o próprio script em execução.
#      Removido.
#    - FIX: `gpg --dearmor -o` aborta se o arquivo já existe (`set -e`), o que
#      quebrava toda re-execução. Agora é idempotente.
#    - FIX: prompts liam de stdin, o que inviabilizava `curl … | bash`
#      (o script era consumido como resposta). Agora leem de /dev/tty.
#    ── Correções de Traefik v3 + Swarm ──
#    - FIX: `traefik.docker.network` não é lido pelo provider Swarm do v3 →
#      `traefik.swarm.network`.
#    - FIX: referência a middleware com sufixo `@docker` não resolve sob o
#      provider Swarm (router é descartado em silêncio) → middlewares inline.
#    - FIX: `hostregexp(\`{host:.+}\`)` é sintaxe do v2 e não compila no v3.
#      O router catch-all foi eliminado — a redireção HTTP→HTTPS já é feita no
#      entrypoint, que é o caminho suportado.
#    - FIX: dashboard com `--api.insecure=true` publicado na 8080 em modo host
#      expunha o painel do Traefik sem autenticação para a internet inteira.
#      Agora é opcional, atrás de HTTPS + BasicAuth + regra de Host.
#    ── Segurança ──
#    - `chmod -R 777 /var/lib/docker/volumes` removido.
#    - Portas do plano de controle do Swarm (2377/7946/4789) deixam de ser
#      abertas para 0.0.0.0 e passam a aceitar só os peers do cluster.
#    - 9000/9001 não são mais publicadas (Portainer entra pelo Traefik; a
#      9001 do agent é interna à overlay).
#    - Firewall aplicado com auto-rollback temporizado: se você perder o
#      acesso, as regras voltam sozinhas em 120s.
#    - Hardening SSH só roda depois de confirmar que existe chave em
#      authorized_keys (evita lockout).
#    ── Operação ──
#    - daemon.json com rotação de log (o padrão sem rotação enche o disco).
#    - Tokens de join impressos e salvos em arquivo 600.
#    - Flags --status, --doctor, --reset, --non-interactive, --dry-run.
#    - `set -uo pipefail`, trap de ERR/INT, shellcheck limpo.
# ============================================================================

set -uo pipefail
IFS=$' \t\n'

# ============================================================================
#  ┌──────────────────────────────────────────────────────────────────────┐
#  │  PERFIL DO CLUSTER — ÚNICO BLOCO QUE VOCÊ PRECISA EDITAR              │
#  └──────────────────────────────────────────────────────────────────────┘
#
#  Tudo abaixo deste bloco é genérico e não deve ser alterado por instalação.
#  Deixe os arrays VAZIOS para o modo genérico: o instalador pergunta o que
#  precisar e descobre o resto sozinho.
#
#  Alternativa a editar o arquivo: crie /etc/swarm-installer.conf (ou passe
#  --profile <arquivo>) com as mesmas variáveis. O arquivo externo vence.
# ============================================================================

CLUSTER_PROFILE_NAME="${CLUSTER_PROFILE_NAME:-generico}"

# Peers do cluster no formato "IP:hostname" (hostname opcional).
# Usados para (a) restringir as portas do Swarm no firewall e (b) popular
# /etc/hosts. Vazio = o instalador pergunta / descobre via `docker node ls`.
#   Ex.: CLUSTER_PEERS=( "10.0.0.10:mgr1" "10.0.0.11:worker1" )
CLUSTER_PEERS=()

# Hostnames que expõem 80/443 publicamente (onde o Traefik roda).
# Vazio = o instalador pergunta se ESTE nó é edge.
#   Ex.: EDGE_HOSTNAMES=( "mgr1" )
EDGE_HOSTNAMES=()

# Labels a aplicar por hostname, formato "chave=valor chave=valor".
# Vazio = o instalador pergunta as labels deste nó.
#   Ex.: CLUSTER_LABELS=( "mgr1=role.edge=true" "db1=role.db=true" )
CLUSTER_LABELS=()

# Rede overlay principal. A /22 dá 1022 IPs (4× a folga de uma /24) e
# 10.0.4.0/22 não colide com a ingress default do Swarm (10.0.0.0/24).
OVERLAY_NAME="${OVERLAY_NAME:-network_public}"
OVERLAY_SUBNET="${OVERLAY_SUBNET:-10.0.4.0/22}"
OVERLAY_ENCRYPTED="${OVERLAY_ENCRYPTED:-true}"

# Pool de endereços das redes locais (bridge) do daemon. Mantido fora das
# faixas mais comuns de VPS/VPC para não colidir com a rede do provedor.
DOCKER_ADDR_POOL_BASE="${DOCKER_ADDR_POOL_BASE:-172.20.0.0/16}"
DOCKER_ADDR_POOL_SIZE="${DOCKER_ADDR_POOL_SIZE:-24}"

# Pool das redes overlay (definido no `swarm init`, não no daemon.json).
SWARM_ADDR_POOL_BASE="${SWARM_ADDR_POOL_BASE:-10.0.0.0/8}"
SWARM_ADDR_POOL_SIZE="${SWARM_ADDR_POOL_SIZE:-24}"

# ---------------------------------------------------------------------------
#  Versões das imagens. Pinadas de propósito (swarm-deploy: nada de :latest em
#  produção). Atualize conscientemente.
# ---------------------------------------------------------------------------
# Traefik: v3.7.11 foi TAGGED mas o índice OCI está VAZIO (0 manifests) — o pull
# falha em qualquer arquitetura. v3.7.10 é a v3 mais nova realmente publicada.
# O instalador ainda valida o manifesto antes de fazer deploy (ver ensure_image).
TRAEFIK_VERSION="${TRAEFIK_VERSION:-v3.7.10}"

# Portainer: a linha LTS é a recomendada para produção. A tag :latest aponta
# para a LTS (2.39.6), NÃO para o número maior — 2.44.0 é STS e a própria
# Portainer diz que STS não é para produção. server e agent devem ter a MESMA
# versão exata.
PORTAINER_VERSION="${PORTAINER_VERSION:-2.39.6}"

# Driver de log. A Docker recomenda "local" (rotaciona por padrão e é mais
# compacto). Use "json-file" APENAS se algo externo lê
# /var/lib/docker/containers/*/*-json.log (Filebeat com input de arquivo, por
# exemplo) — o formato do "local" é privado do daemon. Portainer, Promtail e
# afins leem pela API do Docker e funcionam com os dois.
DOCKER_LOG_DRIVER="${DOCKER_LOG_DRIVER:-local}"

# ============================================================================
#  CONSTANTES INTERNAS
# ============================================================================
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="${0##*/}"
readonly DOCKER_CHANNEL="stable"
readonly DOCKER_MIRROR="https://download.docker.com/linux"

STATE_DIR="${SWARM_STATE_DIR:-${HOME:-/root}/.setup_state}"
STATE_FILE="$STATE_DIR/installation_state.conf"
LOG_FILE="$STATE_DIR/setup.log"
TOKEN_FILE="$STATE_DIR/swarm-tokens.txt"

# Flags de linha de comando (preenchidas em parse_args)
OPT_NONINTERACTIVE=0
OPT_ASSUME_YES=0
OPT_DRY_RUN=0
OPT_STATUS_ONLY=0
OPT_DOCTOR_ONLY=0
OPT_RESET=0
OPT_NO_COLOR=0
OPT_PROFILE_FILE=""
OPT_SKIP=""

# Preenchidas por detect_os()
OS_ID="" ; OS_ID_LIKE="" ; OS_VERSION_ID="" ; OS_CODENAME="" ; OS_PRETTY=""
OS_FAMILY="" ; PKG_MGR="" ; INIT_SYS="" ; CPU_ARCH=""
DOCKER_REPO_DISTRO="" ; DOCKER_REPO_SUITE=""

# ============================================================================
#  CORES (desligadas automaticamente fora de TTY ou com NO_COLOR / --no-color)
# ============================================================================
setup_colors() {
    if [ "$OPT_NO_COLOR" = "1" ] || [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
        RED='' ; GREEN='' ; YELLOW='' ; MAGENTA='' ; PURPLE='' ; CYAN='' ; BOLD='' ; NC=''
    else
        RED=$'\033[0;31m'   ; GREEN=$'\033[0;32m'  ; YELLOW=$'\033[0;33m'
        MAGENTA=$'\033[0;35m'; PURPLE=$'\033[1;35m'
        CYAN=$'\033[0;36m'  ; BOLD=$'\033[1m'    ; NC=$'\033[0m'
    fi
}
setup_colors

# ============================================================================
#  LOGGING
# ============================================================================
_ts() { date +'%d-%m-%Y %H:%M:%S'; }

_log_to_file() {
    # Nunca deixa o log derrubar o instalador (disco cheio, diretório ainda
    # não criado, sistema de arquivos read-only…).
    # O `2>/dev/null` precisa vir ANTES do `>>`: o shell monta os
    # redirecionamentos da esquerda para a direita, então um `>>` que falha
    # com o stderr ainda apontando para o terminal imprime o erro na tela.
    [ -n "${LOG_FILE:-}" ] || return 0
    [ -d "${LOG_FILE%/*}" ] || return 0
    printf '%s\n' "$1" 2>/dev/null >> "$LOG_FILE" || true
}

_emit() {   # _emit <cor> <prefixo> <mensagem> [--stderr]
    local color="$1" prefix="$2" text="$3" to_err="${4:-}" msg
    msg="[$(_ts)]${prefix:+ }${prefix}${text:+ }${text}"
    if [ "$to_err" = "--stderr" ]; then
        printf '%s%s%s\n' "$color" "$msg" "$NC" >&2
    else
        printf '%s%s%s\n' "$color" "$msg" "$NC"
    fi
    _log_to_file "$msg"
}

log()         { _emit "$GREEN"  ""       "$1"; }
log_info()    { _emit "$CYAN"   "INFO:"  "$1"; }
log_warning() { _emit "$YELLOW" "AVISO:" "$1" --stderr; }
log_error()   { _emit "$RED"    "ERRO:"  "$1" --stderr; }
log_success() { _emit "$GREEN"  "OK:"    "$1"; }
log_step()    {
    printf '\n%s%s%s\n' "$MAGENTA" "──────────────────────────────────────────────────────────────────────" "$NC"
    printf '%s  %s%s\n'   "$BOLD$CYAN" "$1" "$NC"
    printf '%s%s%s\n\n' "$MAGENTA" "──────────────────────────────────────────────────────────────────────" "$NC"
    _log_to_file "[$(_ts)] ===== $1 ====="
}

die() { log_error "$1"; exit "${2:-1}"; }

# ============================================================================
#  ENTRADA INTERATIVA
#  Lê SEMPRE do terminal (fd 3), nunca do stdin. É isso que permite
#  `curl -fsSL … | sudo bash` sem que o script seja consumido como resposta.
# ============================================================================
TTY_OK=0
open_tty() {
    # O erro de redirecionamento do `exec` é emitido pelo próprio shell, então
    # o `2>/dev/null` tem que envolver o comando inteiro — não basta anexá-lo.
    if [ -c /dev/tty ] && { exec 3</dev/tty; } 2>/dev/null; then
        TTY_OK=1
        return 0
    fi
    TTY_OK=0
    # Sem terminal, comandos informativos seguem normalmente e em silêncio.
    if [ "$OPT_NONINTERACTIVE" != "1" ] \
       && [ "$OPT_STATUS_ONLY" != "1" ] && [ "$OPT_DOCTOR_ONLY" != "1" ] && [ "$OPT_RESET" != "1" ]; then
        log_warning "Sem terminal disponível — entrando em modo não-interativo automaticamente."
    fi
    OPT_NONINTERACTIVE=1
}

# ask_text <prompt> <default> [--secret]
ask_text() {
    local prompt="$1" default="${2:-}" secret="${3:-}" ans=""
    if [ "$OPT_NONINTERACTIVE" = "1" ] || [ "$TTY_OK" != "1" ]; then
        printf '%s' "$default"; return 0
    fi
    if [ -n "$default" ]; then
        printf '%s%s%s [%s]: ' "$CYAN" "$prompt" "$NC" "$default" > /dev/tty
    else
        printf '%s%s%s: ' "$CYAN" "$prompt" "$NC" > /dev/tty
    fi
    if [ "$secret" = "--secret" ]; then
        read -r -s ans <&3 || ans=""
        printf '\n' > /dev/tty
    else
        read -r ans <&3 || ans=""
    fi
    printf '%s' "${ans:-$default}"
}

# ask_yn <prompt> <default y|n>  → retorna 0 para sim
ask_yn() {
    local prompt="$1" default="${2:-n}" suffix ans
    [[ "$default" =~ ^[Yy]$ ]] && suffix="[S/n]" || suffix="[s/N]"
    if [ "$OPT_ASSUME_YES" = "1" ]; then
        printf '%s%s%s %s → s (--yes)\n' "$CYAN" "$prompt" "$NC" "$suffix"
        return 0
    fi
    if [ "$OPT_NONINTERACTIVE" = "1" ] || [ "$TTY_OK" != "1" ]; then
        [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
    fi
    while :; do
        printf '%s%s%s %s: ' "$CYAN" "$prompt" "$NC" "$suffix" > /dev/tty
        read -r ans <&3 || ans=""
        ans="${ans:-$default}"
        case "$ans" in
            [YySs]|[Ss][Ii][Mm]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][AaÃã][Oo]|[Nn][Oo])     return 1 ;;
            *) printf '  Responda s (sim) ou n (não).\n' > /dev/tty ;;
        esac
    done
}

# ask_choice <prompt> <default> <opção1> <opção2> …  → ecoa a opção escolhida
ask_choice() {
    local prompt="$1" default="$2"; shift 2
    local opts=("$@") i ans
    if [ "$OPT_NONINTERACTIVE" = "1" ] || [ "$TTY_OK" != "1" ]; then
        # O default é o ÍNDICE (1..N). Devolver o índice cru faria o chamador
        # cair no ramo `*)` do case dele — foi assim que o modo
        # --non-interactive sempre virava "worker", nunca manager-leader.
        if [[ "$default" =~ ^[0-9]+$ ]] && [ "$default" -ge 1 ] && [ "$default" -le "${#opts[@]}" ]; then
            printf '%s' "${opts[$((default - 1))]}"
        else
            printf '%s' "$default"
        fi
        return 0
    fi
    while :; do
        printf '\n%s%s%s\n' "$CYAN" "$prompt" "$NC" > /dev/tty
        for i in "${!opts[@]}"; do
            printf '  %s) %s\n' "$((i + 1))" "${opts[$i]}" > /dev/tty
        done
        printf 'Escolha [1-%s] (padrão: %s): ' "${#opts[@]}" "$default" > /dev/tty
        read -r ans <&3 || ans=""
        ans="${ans:-$default}"
        if [[ "$ans" =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le "${#opts[@]}" ]; then
            printf '%s' "${opts[$((ans - 1))]}"; return 0
        fi
        printf '  Opção inválida.\n' > /dev/tty
    done
}

# ============================================================================
#  EXECUÇÃO (respeita --dry-run)
# ============================================================================
have() { command -v "$1" >/dev/null 2>&1; }

run() {
    if [ "$OPT_DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s %s\n' "$YELLOW" "$NC" "$*"
        return 0
    fi
    "$@"
}

# Escrita de arquivo respeitando --dry-run.
#   write_file <caminho>   conteúdo em stdin, SUBSTITUI
#   append_file <caminho>  conteúdo em stdin, ANEXA
# Sem isso, --dry-run continuaria sobrescrevendo daemon.json, sources.list,
# sysctl.d, sshd_config.d e /etc/hosts de verdade — ou seja, não seria um
# ensaio, seria a instalação com o log mentindo.
write_file() {
    local path="$1"
    if [ "$OPT_DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s escreveria %s:\n' "$YELLOW" "$NC" "$path"
        sed 's/^/    | /' 
        return 0
    fi
    cat > "$path"
}

append_file() {
    local path="$1"
    if [ "$OPT_DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s anexaria a %s:\n' "$YELLOW" "$NC" "$path"
        sed 's/^/    | /'
        return 0
    fi
    cat >> "$path"
}

# run_quiet: executa silenciando stdout, preservando stderr no log
run_quiet() {
    if [ "$OPT_DRY_RUN" = "1" ]; then
        printf '%s[dry-run]%s %s\n' "$YELLOW" "$NC" "$*"
        return 0
    fi
    "$@" >/dev/null 2>>"$LOG_FILE"
}

# ============================================================================
#  MÁQUINA DE ESTADO (retomável entre execuções)
# ============================================================================
#  Chaves conhecidas e seus valores iniciais. Toda chave listada aqui é
#  garantidamente definida em memória (`set -u` seguro) MESMO que o arquivo de
#  estado seja de uma versão antiga do instalador — este era exatamente o
#  buraco que produzia OS_CHOICE vazio e o `integer expression expected`.
# ----------------------------------------------------------------------------
STATE_KEYS=(
    STATE_SCHEMA
    INSTALLER_VERSION
    OS_DISTRO OS_CODENAME OS_FAMILY_S
    SYSTEM_USER
    HOSTNAME_CONFIGURED
    HOSTS_FILE_CONFIGURED
    MACHINE_ID_REGENERATED
    KERNEL_NOTIFICATIONS_DISABLED
    SYSTEM_UPDATED
    PREREQS_INSTALLED
    TIMESYNC_CONFIGURED
    SWAP_DISABLED
    SYSCTL_TUNED
    DOCKER_INSTALLED
    DOCKER_DAEMON_CONFIGURED
    DOCKER_PERMISSIONS_CONFIGURED
    FIREWALL_CONFIGURED
    FIREWALL_BACKEND
    SSH_HARDENED
    SWARM_INITIALIZED
    SWARM_LABELS_CONFIGURED
    NETWORK_CREATED
    NETWORK_NAME
    TRAEFIK_INSTALLED
    TRAEFIK_RESOLVER
    PORTAINER_INSTALLED
    NODE_TYPE
    NODE_ROLE
    NODE_IS_EDGE
    NODE_ADVERTISE_IP
)

state_default() {
    case "$1" in
        STATE_SCHEMA)        printf '3' ;;
        INSTALLER_VERSION)   printf '%s' "$SCRIPT_VERSION" ;;
        NETWORK_NAME)        printf '%s' "$OVERLAY_NAME" ;;
        TRAEFIK_RESOLVER)    printf 'letsencrypt' ;;
        FIREWALL_BACKEND)    printf '' ;;
        OS_DISTRO|OS_CODENAME|OS_FAMILY_S|SYSTEM_USER|NODE_TYPE|NODE_ROLE|NODE_ADVERTISE_IP)
                             printf '' ;;
        *)                   printf 'false' ;;
    esac
}

initialize_environment() {
    mkdir -p "$STATE_DIR" 2>/dev/null || die "Não consegui criar $STATE_DIR"
    chmod 700 "$STATE_DIR" 2>/dev/null || true
    : > /dev/null
    [ -f "$LOG_FILE" ] || touch "$LOG_FILE" 2>/dev/null || true

    if [ ! -f "$STATE_FILE" ]; then
        {
            printf '# Estado da instalação — Setup Automatizado v%s\n' "$SCRIPT_VERSION"
            printf '# Criado em %s\n' "$(date)"
        } > "$STATE_FILE"
        chmod 600 "$STATE_FILE" 2>/dev/null || true
    fi

    state_load
    state_hydrate       # <— garante TODA chave definida, mesmo vindo de state antigo
}

# Carrega o arquivo sem `source` (que executaria comando embutido no valor).
state_load() {
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        # só aceita identificadores válidos — ignora lixo silenciosamente
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        printf -v "$key" '%s' "$value"
    done < "$STATE_FILE"
}

state_hydrate() {
    local k
    for k in "${STATE_KEYS[@]}"; do
        if [ -z "${!k+x}" ]; then
            printf -v "$k" '%s' "$(state_default "$k")"
        fi
    done
}

# state_set KEY VALUE — append-se-ausente, substitui-se-presente.
# O bug original (`sed s/^KEY=.*/…/`) era no-op quando a chave não existia.
state_set() {
    local key="$1" value="${2:-}" tmp
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { log_error "Chave de estado inválida: $key"; return 1; }
    # valores multi-linha quebrariam o formato — normaliza
    value="${value//$'\n'/ }"

    if [ "$OPT_DRY_RUN" != "1" ]; then
        tmp="$(mktemp "${STATE_FILE}.XXXXXX")" || return 1
        # grava tudo menos a chave antiga, depois acrescenta a nova
        grep -v -E "^${key}=" "$STATE_FILE" > "$tmp" 2>/dev/null || true
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
        chmod 600 "$tmp" 2>/dev/null || true
        mv -f "$tmp" "$STATE_FILE" || { rm -f "$tmp"; return 1; }
    fi

    printf -v "$key" '%s' "$value"
    export "${key?}"
    _log_to_file "[$(_ts)] estado: ${key}=${value}"
    return 0
}

state_is_done() { [ "${!1:-false}" = "true" ]; }

# check_step VAR "Nome amigável" → 0 = executar, 1 = pular
check_step() {
    local var="$1" name="$2"
    if state_is_done "$var"; then
        if [ "$OPT_NONINTERACTIVE" = "1" ]; then
            log_info "'$name' já concluído — pulando."
            return 1
        fi
        printf '%s'"'"'%s'"'"' já foi concluído nesta máquina.%s\n' "$YELLOW" "$name" "$NC"
        ask_yn "Executar novamente?" "n" && return 0 || return 1
    fi
    return 0
}

# Permite `--skip docker,firewall`
step_skipped() {
    case ",${OPT_SKIP}," in
        *",$1,"*) log_info "Etapa '$1' pulada por --skip."; return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
#  DETECÇÃO DE SISTEMA OPERACIONAL
# ============================================================================
#  Lê /etc/os-release SEM `source` (um valor malicioso com $(...) não executa)
#  e SEM poluir o namespace do chamador.
# ----------------------------------------------------------------------------
# Caminhos sobrescrevíveis — permitem testar a detecção contra os
# /etc/os-release reais de outras distros sem precisar bootar cada uma.
OSRELEASE_FILES="${OSRELEASE_FILES:-/etc/os-release /usr/lib/os-release}"
DEBIAN_VERSION_FILE="${DEBIAN_VERSION_FILE:-/etc/debian_version}"

osr() {
    local key="$1" f
    for f in $OSRELEASE_FILES; do
        [ -r "$f" ] || continue
        sed -n -E "s/^[[:space:]]*${key}=[\"']?(.*[^\"'])[\"']?[[:space:]]*$/\1/p" "$f" | head -n1
        return 0
    done
    return 1
}

detect_init_system() {
    if [ -d /run/systemd/system ] && have systemctl;   then INIT_SYS="systemd"
    elif have rc-update && have rc-service;            then INIT_SYS="openrc"
    elif have service;                                 then INIT_SYS="sysv"
    else                                                    INIT_SYS="none"
    fi
}

detect_pkg_mgr() {
    if   have apt-get; then PKG_MGR="apt"
    elif have dnf5;    then PKG_MGR="dnf5"
    elif have dnf;     then
        # dnf5 pode se instalar como /usr/bin/dnf (Fedora 41+, RHEL 10)
        if dnf --version 2>/dev/null | head -n1 | grep -qi 'dnf5'; then PKG_MGR="dnf5"; else PKG_MGR="dnf"; fi
    elif have zypper;  then PKG_MGR="zypper"
    elif have yum;     then PKG_MGR="yum"
    elif have pacman;  then PKG_MGR="pacman"
    elif have apk;     then PKG_MGR="apk"
    else                    PKG_MGR="unknown"
    fi
}

# Família a partir de ID + ID_LIKE (ID_LIKE é lista separada por espaço).
detect_family() {
    local id="$OS_ID" like=" ${OS_ID_LIKE} "
    case "$id" in
        debian|ubuntu|raspbian|linuxmint|pop|zorin|elementary|neon|kali|devuan|mx|parrot|tuxedo|deepin|pureos|trisquel)
            OS_FAMILY="debian" ; return ;;
        rhel|centos|rocky|almalinux|ol|oraclelinux|fedora|amzn|scientific|virtuozzo|cloudlinux|navylinux|circle|eurolinux|miraclelinux|openeuler)
            OS_FAMILY="rhel" ; return ;;
        sles|sled|opensuse|opensuse-leap|opensuse-tumbleweed|opensuse-microos|suse)
            OS_FAMILY="suse" ; return ;;
        arch|archarm|manjaro|endeavouros|garuda|cachyos|artix)
            OS_FAMILY="arch" ; return ;;
        alpine)
            OS_FAMILY="alpine" ; return ;;
    esac
    case "$like" in
        *" ubuntu "*|*" debian "*)                       OS_FAMILY="debian" ;;
        *" rhel "*|*" fedora "*|*" centos "*)            OS_FAMILY="rhel" ;;
        *" suse "*|*" opensuse "*|*" sles "*)            OS_FAMILY="suse" ;;
        *" arch "*)                                      OS_FAMILY="arch" ;;
        *" alpine "*)                                    OS_FAMILY="alpine" ;;
        *)                                               OS_FAMILY="unknown" ;;
    esac
}

# --- Sondagem real do repositório Docker -----------------------------------
# Em vez de manter uma tabela estática (que apodrece a cada release novo),
# perguntamos ao próprio download.docker.com se aquele suite/major existe.
docker_repo_probe() {
    local url="$1" code
    have curl || return 0     # sem curl ainda: aceita o candidato sem sondar
    code="$(curl -fsSI --max-time 12 --retry 2 --retry-delay 1 \
              -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
    [ "$code" = "200" ]
}

# Codename Debian correspondente ao conteúdo de /etc/debian_version.
# Cobre Kali ("kali-rolling"), testing/sid ("trixie/sid") e numérico ("13.1").
debian_version_to_codename() {
    local dv="" major=""
    [ -r "$DEBIAN_VERSION_FILE" ] && dv="$(tr -d '[:space:]' < "$DEBIAN_VERSION_FILE")"
    [ -n "$dv" ] || return 1
    case "$dv" in
        */sid)  printf '%s' "${dv%%/*}" ; return 0 ;;   # "trixie/sid" → trixie
    esac
    major="${dv%%.*}"
    case "$major" in
        14) printf 'forky'    ;;
        13) printf 'trixie'   ;;
        12) printf 'bookworm' ;;
        11) printf 'bullseye' ;;
        10) printf 'buster'   ;;
        *)  return 1 ;;
    esac
}

# Devuan usa nomes próprios; mapeia para o Debian equivalente.
devuan_to_debian() {
    case "$1" in
        excalibur) printf 'trixie'   ;;
        daedalus)  printf 'bookworm' ;;
        chimaera)  printf 'bullseye' ;;
        beowulf)   printf 'buster'   ;;
        *)         return 1 ;;
    esac
}

resolve_docker_deb_repo() {
    local candidates=() c derived

    case "$OS_ID" in
        ubuntu)
            DOCKER_REPO_DISTRO="ubuntu"
            candidates=( "${UBUNTU_CODENAME_RAW:-}" "$OS_CODENAME" )
            ;;
        linuxmint|pop|zorin|elementary|neon|tuxedo|pureos|trisquel)
            # Derivados de Ubuntu: UBUNTU_CODENAME traz o codename de UPSTREAM.
            # VERSION_CODENAME traz o do derivado (ex.: "wilma"), que não existe
            # no repositório do Docker.
            DOCKER_REPO_DISTRO="ubuntu"
            candidates=( "${UBUNTU_CODENAME_RAW:-}" )
            ;;
        debian)
            DOCKER_REPO_DISTRO="debian"
            candidates=( "$OS_CODENAME" )
            derived="$(debian_version_to_codename || true)"; [ -n "$derived" ] && candidates+=( "$derived" )
            ;;
        raspbian)
            DOCKER_REPO_DISTRO="raspbian"
            candidates=( "$OS_CODENAME" )
            ;;
        devuan)
            DOCKER_REPO_DISTRO="debian"
            derived="$(devuan_to_debian "$OS_CODENAME" || true)"; [ -n "$derived" ] && candidates+=( "$derived" )
            ;;
        kali|parrot|mx)
            # Rolling sobre Debian testing: VERSION_CODENAME não é um codename
            # Debian válido ("kali-rolling"). Deriva de /etc/debian_version.
            DOCKER_REPO_DISTRO="debian"
            derived="$(debian_version_to_codename || true)"; [ -n "$derived" ] && candidates+=( "$derived" )
            ;;
        *)
            case " ${OS_ID_LIKE} " in
                *" ubuntu "*) DOCKER_REPO_DISTRO="ubuntu"; candidates=( "${UBUNTU_CODENAME_RAW:-}" "$OS_CODENAME" ) ;;
                *)            DOCKER_REPO_DISTRO="debian"
                              candidates=( "$OS_CODENAME" )
                              derived="$(debian_version_to_codename || true)"; [ -n "$derived" ] && candidates+=( "$derived" ) ;;
            esac
            ;;
    esac

    # Rede de segurança: LTS/estáveis conhecidos, do mais novo para o mais antigo.
    case "$DOCKER_REPO_DISTRO" in
        ubuntu)   candidates+=( resolute questing plucky oracular noble jammy focal ) ;;
        debian)   candidates+=( trixie bookworm bullseye ) ;;
        raspbian) candidates+=( bookworm bullseye ) ;;
    esac

    for c in "${candidates[@]}"; do
        [ -n "$c" ] || continue
        [[ "$c" =~ ^[a-z][a-z0-9]*$ ]] || continue      # descarta "kali-rolling", "n/a", vazio
        if docker_repo_probe "${DOCKER_MIRROR}/${DOCKER_REPO_DISTRO}/dists/${c}/Release"; then
            DOCKER_REPO_SUITE="$c"
            [ "$c" = "${OS_CODENAME}" ] || log_info \
                "Codename '${OS_CODENAME:-?}' não existe no repositório Docker de ${DOCKER_REPO_DISTRO}; usando '${c}'."
            return 0
        fi
    done
    return 1
}

resolve_docker_rpm_repo() {
    # O .repo oficial usa \$releasever, então o dnf resolve a major sozinho.
    #
    # ARMADILHA (verificada em 2026-08-19, não é teoria): existem árvores
    # download.docker.com/linux/{rocky,alma,oracle}/ e elas respondem 200 —
    # mas NÃO contêm o pacote docker-ce. Só containerd.io, buildx, compose e
    # alguns plugins (24–28 rpms, contra 507 do centos). Apontar o Rocky para
    # a árvore "rocky" instala os plugins e falha no engine com
    # "No match for argument: docker-ce".
    # Por isso todo clone de RHEL vai para a árvore CENTOS, que é o caminho
    # que a documentação da Docker prescreve para eles.
    case "$OS_ID" in
        rhel)                 DOCKER_REPO_DISTRO="rhel"   ;;
        fedora)               DOCKER_REPO_DISTRO="fedora" ;;
        amzn)                 DOCKER_REPO_DISTRO=""       ;;  # a AWS tem repo próprio
        centos|rocky|almalinux|ol|oraclelinux|*)
                              DOCKER_REPO_DISTRO="centos" ;;
    esac
    [ -n "$DOCKER_REPO_DISTRO" ] || return 0

    local major="${OS_VERSION_ID%%.*}"
    if [ -n "$major" ] && ! docker_repo_probe "${DOCKER_MIRROR}/${DOCKER_REPO_DISTRO}/${major}/"; then
        log_warning "Docker não publica ${DOCKER_REPO_DISTRO} ${major}; tentando a árvore CentOS."
        DOCKER_REPO_DISTRO="centos"
    fi
    return 0
}

detect_os() {
    log_step "Detecção do sistema"

    local _f _found=0
    for _f in $OSRELEASE_FILES; do [ -r "$_f" ] && { _found=1; break; }; done
    [ "$_found" = "1" ] || die "Sem /etc/os-release — não é possível identificar a distribuição."

    OS_ID="$(osr ID || true)"
    OS_ID_LIKE="$(osr ID_LIKE || true)"
    OS_VERSION_ID="$(osr VERSION_ID || true)"
    OS_CODENAME="$(osr VERSION_CODENAME || true)"
    OS_PRETTY="$(osr PRETTY_NAME || true)"
    UBUNTU_CODENAME_RAW="$(osr UBUNTU_CODENAME || true)"
    CPU_ARCH="$(uname -m)"

    [ -n "$OS_ID" ] || die "ID ausente em /etc/os-release."

    detect_family
    detect_pkg_mgr
    detect_init_system

    log_success "${OS_PRETTY:-$OS_ID $OS_VERSION_ID}"
    log_info "família=${OS_FAMILY} · pacotes=${PKG_MGR} · init=${INIT_SYS} · arch=${CPU_ARCH}"

    case "$CPU_ARCH" in
        x86_64|amd64|aarch64|arm64|armv7l|armhf|s390x|ppc64le) ;;
        *) log_warning "Arquitetura '${CPU_ARCH}' pouco testada com Docker CE." ;;
    esac

    case "$OS_FAMILY" in
        debian)
            if resolve_docker_deb_repo; then
                log_success "Repositório Docker: ${DOCKER_MIRROR}/${DOCKER_REPO_DISTRO} ${DOCKER_REPO_SUITE} ${DOCKER_CHANNEL}"
            else
                log_warning "Nenhum suite Docker compatível encontrado — usaremos o instalador oficial get.docker.com."
                DOCKER_REPO_DISTRO=""
            fi
            ;;
        rhel)
            resolve_docker_rpm_repo
            if [ "$OS_ID" = "amzn" ]; then
                log_info "Amazon Linux: o Docker vem do repositório da própria AWS."
            else
                log_success "Repositório Docker: ${DOCKER_MIRROR}/${DOCKER_REPO_DISTRO}/\$releasever"
            fi
            ;;
        suse)
            log_info "Família SUSE detectada."
            ;;
        arch|alpine)
            log_info "Docker virá dos repositórios da própria distribuição."
            ;;
        *)
            log_warning "Distribuição '${OS_ID}' fora da matriz conhecida — usaremos get.docker.com."
            ;;
    esac

    if [ "$INIT_SYS" != "systemd" ]; then
        log_warning "Init '${INIT_SYS}' (sem systemd). O Swarm funciona, mas as etapas de systemd serão adaptadas ou puladas."
    fi

    state_set OS_DISTRO   "$OS_ID"
    state_set OS_CODENAME "${DOCKER_REPO_SUITE:-$OS_CODENAME}"
    state_set OS_FAMILY_S "$OS_FAMILY"
}

# Reconcilia o arquivo de estado com o que a máquina REALMENTE tem.
# O estado é só um cache; a máquina é a verdade. Sem isso, um state file
# copiado de outro host, um `docker swarm leave`, ou uma stack removida à mão
# fazem o instalador pular etapas que precisam rodar de novo — e o usuário
# nunca descobre por quê.
reconcile_state() {
    have docker || return 0
    docker version >/dev/null 2>&1 || return 0

    local live_swarm is_mgr
    live_swarm="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo inactive)"
    is_mgr="$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null || echo false)"

    if state_is_done SWARM_INITIALIZED && [ "$live_swarm" != "active" ]; then
        log_warning "Estado dizia que o Swarm estava ativo, mas o daemon diz '${live_swarm}'. Corrigindo."
        state_set SWARM_INITIALIZED false
        state_set SWARM_LABELS_CONFIGURED false
        state_set NETWORK_CREATED false
        state_set TRAEFIK_INSTALLED false
        state_set PORTAINER_INSTALLED false
        return 0
    fi
    [ "$live_swarm" = "active" ] && ! state_is_done SWARM_INITIALIZED && {
        log_info "Nó já está no Swarm — marcando a etapa como concluída."
        state_set SWARM_INITIALIZED true; }

    [ "$is_mgr" = "true" ] || return 0

    if state_is_done NETWORK_CREATED \
       && ! docker network ls --format '{{.Name}}' 2>/dev/null | grep -qx "${NETWORK_NAME:-$OVERLAY_NAME}"; then
        log_warning "Rede '${NETWORK_NAME:-$OVERLAY_NAME}' não existe mais. Corrigindo o estado."
        state_set NETWORK_CREATED false
    fi
    if state_is_done TRAEFIK_INSTALLED \
       && ! docker service ls --format '{{.Name}}' 2>/dev/null | grep -qx 'traefik_traefik'; then
        log_warning "Serviço traefik_traefik não existe mais. Corrigindo o estado."
        state_set TRAEFIK_INSTALLED false
    fi
    if state_is_done PORTAINER_INSTALLED \
       && ! docker service ls --format '{{.Name}}' 2>/dev/null | grep -qx 'portainer_portainer'; then
        log_warning "Serviço portainer_portainer não existe mais. Corrigindo o estado."
        state_set PORTAINER_INSTALLED false
    fi
}

# ============================================================================
#  ABSTRAÇÕES DE SISTEMA (funcionam com systemd, OpenRC ou SysV)
# ============================================================================
svc_enable_now() {
    local unit="$1"
    case "$INIT_SYS" in
        systemd) run systemctl enable --now "$unit" >/dev/null 2>&1 || run systemctl start "$unit" >/dev/null 2>&1 || return 1 ;;
        openrc)  run rc-update add "$unit" default >/dev/null 2>&1 || true; run rc-service "$unit" start >/dev/null 2>&1 || return 1 ;;
        sysv)    run service "$unit" start >/dev/null 2>&1 || return 1 ;;
        *)       log_warning "Sem gerenciador de serviços — inicie '$unit' manualmente."; return 0 ;;
    esac
}

svc_restart() {
    local unit="$1"
    case "$INIT_SYS" in
        systemd) run systemctl restart "$unit" ;;
        openrc)  run rc-service "$unit" restart ;;
        sysv)    run service "$unit" restart ;;
        *)       return 0 ;;
    esac
}

svc_disable_now() {
    local unit="$1"
    case "$INIT_SYS" in
        systemd) run systemctl disable --now "$unit" >/dev/null 2>&1 || true ;;
        openrc)  run rc-update del "$unit" default >/dev/null 2>&1 || true ;;
        *) : ;;
    esac
}

pkg_install() {
    [ "$#" -gt 0 ] || return 0
    case "$PKG_MGR" in
        apt)      DEBIAN_FRONTEND=noninteractive run apt-get install -y --no-install-recommends "$@" ;;
        dnf|dnf5) run "$PKG_MGR" install -y "$@" ;;
        yum)      run yum install -y "$@" ;;
        zypper)   run zypper --non-interactive install -y "$@" ;;
        pacman)   run pacman -S --needed --noconfirm "$@" ;;
        apk)      run apk add --no-cache "$@" ;;
        *)        log_warning "Sem gerenciador de pacotes conhecido; não instalei: $*"; return 1 ;;
    esac
}

pkg_refresh() {
    case "$PKG_MGR" in
        apt)      DEBIAN_FRONTEND=noninteractive run apt-get update -y ;;
        dnf|dnf5) run "$PKG_MGR" -y makecache 2>/dev/null || true ;;
        yum)      run yum -y makecache 2>/dev/null || true ;;
        zypper)   run zypper --non-interactive refresh ;;
        pacman)   run pacman -Sy --noconfirm ;;
        apk)      run apk update ;;
        *)        return 0 ;;
    esac
}

# ============================================================================
#  PRÉ-VOO
# ============================================================================
preflight() {
    log_step "Pré-voo"

    # PKG_MGR/INIT_SYS só são preenchidos por detect_os(), que roda DEPOIS
    # daqui. Sem esta chamada, o passo 6 (instalar curl/ca-certificates) cai no
    # ramo "*)" de pkg_install e não instala nada — e aí docker_repo_probe,
    # que faz `have curl || return 0`, passa a ACEITAR o primeiro candidato sem
    # sondar. Ou seja: numa instalação mínima sem curl, toda a garantia de
    # "sondamos o índice real" some em silêncio. Ambas são idempotentes.
    detect_pkg_mgr
    detect_init_system

    # 1) root
    if [ "$(id -u)" -ne 0 ]; then
        if have sudo; then
            die "Rode como root: sudo bash ${SCRIPT_NAME}"
        fi
        die "Rode como root (sudo não está instalado nesta máquina: use 'su -')."
    fi
    log_success "Executando como root."

    # 2) kernel Linux
    [ "$(uname -s)" = "Linux" ] || die "Este instalador é só para Linux (detectado: $(uname -s))."

    # 3) container / ambiente sem privilégio de rede
    if [ -f /.dockerenv ] || grep -qa 'container=' /proc/1/environ 2>/dev/null; then
        log_warning "Parece que estamos dentro de um container. Docker Swarm precisa de um host real."
        ask_yn "Continuar mesmo assim?" "n" || die "Abortado pelo usuário." 0
    fi

    # 4) espaço em disco (Docker + imagens confortavelmente em 5 GB)
    local free_mb
    free_mb="$(df -Pm /var 2>/dev/null | awk 'NR==2{print $4}')"
    if [ -n "$free_mb" ] && [ "$free_mb" -lt 5120 ]; then
        log_warning "Só ${free_mb} MB livres em /var. O recomendado é 5 GB+."
        ask_yn "Continuar mesmo assim?" "n" || die "Abortado — libere espaço primeiro." 0
    else
        log_success "Espaço em /var: ${free_mb:-?} MB livres."
    fi

    # 5) memória
    local mem_mb
    mem_mb="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null)"
    [ -n "$mem_mb" ] && [ "$mem_mb" -lt 1800 ] && \
        log_warning "Só ${mem_mb} MB de RAM. Um manager de Swarm com Traefik+Portainer pede 2 GB+."

    # 6) ferramentas mínimas — instala antes de qualquer coisa que dependa delas
    local missing=()
    have curl || missing+=("curl")
    have ca-certificates 2>/dev/null || true
    [ -d /etc/ssl/certs ] || missing+=("ca-certificates")
    if [ "${#missing[@]}" -gt 0 ]; then
        log_info "Instalando dependências mínimas: ${missing[*]}"
        pkg_refresh || true
        pkg_install "${missing[@]}" || log_warning "Falha ao instalar ${missing[*]} — algumas sondagens serão puladas."
    fi

    # 7) conectividade com o registry/repos
    if have curl; then
        if curl -fsS --max-time 12 -o /dev/null https://download.docker.com/ 2>/dev/null; then
            log_success "Conectividade com download.docker.com OK."
        else
            log_warning "Não alcancei download.docker.com. Proxy/DNS/firewall de saída?"
        fi
    fi

    # 8) relógio — ACME/Let's Encrypt e o raft do Swarm são sensíveis a drift
    if have timedatectl; then
        if ! timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
            log_warning "Relógio não sincronizado por NTP. Certificados TLS e o raft do Swarm podem falhar."
        fi
    fi
}

# ============================================================================
#  HOSTNAME + /etc/hosts
# ============================================================================
configure_hostname() {
    step_skipped hostname && return 0
    check_step HOSTNAME_CONFIGURED "Configurar hostname" || return 0
    log_step "Hostname"

    local current new
    current="$(hostname -s 2>/dev/null || cat /etc/hostname 2>/dev/null || echo localhost)"
    log_info "Hostname atual: ${current}"

    if [ "${#CLUSTER_PEERS[@]}" -gt 0 ]; then
        printf '%sHostnames previstos no perfil "%s":%s\n' "$CYAN" "$CLUSTER_PROFILE_NAME" "$NC"
        local p
        for p in "${CLUSTER_PEERS[@]}"; do
            [ "${p#*:}" != "$p" ] && printf '  • %s (%s)\n' "${p#*:}" "${p%%:*}"
        done
    fi

    new="$(ask_text "Hostname deste nó (ENTER mantém)" "$current")"

    if [ -n "$new" ] && [ "$new" != "$current" ]; then
        if ! [[ "$new" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            log_error "Hostname inválido (RFC 1123): '${new}'. Mantendo '${current}'."
            new="$current"
        else
            log "Alterando hostname: ${current} → ${new}"
            if have hostnamectl && [ "$INIT_SYS" = "systemd" ]; then
                run hostnamectl set-hostname "$new"
            else
                run hostname "$new"
                printf '%s\n' "$new" | write_file /etc/hostname
            fi
            if grep -qE '^127\.0\.1\.1' /etc/hosts 2>/dev/null; then
                run sed -i -E "s/^127\.0\.1\.1.*/127.0.1.1\t${new}/" /etc/hosts
            else
                printf '127.0.1.1\t%s\n' "$new" | append_file /etc/hosts
            fi
        fi
    fi

    state_set HOSTNAME_CONFIGURED true
    log_success "Hostname: $(hostname -s 2>/dev/null || echo "$new")"
}

configure_hosts_file() {
    [ "${#CLUSTER_PEERS[@]}" -gt 0 ] || return 0
    step_skipped hosts && return 0
    check_step HOSTS_FILE_CONFIGURED "Popular /etc/hosts com os peers" || return 0
    log_step "/etc/hosts"

    local entry ip host added=0
    for entry in "${CLUSTER_PEERS[@]}"; do
        ip="${entry%%:*}"; host="${entry#*:}"
        [ -n "$host" ] && [ "$host" != "$ip" ] || continue
        if ! grep -qE "^[[:space:]]*${ip//./\\.}[[:space:]]+.*\b${host}\b" /etc/hosts 2>/dev/null; then
            printf '%s\t%s\n' "$ip" "$host" | append_file /etc/hosts
            added=$((added + 1))
        fi
    done

    state_set HOSTS_FILE_CONFIGURED true
    log_success "/etc/hosts atualizado (${added} entrada(s) nova(s))."
}

# ============================================================================
#  MACHINE-ID  (imagens de VPS clonadas compartilham o mesmo id e o Swarm
#  passa a tratar nós distintos como o mesmo nó)
# ============================================================================
regenerate_machine_id() {
    step_skipped machineid && return 0
    [ "$INIT_SYS" = "systemd" ] || { log_info "Sem systemd — machine-id não se aplica."; return 0; }
    check_step MACHINE_ID_REGENERATED "Regenerar machine-id" || return 0
    log_step "machine-id"

    log_warning "Só faça isso ANTES de o nó entrar no Swarm. Em nó já ativo, o ID muda e o Swarm perde a identidade."
    # O flag do arquivo de estado não basta: --reset o apaga, $HOME pode mudar
    # entre execuções e o nó pode ter entrado no Swarm por fora. Consulta o
    # daemon, que é a única fonte confiável.
    local live_swarm="inactive"
    have docker && live_swarm="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo inactive)"
    if state_is_done SWARM_INITIALIZED || [ "$live_swarm" = "active" ] || [ -d /var/lib/docker/swarm ]; then
        log_error "Este nó já participa de um Swarm — regeneração cancelada por segurança."
        return 0
    fi
    ask_yn "Regenerar o machine-id (recomendado em VPS criada a partir de imagem/snapshot)?" "y" || {
        log_info "Mantendo o machine-id atual."; return 0; }

    run rm -f /etc/machine-id /var/lib/dbus/machine-id
    run systemd-machine-id-setup >/dev/null 2>&1 || true
    have dbus-uuidgen && run dbus-uuidgen --ensure >/dev/null 2>&1 || true

    state_set MACHINE_ID_REGENERATED true
    log_success "machine-id: $(cat /etc/machine-id 2>/dev/null || echo '?')"
}

# ============================================================================
#  NOTIFICAÇÕES / UPGRADES AUTOMÁTICOS DE KERNEL
# ============================================================================
disable_kernel_notifications() {
    step_skipped kernelnotif && return 0
    check_step KERNEL_NOTIFICATIONS_DISABLED "Desabilitar upgrades automáticos" || return 0
    log_step "Upgrades automáticos"

    case "$OS_FAMILY" in
        debian)
            write_file /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
EOF
            if [ -d /etc/update-motd.d ]; then
                local f
                for f in /etc/update-motd.d/*-updates-available \
                         /etc/update-motd.d/*-release-upgrade \
                         /etc/update-motd.d/*-reboot-required; do
                    [ -e "$f" ] && run chmod -x "$f" 2>/dev/null || true
                done
            fi
            svc_disable_now unattended-upgrades.service
            svc_disable_now apt-daily.timer
            svc_disable_now apt-daily-upgrade.timer
            ;;
        rhel)
            [ -f /etc/dnf/automatic.conf ] && {
                run sed -i 's/^apply_updates = yes/apply_updates = no/' /etc/dnf/automatic.conf
                run sed -i 's/^emit_via = .*/emit_via = none/'         /etc/dnf/automatic.conf
            }
            svc_disable_now dnf-automatic.timer
            svc_disable_now dnf-automatic-install.timer
            svc_disable_now yum-cron
            ;;
        suse)
            svc_disable_now transactional-update.timer
            ;;
        *)
            log_info "Nada a desabilitar nesta família."
            ;;
    esac

    state_set KERNEL_NOTIFICATIONS_DISABLED true
    log_success "Upgrades automáticos desabilitados."
}

# ============================================================================
#  UPDATE / UPGRADE
# ============================================================================
update_upgrade() {
    step_skipped update && return 0
    check_step SYSTEM_UPDATED "Atualizar o sistema" || return 0
    log_step "Atualização do sistema"

    case "$PKG_MGR" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            run apt-get update -y || log_warning "apt-get update falhou — seguindo."
            run apt-get upgrade -y \
                -o Dpkg::Options::=--force-confdef \
                -o Dpkg::Options::=--force-confold || log_warning "apt-get upgrade falhou — seguindo."
            ;;
        dnf|dnf5)
            run "$PKG_MGR" upgrade -y --refresh || log_warning "upgrade falhou — seguindo." ;;
        yum)    run yum update -y || log_warning "yum update falhou — seguindo." ;;
        zypper) run zypper --non-interactive update -y || log_warning "zypper update falhou — seguindo." ;;
        pacman) run pacman -Syu --noconfirm || log_warning "pacman -Syu falhou — seguindo." ;;
        apk)    run apk update && run apk upgrade || log_warning "apk upgrade falhou — seguindo." ;;
    esac

    state_set SYSTEM_UPDATED true
    log_success "Sistema atualizado."
}

# ============================================================================
#  PRÉ-REQUISITOS
# ============================================================================
install_prerequisites() {
    step_skipped prereqs && return 0
    check_step PREREQS_INSTALLED "Instalar pré-requisitos" || return 0
    log_step "Pré-requisitos"

    pkg_refresh || true

    # Dois grupos, de propósito. apt/dnf/zypper abortam a transação INTEIRA se
    # um único nome de pacote não existir naquela distro — então um nome errado
    # (ou um pacote renomeado numa versão nova) derrubaria toda a etapa.
    # Os ESSENCIAIS vão juntos e precisam passar; os OPCIONAIS vão um a um e
    # falham em silêncio. Assim, uma distro exótica ainda instala o Docker.
    local essentials=() optionals=()
    case "$PKG_MGR" in
        apt)
            essentials=( ca-certificates curl gnupg )
            optionals=( apt-transport-https jq htop nano rsync git iproute2 dnsutils openssl nftables sudo )
            ;;
        dnf|dnf5|yum)
            essentials=( ca-certificates curl )
            optionals=( gnupg2 jq htop nano rsync git iproute bind-utils openssl nftables sudo )
            ;;
        zypper)
            essentials=( ca-certificates curl )
            optionals=( gpg2 jq htop nano rsync git iproute2 bind-utils openssl nftables sudo )
            ;;
        pacman)
            essentials=( ca-certificates curl )
            optionals=( gnupg jq htop nano rsync git iproute2 bind openssl nftables sudo )
            ;;
        apk)
            essentials=( ca-certificates curl )
            optionals=( gnupg jq htop nano rsync git iproute2 bind-tools openssl nftables sudo )
            ;;
        *)
            log_warning "Gerenciador de pacotes desconhecido — pulando pré-requisitos."
            state_set PREREQS_INSTALLED true
            return 0
            ;;
    esac

    if ! pkg_install "${essentials[@]}"; then
        log_error "Não consegui instalar os pacotes essenciais: ${essentials[*]}"
        return 1
    fi
    log_success "Essenciais instalados: ${essentials[*]}"

    local pkg missing=()
    for pkg in "${optionals[@]}"; do
        pkg_install "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        log_warning "Opcionais indisponíveis nesta distribuição (seguindo sem eles): ${missing[*]}"
    fi

    state_set PREREQS_INSTALLED true
    log_success "Pré-requisitos concluídos."
}

# ============================================================================
#  SINCRONIZAÇÃO DE RELÓGIO
#  Raft do Swarm e emissão ACME quebram com drift de relógio.
# ============================================================================
configure_timesync() {
    step_skipped timesync && return 0
    check_step TIMESYNC_CONFIGURED "Sincronizar relógio" || return 0
    log_step "Relógio (NTP)"

    if [ "$INIT_SYS" = "systemd" ] && have timedatectl; then
        run timedatectl set-ntp true >/dev/null 2>&1 || true
        if ! timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
            if ! systemctl is-enabled systemd-timesyncd >/dev/null 2>&1; then
                pkg_install systemd-timesyncd >/dev/null 2>&1 || pkg_install chrony >/dev/null 2>&1 || true
            fi
            svc_enable_now systemd-timesyncd 2>/dev/null || svc_enable_now chronyd 2>/dev/null || \
                svc_enable_now chrony 2>/dev/null || true
        fi
    else
        pkg_install chrony >/dev/null 2>&1 || true
        svc_enable_now chronyd 2>/dev/null || svc_enable_now chrony 2>/dev/null || true
    fi

    state_set TIMESYNC_CONFIGURED true
    log_success "NTP: $(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo 'verificar manualmente')"
}

# ============================================================================
#  SWAP
# ============================================================================
disable_swap_persistent() {
    step_skipped swap && return 0
    check_step SWAP_DISABLED "Desabilitar swap" || return 0
    log_step "Swap"

    if [ "$(awk 'NR>1{s+=$3} END{print s+0}' /proc/swaps 2>/dev/null)" = "0" ] \
       && [ ! -s /proc/swaps ]; then
        log_info "Nenhum swap ativo."
    fi

    run swapoff -a 2>/dev/null || true

    if [ -f /etc/fstab ]; then
        cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        run sed -i -E 's@^([^#][^[:space:]]*[[:space:]]+[^[:space:]]+[[:space:]]+swap[[:space:]]+.*)$@#\1@' /etc/fstab || true
    fi

    if [ "$INIT_SYS" = "systemd" ]; then
        local units=() u
        while IFS= read -r u; do [ -n "$u" ] && units+=("$u"); done < <(
            systemctl list-unit-files --type=swap --no-legend --no-pager 2>/dev/null | awk '{print $1}'
        )
        for u in "${units[@]}"; do
            run systemctl mask "$u" >/dev/null 2>&1 || true
            log_info "Unit de swap mascarada: $u"
        done
    fi

    printf 'vm.swappiness = 0\n' | write_file /etc/sysctl.d/99-swap-disable.conf
    run sysctl -w vm.swappiness=0 >/dev/null 2>&1 || true

    state_set SWAP_DISABLED true
    log_success "Swap desligado de forma persistente."
}

# ============================================================================
#  SYSCTL
# ============================================================================
apply_sysctl_tuning() {
    step_skipped sysctl && return 0
    check_step SYSCTL_TUNED "Aplicar tuning de sysctl" || return 0
    log_step "sysctl"

    # br_netfilter e overlay precisam existir ANTES de setar as chaves
    # net.bridge.* — senão sysctl -p reclama de "key não existe".
    printf 'overlay\nbr_netfilter\n' | write_file /etc/modules-load.d/docker-swarm.conf
    run modprobe overlay      2>/dev/null || log_warning "Módulo 'overlay' indisponível."
    run modprobe br_netfilter 2>/dev/null || log_warning "Módulo 'br_netfilter' indisponível."

    write_file /etc/sysctl.d/99-docker-swarm.conf <<'EOF'
# Tuning para Docker Swarm — Setup Automatizado
# Descritores de arquivo
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024

# Rede: backlog e temporizações
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.ip_local_port_range = 10240 65535

# Roteamento — obrigatório para as redes do Docker
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Memória
vm.max_map_count = 262144
vm.overcommit_memory = 1
EOF

    # conntrack só existe se o módulo estiver carregado — evita erro no sysctl -p
    if [ -e /proc/sys/net/netfilter/nf_conntrack_max ]; then
        printf '\n# Conntrack\nnet.netfilter.nf_conntrack_max = 524288\n' | append_file /etc/sysctl.d/99-docker-swarm.conf
    fi

    if ! run sysctl --system >/dev/null 2>&1; then
        log_warning "Algumas chaves de sysctl não aplicaram (módulo ausente?). Detalhes:"
        sysctl -p /etc/sysctl.d/99-docker-swarm.conf 2>&1 | grep -i 'cannot\|error' | head -5 || true
    fi

    state_set SYSCTL_TUNED true
    log_success "sysctl aplicado."
}

# ============================================================================
#  INSTALAÇÃO DO DOCKER CE
# ============================================================================
#  Um caminho por família + um fallback universal (get.docker.com), para que
#  nenhuma distro fique de fora.
# ----------------------------------------------------------------------------

docker_remove_conflicts_deb() {
    local p
    for p in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        if dpkg -l "$p" 2>/dev/null | grep -q '^ii'; then
            log_info "Removendo pacote conflitante: $p"
            DEBIAN_FRONTEND=noninteractive run apt-get remove -y "$p" >/dev/null 2>&1 || true
        fi
    done
}

docker_remove_conflicts_rpm() {
    local p mgr="$PKG_MGR"; [ "$mgr" = "dnf5" ] && mgr="dnf"
    for p in docker docker-client docker-client-latest docker-common docker-latest \
             docker-latest-logrotate docker-logrotate docker-engine podman runc buildah; do
        if rpm -q "$p" >/dev/null 2>&1; then
            log_info "Removendo pacote conflitante: $p"
            run "$mgr" remove -y "$p" >/dev/null 2>&1 || true
        fi
    done
}

install_docker_deb() {
    export DEBIAN_FRONTEND=noninteractive
    docker_remove_conflicts_deb

    run install -m 0755 -d /etc/apt/keyrings

    # `gpg --dearmor -o` ABORTA se o destino existe. Era isso que quebrava toda
    # re-execução do script antigo. Baixa para temporário e move por cima.
    local keyring=/etc/apt/keyrings/docker.gpg tmpkey
    tmpkey="$(mktemp)" || return 1
    if ! curl -fsSL --max-time 30 --retry 3 "${DOCKER_MIRROR}/${DOCKER_REPO_DISTRO}/gpg" -o "${tmpkey}.asc"; then
        rm -f "$tmpkey" "${tmpkey}.asc"; log_error "Falha ao baixar a chave GPG do Docker."; return 1
    fi
    if ! gpg --batch --yes --dearmor -o "$tmpkey" "${tmpkey}.asc"; then
        rm -f "$tmpkey" "${tmpkey}.asc"; log_error "Falha ao converter a chave GPG."; return 1
    fi
    run install -m 0644 "$tmpkey" "$keyring"
    rm -f "$tmpkey" "${tmpkey}.asc"

    # Um repositório antigo do get.docker.com/apt-key pode conflitar com o novo
    # signed-by e travar o apt-get update.
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        cp -a /etc/apt/sources.list.d/docker.list \
              "/etc/apt/sources.list.d/docker.list.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi

    local arch; arch="$(dpkg --print-architecture)"
    printf 'deb [arch=%s signed-by=%s] %s/%s %s %s\n' \
        "$arch" "$keyring" "$DOCKER_MIRROR" "$DOCKER_REPO_DISTRO" \
        "$DOCKER_REPO_SUITE" "$DOCKER_CHANNEL" | write_file /etc/apt/sources.list.d/docker.list

    run apt-get update -y || { log_error "apt-get update falhou depois de adicionar o repo do Docker."; return 1; }
    run apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin || {
        log_error "Instalação dos pacotes do Docker falhou."; return 1; }
}

install_docker_rpm() {
    local mgr="$PKG_MGR"; [ "$mgr" = "dnf5" ] && mgr="dnf"
    docker_remove_conflicts_rpm

    if [ "$OS_ID" = "amzn" ]; then
        # A AWS não é servida por download.docker.com; o pacote 'docker' do
        # repositório da Amazon É o Docker CE empacotado por eles.
        log_info "Amazon Linux — instalando o pacote 'docker' do repositório da AWS."
        pkg_install docker || return 1
        pkg_install docker-compose-plugin 2>/dev/null || true
        return 0
    fi

    # Escrever o .repo direto evita toda a bagunça do 'config-manager':
    # dnf4 usa `--add-repo URL`, dnf5 usa `addrepo --from-repofile=URL`, e o
    # subcomando ainda depende de dnf-plugins-core / dnf5-plugins. Baixar o
    # arquivo com curl funciona igual em dnf4, dnf5, yum e microdnf.
    if ! curl -fsSL --max-time 30 --retry 3 \
        "${DOCKER_MIRROR}/${DOCKER_REPO_DISTRO}/docker-ce.repo" \
        -o /etc/yum.repos.d/docker-ce.repo; then
        log_error "Falha ao baixar docker-ce.repo de ${DOCKER_REPO_DISTRO}."
        return 1
    fi
    log_info "Repositório escrito em /etc/yum.repos.d/docker-ce.repo"

    run "$mgr" makecache -y >/dev/null 2>&1 || true

    # Cinto e suspensório: se o engine não estiver visível nesta árvore
    # (o caso de rocky/alma/oracle), troca para a árvore CentOS e refaz.
    if ! "$mgr" -q list --available docker-ce >/dev/null 2>&1 \
       && ! rpm -q docker-ce >/dev/null 2>&1 \
       && [ "$DOCKER_REPO_DISTRO" != "centos" ]; then
        log_warning "docker-ce não está disponível na árvore '${DOCKER_REPO_DISTRO}'; trocando para 'centos'."
        DOCKER_REPO_DISTRO="centos"
        curl -fsSL --max-time 30 --retry 3 \
            "${DOCKER_MIRROR}/centos/docker-ce.repo" -o /etc/yum.repos.d/docker-ce.repo || {
            log_error "Falha ao baixar docker-ce.repo do CentOS."; return 1; }
        run "$mgr" makecache -y >/dev/null 2>&1 || true
    fi

    run "$mgr" install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin || {
        # RHEL e derivados às vezes travam containerd.io por module stream
        log_warning "Instalação padrão falhou; tentando com --allowerasing / --nobest."
        run "$mgr" install -y --allowerasing --nobest docker-ce docker-ce-cli \
            containerd.io docker-buildx-plugin docker-compose-plugin || {
            log_error "Instalação dos pacotes do Docker falhou."; return 1; }
    }
}

install_docker_suse() {
    # A árvore download.docker.com/linux/sles/15 tem SOMENTE s390x (não existe
    # x86_64 lá) e a Docker não publica procedimento de instalação para SLES —
    # docs.docker.com/engine/install/sles/ responde 404. Em x86_64/aarch64 a via
    # correta é o pacote 'docker' mantido pela própria SUSE.
    if { [ "$OS_ID" = "sles" ] || [ "$OS_ID" = "sled" ]; } && [ "$CPU_ARCH" = "s390x" ]; then
        run rpm --import "${DOCKER_MIRROR}/sles/gpg" 2>/dev/null || true
        run zypper --non-interactive addrepo --refresh \
            "${DOCKER_MIRROR}/sles/15/s390x/${DOCKER_CHANNEL}" docker-ce-stable 2>/dev/null || true
        run zypper --non-interactive --gpg-auto-import-keys refresh
        if run zypper --non-interactive install -y docker-ce docker-ce-cli containerd.io \
               docker-buildx-plugin docker-compose-plugin; then
            return 0
        fi
        log_warning "Repo Docker falhou no SLES s390x; caindo para o pacote da distribuição."
    else
        log_info "SUSE em ${CPU_ARCH}: a Docker não publica pacote para esta combinação — usando o 'docker' da distribuição."
    fi
    pkg_install docker docker-compose || return 1
}

install_docker_arch()   { pkg_install docker docker-buildx docker-compose || return 1; }
install_docker_alpine() { pkg_install docker docker-cli-compose docker-cli-buildx || return 1; }

install_docker_fallback() {
    log_warning "Usando o instalador oficial de conveniência (https://get.docker.com)."
    have curl || { log_error "curl é necessário para o fallback."; return 1; }
    local sh; sh="$(mktemp)" || return 1
    if ! curl -fsSL --max-time 60 --retry 3 https://get.docker.com -o "$sh"; then
        rm -f "$sh"; log_error "Falha ao baixar get.docker.com."; return 1
    fi
    run sh "$sh" || { rm -f "$sh"; log_error "get.docker.com falhou."; return 1; }
    rm -f "$sh"
}

# --- Backend de iptables ----------------------------------------------------
# Historicamente o Docker quebrava com o backend nft em algumas distros. Hoje o
# Docker fala nftables nativamente e forçar 'legacy' pode ser PIOR (em Debian 13
# o pacote iptables pode nem trazer mais o binário legacy). Então: só reportamos,
# e só trocamos se o legacy existir E o usuário pedir depois de um erro real.
report_iptables_backend() {
    have iptables || { log_info "iptables não instalado (o Docker traz o que precisa)."; return 0; }
    local backend="desconhecido"
    if iptables --version 2>/dev/null | grep -q 'nf_tables'; then backend="nf_tables"
    elif iptables --version 2>/dev/null | grep -q 'legacy';  then backend="legacy"; fi
    log_info "Backend de iptables: ${backend}"
    if [ "$backend" = "nf_tables" ] && [ ! -x /usr/sbin/iptables-legacy ]; then
        log_info "Sem binário iptables-legacy nesta distro — normal em Debian 13+; o Docker usa nftables."
    fi
}

install_docker() {
    step_skipped docker && return 0
    if have docker && docker version >/dev/null 2>&1 && state_is_done DOCKER_INSTALLED; then
        check_step DOCKER_INSTALLED "Instalar Docker CE" || {
            log_info "Docker já instalado: $(docker version --format '{{.Server.Version}}' 2>/dev/null)"
            return 0; }
    fi
    log_step "Docker CE"

    local ok=1
    case "$OS_FAMILY" in
        debian) if [ -n "$DOCKER_REPO_DISTRO" ] && [ -n "$DOCKER_REPO_SUITE" ]; then
                    install_docker_deb && ok=0
                fi ;;
        rhel)   install_docker_rpm    && ok=0 ;;
        suse)   install_docker_suse   && ok=0 ;;
        arch)   install_docker_arch   && ok=0 ;;
        alpine) install_docker_alpine && ok=0 ;;
    esac

    if [ "$ok" -ne 0 ]; then
        log_warning "Caminho nativo indisponível ou falhou nesta distribuição."
        install_docker_fallback && ok=0
    fi
    [ "$ok" -eq 0 ] || { log_error "Não foi possível instalar o Docker."; return 1; }

    report_iptables_backend

    svc_enable_now docker    || log_warning "Não consegui habilitar o serviço docker."
    svc_enable_now containerd 2>/dev/null || true

    # O daemon pode levar alguns segundos para abrir o socket
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        docker version >/dev/null 2>&1 && break
        sleep 2
    done

    if docker version >/dev/null 2>&1; then
        state_set DOCKER_INSTALLED true
        log_success "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null) instalado."
        log_info "Compose: $(docker compose version --short 2>/dev/null || echo 'n/d') · Buildx: $(docker buildx version 2>/dev/null | awk '{print $2}' || echo 'n/d')"
    else
        log_error "O Docker instalou mas não responde. Verifique: journalctl -u docker -n 80 --no-pager"
        return 1
    fi
}

# ============================================================================
#  /etc/docker/daemon.json
# ============================================================================
configure_docker_daemon() {
    step_skipped daemon && return 0
    check_step DOCKER_DAEMON_CONFIGURED "Configurar daemon.json" || return 0
    log_step "daemon.json"

    run mkdir -p /etc/docker

    if [ -s /etc/docker/daemon.json ]; then
        local bkp
        bkp="/etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)"
        cp -a /etc/docker/daemon.json "$bkp" 2>/dev/null || true
        log_warning "daemon.json existente salvo em ${bkp} — será substituído."
        ask_yn "Substituir o /etc/docker/daemon.json atual?" "y" || {
            log_info "Mantendo o daemon.json existente."; return 0; }
    fi

    # NOTAS:
    #  • live-restore é INCOMPATÍVEL com swarm mode — o daemon recusa subir.
    #    Por isso ele NÃO aparece aqui. Não adicione.
    #  • default-address-pools aqui vale para as redes LOCAIS (bridge). O pool
    #    das OVERLAY é definido no `docker swarm init --default-addr-pool`.
    #  • log-opts é o que impede o disco de encher: o padrão json-file não
    #    rotaciona nada.
    # 'compress' só existe no json-file; o driver 'local' já comprime sozinho.
    local log_opts='"max-size": "50m", "max-file": "5"'
    [ "$DOCKER_LOG_DRIVER" = "json-file" ] && log_opts="${log_opts}, \"compress\": \"true\""

    write_file /etc/docker/daemon.json <<EOF
{
  "log-driver": "${DOCKER_LOG_DRIVER}",
  "log-opts": { ${log_opts} },
  "default-address-pools": [
    { "base": "${DOCKER_ADDR_POOL_BASE}", "size": ${DOCKER_ADDR_POOL_SIZE} }
  ],
  "storage-driver": "overlay2",
  "live-restore": false,
  "features": { "buildkit": true },
  "default-ulimits": {
    "nofile": { "Name": "nofile", "Hard": 1048576, "Soft": 1048576 }
  }
}
EOF

    if have python3; then
        python3 -c 'import json,sys; json.load(open("/etc/docker/daemon.json"))' 2>/dev/null || {
            log_error "daemon.json gerado é JSON inválido — abortando para não derrubar o daemon."; return 1; }
    fi

    if ! svc_restart docker; then
        log_error "Docker não reiniciou com o novo daemon.json. Veja: journalctl -u docker -n 80 --no-pager"
        return 1
    fi

    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do docker info >/dev/null 2>&1 && break; sleep 2; done
    if docker info >/dev/null 2>&1; then
        state_set DOCKER_DAEMON_CONFIGURED true
        log_success "daemon.json aplicado (driver=${DOCKER_LOG_DRIVER}, rotação 50m × 5)."
    else
        log_error "Docker não respondeu após o restart."
        return 1
    fi
}

# ============================================================================
#  PERMISSÕES
# ============================================================================
setup_docker_permissions() {
    step_skipped permissions && return 0
    check_step DOCKER_PERMISSIONS_CONFIGURED "Permissões do Docker" || return 0
    log_step "Permissões"

    local user="${SYSTEM_USER:-}"
    [ -n "$user" ] || user="${SUDO_USER:-root}"

    if [ "$user" = "root" ]; then
        log_info "Usuário é root — nada a fazer (root já fala com o socket)."
        state_set DOCKER_PERMISSIONS_CONFIGURED true
        return 0
    fi
    if ! id -u "$user" >/dev/null 2>&1; then
        log_error "Usuário '${user}' não existe. Pulando."
        return 0
    fi

    run groupadd -f docker 2>/dev/null || true
    run usermod -aG docker "$user" || { log_error "Falha ao adicionar ${user} ao grupo docker."; return 1; }

    # Deliberadamente NÃO mexemos em /var/lib/docker/volumes. A versão antiga
    # fazia `chmod -R 777` ali, o que deixa todo dado de volume aberto para
    # qualquer usuário local. O grupo 'docker' já é suficiente.
    log_warning "Estar no grupo 'docker' equivale a root nesta máquina — conceda só a quem administra."

    state_set DOCKER_PERMISSIONS_CONFIGURED true
    log_success "Usuário '${user}' adicionado ao grupo docker (exige logout/login)."
}

# ============================================================================
#  FIREWALL
# ============================================================================
#  Três coisas que a versão antiga errava e que valem ser lidas antes de mexer:
#
#  1) PORTA PUBLICADA DE CONTAINER NÃO PASSA PELO INPUT.
#     O Docker faz DNAT em PREROUTING e o pacote segue por FORWARD. Ou seja:
#     `ufw deny 9000` NÃO fecha uma porta que o Docker publicou. O ponto de
#     filtragem correto para tráfego de container é a chain DOCKER-USER.
#     As portas do Swarm (2377/7946/4789) SÃO do host, então o INPUT vale.
#
#  2) `nft flush ruleset` APAGA AS CHAINS DO DOCKER.
#     A doc do Docker é explícita: "Firewall rules created with nft are not
#     supported on a system with Docker installed". Por isso o modo padrão
#     aqui é CIRÚRGICO: uma tabela própria que só restringe as portas do
#     Swarm, sem política default DROP e sem encostar no que o Docker criou.
#
#  3) OVERLAY COM `encrypted=true` USA IPsec ESP (protocolo IP 50).
#     Abrir só 2377/7946/4789 e ligar criptografia na overlay faz o tráfego
#     entre containers sumir sem log. Aqui o ESP é liberado junto.
# ----------------------------------------------------------------------------

FW_PEERS=()

collect_cluster_peers() {
    FW_PEERS=()
    local entry ip

    for entry in "${CLUSTER_PEERS[@]:-}"; do
        [ -n "$entry" ] || continue
        ip="${entry%%:*}"
        [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && FW_PEERS+=("$ip")
    done

    # Se o nó já está no Swarm, os peers reais valem mais que qualquer lista.
    if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q active; then
        local node_ids=() nid
        while IFS= read -r nid; do [ -n "$nid" ] && node_ids+=("$nid"); done \
            < <(docker node ls -q 2>/dev/null || true)
        if [ "${#node_ids[@]}" -gt 0 ]; then
            while IFS= read -r ip; do
                [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || continue
                case " ${FW_PEERS[*]:-} " in *" $ip "*) ;; *) FW_PEERS+=("$ip") ;; esac
            done < <(docker node inspect "${node_ids[@]}" \
                       --format '{{.Status.Addr}}' 2>/dev/null || true)
        fi
    fi

    if [ "${#FW_PEERS[@]}" -eq 0 ]; then
        log_warning "Nenhum peer conhecido do cluster."
        local answer
        answer="$(ask_text "IPs dos nós do cluster, separados por vírgula (vazio = não restringir)" "")"
        if [ -n "$answer" ]; then
            local old_ifs="$IFS"; IFS=','
            for ip in $answer; do
                ip="${ip// /}"
                [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && FW_PEERS+=("$ip")
            done
            IFS="$old_ifs"
        fi
    fi
}

node_is_edge() {
    local h; h="$(hostname -s 2>/dev/null)"
    local e
    for e in "${EDGE_HOSTNAMES[@]:-}"; do
        [ "$e" = "$h" ] && return 0
    done
    [ "${NODE_IS_EDGE:-false}" = "true" ] && return 0
    return 1
}

fw_backend_detect() {
    if have firewall-cmd && systemctl is-active firewalld >/dev/null 2>&1; then printf 'firewalld'; return; fi
    if have ufw && ufw status 2>/dev/null | head -1 | grep -qi active;       then printf 'ufw';       return; fi
    if have nft;                                                             then printf 'nftables';  return; fi
    if have firewall-cmd;                                                    then printf 'firewalld'; return; fi
    if have ufw;                                                             then printf 'ufw';       return; fi
    if have iptables;                                                        then printf 'iptables';  return; fi
    printf 'none'
}

# --- nftables cirúrgico -----------------------------------------------------
# Tabela própria (inet swarm_guard). Prioridade -10 → roda ANTES do filtro
# padrão, decide sobre as portas do Swarm e não interfere no resto.
fw_apply_nftables() {
    local peers_csv="$1" edge="$2"
    local conf=/etc/nftables.d/swarm-guard.nft

    run mkdir -p /etc/nftables.d

    {
        printf '#!/usr/sbin/nft -f\n'
        printf '# Gerado por %s v%s — NÃO faz flush ruleset (isso apagaria as chains do Docker).\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"
        printf 'table inet swarm_guard\n'
        printf 'delete table inet swarm_guard\n'
        printf 'table inet swarm_guard {\n'
        if [ -n "$peers_csv" ]; then
            printf '    set peers {\n        type ipv4_addr\n        elements = { %s }\n    }\n\n' "$peers_csv"
        fi
        printf '    chain input {\n'
        printf '        type filter hook input priority -10; policy accept;\n\n'
        printf '        iif lo accept\n'
        printf '        ct state established,related accept\n\n'
        if [ -n "$peers_csv" ]; then
            printf '        # Plano de controle do Swarm: só entre os nós do cluster.\n'
            printf '        ip saddr @peers tcp dport 2377 accept comment "swarm control"\n'
            printf '        ip saddr @peers tcp dport 7946 accept comment "swarm gossip tcp"\n'
            printf '        ip saddr @peers udp dport 7946 accept comment "swarm gossip udp"\n'
            printf '        ip saddr @peers udp dport 4789 accept comment "swarm vxlan"\n'
            printf '        ip saddr @peers meta l4proto esp accept comment "overlay encrypted (IPsec ESP)"\n'
            printf '        ip saddr @peers tcp dport 9323 accept comment "docker metrics"\n\n'
            printf '        # Qualquer outra origem nessas portas é descartada.\n'
            printf '        tcp dport { 2377, 7946 } drop\n'
            printf '        udp dport { 7946, 4789 } drop\n'
            printf '        meta l4proto esp drop\n'
            printf '        tcp dport 9323 drop\n'
        else
            printf '        # Sem lista de peers: nada é restringido (só documenta as portas).\n'
        fi
        printf '    }\n'
        printf '}\n'
    } | write_file "$conf"

    run chmod 600 "$conf"

    if ! nft -c -f "$conf" >/dev/null 2>&1; then
        log_error "Sintaxe nftables inválida — nada foi aplicado. Saída do teste:"
        nft -c -f "$conf" 2>&1 | head -10
        return 1
    fi

    run nft -f "$conf" || { log_error "Falha ao aplicar as regras nftables."; return 1; }

    # Persistência entre reboots
    if [ -f /etc/nftables.conf ] && ! grep -q 'nftables.d/swarm-guard.nft' /etc/nftables.conf; then
        printf '\ninclude "/etc/nftables.d/swarm-guard.nft"\n' | append_file /etc/nftables.conf
    elif [ ! -f /etc/nftables.conf ]; then
        printf '#!/usr/sbin/nft -f\ninclude "/etc/nftables.d/swarm-guard.nft"\n' | write_file /etc/nftables.conf
    fi
    svc_enable_now nftables 2>/dev/null || log_warning "Habilite o serviço nftables para as regras sobreviverem ao reboot."

    [ "$edge" = "yes" ] && log_info "Nó edge: 80/443 seguem abertas (o Docker publica direto, sem passar pelo INPUT)."
    return 0
}

fw_apply_firewalld() {
    local edge="$2" ip
    svc_enable_now firewalld || true

    if [ "${#FW_PEERS[@]}" -gt 0 ]; then
        # NÃO usar --zone=trusted: aquela zona aceita TODO tráfego da origem,
        # não só as portas do Swarm — seria abrir o host inteiro para os peers.
        # Rich rules na zona real restringem por porta E por origem.
        local zone
        zone="$(firewall-cmd --get-default-zone 2>/dev/null || echo public)"
        for ip in "${FW_PEERS[@]}"; do
            run firewall-cmd --permanent --zone="$zone" \
                --add-rich-rule="rule family=ipv4 source address=${ip}/32 port port=2377 protocol=tcp accept" >/dev/null 2>&1 || true
            run firewall-cmd --permanent --zone="$zone" \
                --add-rich-rule="rule family=ipv4 source address=${ip}/32 port port=7946 protocol=tcp accept" >/dev/null 2>&1 || true
            run firewall-cmd --permanent --zone="$zone" \
                --add-rich-rule="rule family=ipv4 source address=${ip}/32 port port=7946 protocol=udp accept" >/dev/null 2>&1 || true
            run firewall-cmd --permanent --zone="$zone" \
                --add-rich-rule="rule family=ipv4 source address=${ip}/32 port port=4789 protocol=udp accept" >/dev/null 2>&1 || true
            if [ "${OVERLAY_ENCRYPTED:-true}" = "true" ]; then
                run firewall-cmd --permanent --zone="$zone" \
                    --add-rich-rule="rule family=ipv4 source address=${ip}/32 protocol value=esp accept" >/dev/null 2>&1 || true
            fi
        done
        log_info "Portas do Swarm liberadas na zona '${zone}' só para: ${FW_PEERS[*]}"
    else
        log_warning "Sem peers definidos — abrindo as portas do Swarm para qualquer origem (menos seguro)."
        run firewall-cmd --permanent --add-port=2377/tcp >/dev/null 2>&1 || true
        run firewall-cmd --permanent --add-port=7946/tcp >/dev/null 2>&1 || true
        run firewall-cmd --permanent --add-port=7946/udp >/dev/null 2>&1 || true
        run firewall-cmd --permanent --add-port=4789/udp >/dev/null 2>&1 || true
        # Sem ESP a overlay criptografada perde TODO o tráfego entre nós,
        # silenciosamente. Se a criptografia está ligada, o ESP tem que abrir.
        if [ "${OVERLAY_ENCRYPTED:-true}" = "true" ]; then
            run firewall-cmd --permanent --add-protocol=esp >/dev/null 2>&1 || true
        fi
    fi

    run firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1 || true
    if [ "$edge" = "yes" ]; then
        run firewall-cmd --permanent --add-service=http  >/dev/null 2>&1 || true
        run firewall-cmd --permanent --add-service=https >/dev/null 2>&1 || true
    fi
    run firewall-cmd --reload >/dev/null 2>&1 || { log_error "firewall-cmd --reload falhou."; return 1; }
    return 0
}

fw_apply_ufw() {
    local edge="$2" ip
    # Nunca liberar "22" às cegas: se o sshd escuta em outra porta, ativar o
    # UFW logo depois tranca a sessão atual do lado de fora.
    local sshports=""
    sshports="$(sshd -T 2>/dev/null | awk '/^port /{print $2}')"
    # O fallback tem que olhar SÓ os sockets do próprio sshd. Um `ss -lntH` sem
    # filtro devolve qualquer serviço escutando — Postgres, Redis, MySQL — e
    # cada um viraria um `ufw allow` aberto para a internet. Pior: com
    # `sort -u` lexicográfico + `head -5`, a porta real do SSH podia ficar de
    # fora justamente antes do `ufw --force enable`.
    [ -n "$sshports" ] || sshports="$(ss -lntpH 2>/dev/null | awk '/"sshd"/{n=split($4,a,":"); print a[n]}')"
    sshports="$(printf '%s\n' "$sshports" | grep -E '^[0-9]+$' | sort -un)"
    [ -n "$sshports" ] || sshports=22
    local sp
    for sp in $sshports; do
        run ufw allow "${sp}/tcp" >/dev/null 2>&1 || true
    done
    log_info "SSH liberado no UFW nas portas: $(echo $sshports | tr '\n' ' ')"

    if [ "${#FW_PEERS[@]}" -gt 0 ]; then
        for ip in "${FW_PEERS[@]}"; do
            run ufw allow from "$ip" to any port 2377 proto tcp >/dev/null 2>&1 || true
            run ufw allow from "$ip" to any port 7946 proto tcp >/dev/null 2>&1 || true
            run ufw allow from "$ip" to any port 7946 proto udp >/dev/null 2>&1 || true
            run ufw allow from "$ip" to any port 4789 proto udp >/dev/null 2>&1 || true
            run ufw allow from "$ip" proto esp                  >/dev/null 2>&1 || true
        done
        log_info "Portas do Swarm liberadas só para: ${FW_PEERS[*]}"
    else
        log_warning "Sem peers definidos — abrindo as portas do Swarm para qualquer origem (menos seguro)."
        run ufw allow 2377/tcp >/dev/null 2>&1 || true
        run ufw allow 7946     >/dev/null 2>&1 || true
        run ufw allow 4789/udp >/dev/null 2>&1 || true
        # ESP: sem isso a overlay criptografada perde tudo entre nós.
        if [ "${OVERLAY_ENCRYPTED:-true}" = "true" ]; then
            run ufw allow proto esp >/dev/null 2>&1 || true
        fi
    fi

    if [ "$edge" = "yes" ]; then
        run ufw allow 80/tcp  >/dev/null 2>&1 || true
        run ufw allow 443/tcp >/dev/null 2>&1 || true
    fi

    if ! ufw status 2>/dev/null | head -1 | grep -qi active; then
        if ask_yn "O UFW está inativo. Ativar agora? (o acesso SSH já foi liberado)" "y"; then
            run ufw --force enable >/dev/null 2>&1 || { log_error "Falha ao ativar o UFW."; return 1; }
        else
            log_warning "UFW permanece inativo — as regras existem mas não estão valendo."
        fi
    fi
    log_warning "Lembrete: o UFW NÃO filtra portas publicadas por containers (o Docker faz DNAT antes). Use a chain DOCKER-USER para isso."
    return 0
}

fw_apply_iptables() {
    local edge="$2" ip
    if [ "${#FW_PEERS[@]}" -gt 0 ]; then
        for ip in "${FW_PEERS[@]}"; do
            run iptables -I INPUT -s "$ip" -p tcp --dport 2377 -j ACCEPT 2>/dev/null || true
            run iptables -I INPUT -s "$ip" -p tcp --dport 7946 -j ACCEPT 2>/dev/null || true
            run iptables -I INPUT -s "$ip" -p udp --dport 7946 -j ACCEPT 2>/dev/null || true
            run iptables -I INPUT -s "$ip" -p udp --dport 4789 -j ACCEPT 2>/dev/null || true
            run iptables -I INPUT -s "$ip" -p esp -j ACCEPT               2>/dev/null || true
        done
        run iptables -A INPUT -p tcp --dport 2377 -j DROP 2>/dev/null || true
        run iptables -A INPUT -p tcp --dport 7946 -j DROP 2>/dev/null || true
        run iptables -A INPUT -p udp --dport 7946 -j DROP 2>/dev/null || true
        run iptables -A INPUT -p udp --dport 4789 -j DROP 2>/dev/null || true
    fi
    log_warning "Regras iptables aplicadas em memória. Instale iptables-persistent/netfilter-persistent para sobreviverem ao reboot."
    return 0
}

# Desfaz o que fw_apply_nftables criou.
# ARMADILHA: `nft -f <dump de "nft list ruleset">` é ADITIVO — ao contrário de
# iptables-restore, ele NÃO substitui o ruleset. Restaurar um snapshot assim
# deixa a tabela swarm_guard de pé E duplica todas as regras que já existiam.
# Como swarm_guard é uma tabela isolada, o desfazer correto é deletá-la.
fw_nft_undo() {
    nft delete table inet swarm_guard >/dev/null 2>&1 || true
    rm -f /etc/nftables.d/swarm-guard.nft 2>/dev/null || true
    sed -i '\#nftables.d/swarm-guard.nft#d' /etc/nftables.conf 2>/dev/null || true
    return 0
}

# --- Aplicação com rollback automático --------------------------------------
# Se você perder o acesso, as regras voltam sozinhas. O relógio só para quando
# você confirmar que ainda consegue falar com a máquina.
fw_with_rollback() {
    local backend="$1" peers_csv="$2" edge="$3"
    local snapshot="" sentinel="$STATE_DIR/.fw_confirmed" guard_pid=""

    rm -f "$sentinel"

    if [ "$backend" = "nftables" ] && have nft; then
        # Guardado só para perícia — o desfazer real é fw_nft_undo (ver acima).
        snapshot="$STATE_DIR/nft-ruleset.before"
        nft list ruleset > "$snapshot" 2>/dev/null || snapshot=""
        chmod 600 "$snapshot" 2>/dev/null || true
    fi

    if [ "$OPT_NONINTERACTIVE" != "1" ] && [ -n "$snapshot" ]; then
        (
            sleep 120
            if [ ! -f "$sentinel" ]; then
                fw_nft_undo
                logger -t swarm-installer "firewall revertido automaticamente (sem confirmação em 120s)" 2>/dev/null || true
            fi
        ) &
        guard_pid=$!
        log_warning "Rede de segurança armada: se você não confirmar em 120s, o firewall volta ao estado anterior."
    fi

    local rc=0
    case "$backend" in
        nftables)  fw_apply_nftables  "$peers_csv" "$edge" || rc=1 ;;
        firewalld) fw_apply_firewalld "$peers_csv" "$edge" || rc=1 ;;
        ufw)       fw_apply_ufw       "$peers_csv" "$edge" || rc=1 ;;
        iptables)  fw_apply_iptables  "$peers_csv" "$edge" || rc=1 ;;
        *)         log_warning "Nenhum backend de firewall disponível — pulando."; rc=2 ;;
    esac

    if [ -n "$guard_pid" ]; then
        if [ "$rc" -eq 0 ]; then
            printf '\n%sConfirme que você AINDA consegue acessar esta máquina.%s\n' "$BOLD$YELLOW" "$NC"
            printf 'Abra outro terminal e teste o SSH antes de responder.\n'
            if ask_yn "Continuo com acesso — manter as novas regras?" "y"; then
                touch "$sentinel"
                kill "$guard_pid" 2>/dev/null || true
                log_success "Regras confirmadas."
            else
                kill "$guard_pid" 2>/dev/null || true
                fw_nft_undo
                log_warning "Regras revertidas a pedido."
                return 1
            fi
        else
            kill "$guard_pid" 2>/dev/null || true
            fw_nft_undo
        fi
    fi
    return "$rc"
}

configure_firewall() {
    step_skipped firewall && return 0
    check_step FIREWALL_CONFIGURED "Configurar firewall" || return 0
    log_step "Firewall"

    local backend; backend="$(fw_backend_detect)"
    if [ "$backend" = "none" ]; then
        log_warning "Nenhuma ferramenta de firewall encontrada (nft/firewalld/ufw/iptables). Pulando."
        return 0
    fi
    log_info "Backend detectado: ${backend}"

    collect_cluster_peers
    local peers_csv=""
    [ "${#FW_PEERS[@]}" -gt 0 ] && peers_csv="$(IFS=, ; printf '%s' "${FW_PEERS[*]}")"

    local edge="no"
    if node_is_edge; then
        edge="yes"
    elif ask_yn "Este nó expõe 80/443 para a internet (roda o Traefik)?" "n"; then
        edge="yes"
    fi
    state_set NODE_IS_EDGE "$([ "$edge" = "yes" ] && echo true || echo false)"

    printf '\n%sO que será aplicado:%s\n' "$BOLD" "$NC"
    printf '  backend ............ %s\n' "$backend"
    printf '  peers do cluster ... %s\n' "${peers_csv:-<nenhum — sem restrição>}"
    printf '  nó edge (80/443) ... %s\n' "$edge"
    printf '  portas restritas ... 2377/tcp 7946/tcp+udp 4789/udp ESP(50) 9323/tcp\n'
    printf '  SSH (22) ........... permanece aberto\n\n'

    ask_yn "Aplicar?" "y" || { log_info "Firewall não alterado."; return 0; }

    if fw_with_rollback "$backend" "$peers_csv" "$edge"; then
        state_set FIREWALL_BACKEND "$backend"
        state_set FIREWALL_CONFIGURED true
        log_success "Firewall configurado com ${backend}."
    else
        log_warning "Firewall não foi aplicado."
    fi
}

# ============================================================================
#  HARDENING DE SSH  (com trava anti-lockout)
# ============================================================================
configure_ssh_hardening() {
    step_skipped ssh && return 0
    check_step SSH_HARDENED "Hardening de SSH" || return 0
    log_step "SSH"

    ask_yn "Desabilitar autenticação por senha e exigir chave?" "n" || {
        log_info "SSH inalterado."; return 0; }

    # Pré-checagem obrigatória: sem chave em authorized_keys, desabilitar senha
    # é trancar a porta com a chave do lado de dentro.
    local key_count=0 files=() f n home
    for home in /root /home/*; do
        [ -d "$home" ] || continue
        f="$home/.ssh/authorized_keys"
        [ -s "$f" ] || continue
        n="$(grep -cE '^[[:space:]]*(ssh-|ecdsa-|sk-)' "$f" 2>/dev/null || true)"
        n="${n:-0}"
        [ "$n" -gt 0 ] && { key_count=$((key_count + n)); files+=("$f"); }
    done

    if [ "$key_count" -eq 0 ]; then
        log_error "Nenhuma chave pública encontrada em authorized_keys."
        log_error "Desabilitar a senha agora deixaria você TRANCADO FORA desta máquina."
        printf '\n%sComo resolver:%s\n' "$BOLD" "$NC"
        printf '  1. Na sua máquina:  ssh-keygen -t ed25519 -f ~/.ssh/%s\n' "$(hostname -s 2>/dev/null || echo servidor)"
        printf '  2. Copie a chave:   ssh-copy-id -i ~/.ssh/%s.pub root@<IP>\n' "$(hostname -s 2>/dev/null || echo servidor)"
        printf '  3. Teste em OUTRO terminal: ssh -i ~/.ssh/%s root@<IP>  (sem pedir senha)\n' "$(hostname -s 2>/dev/null || echo servidor)"
        printf '  4. Rode este instalador de novo e escolha o hardening.\n\n'
        log_warning "Hardening CANCELADO. A autenticação por senha continua ativa."
        return 0
    fi
    log_success "${key_count} chave(s) encontrada(s) em: ${files[*]}"

    local sshd=/etc/ssh/sshd_config
    [ -f "$sshd" ] || { log_warning "Sem ${sshd} — servidor SSH não instalado?"; return 0; }
    cp -a "$sshd" "${sshd}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

    # Preferir o drop-in quando existe Include (padrão em Debian 13 / Ubuntu 22+):
    # editar o arquivo principal pode ser sobrescrito por um .conf posterior.
    if [ -d /etc/ssh/sshd_config.d ] && grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' "$sshd"; then
        write_file /etc/ssh/sshd_config.d/99-swarm-hardening.conf <<'EOF'
# Hardening aplicado pelo instalador do cluster Swarm
PasswordAuthentication no
PermitRootLogin prohibit-password
# KbdInteractiveAuthentication é o nome atual (OpenSSH 8.7+);
# ChallengeResponseAuthentication virou alias obsoleto.
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 4
LoginGraceTime 30
EOF
        run chmod 600 /etc/ssh/sshd_config.d/99-swarm-hardening.conf
        log_info "Aplicado via /etc/ssh/sshd_config.d/99-swarm-hardening.conf"
    else
        run sed -i -E 's/^[[:space:]]*#?[[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/'         "$sshd"
        run sed -i -E 's/^[[:space:]]*#?[[:space:]]*PermitRootLogin.*/PermitRootLogin prohibit-password/'         "$sshd"
        run sed -i -E 's/^[[:space:]]*#?[[:space:]]*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "$sshd"
        grep -qE '^KbdInteractiveAuthentication' "$sshd" || printf 'KbdInteractiveAuthentication no\n' >> "$sshd"
    fi

    if have sshd && ! sshd -t 2>/dev/null; then
        log_error "Configuração de SSH inválida — revertendo."
        rm -f /etc/ssh/sshd_config.d/99-swarm-hardening.conf
        sshd -t 2>&1 | head -5
        return 1
    fi

    svc_restart ssh 2>/dev/null || svc_restart sshd 2>/dev/null || \
        run systemctl reload ssh 2>/dev/null || true

    state_set SSH_HARDENED true
    log_success "SSH endurecido — só chave a partir de agora."
    log_warning "NÃO feche esta sessão antes de confirmar em outro terminal que o login por chave funciona."
}

# ============================================================================
#  SWARM — init / join
# ============================================================================
detect_primary_ip() {
    local ip=""
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
    [ -n "$ip" ] || ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    printf '%s' "$ip"
}

setup_docker_swarm() {
    step_skipped swarm && return 0
    check_step SWARM_INITIALIZED "Inicializar/ingressar no Swarm" || return 0
    log_step "Docker Swarm"

    local swarm_state
    swarm_state="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo inactive)"
    if [ "$swarm_state" = "active" ]; then
        local is_mgr; is_mgr="$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)"
        log_info "Este nó já está no Swarm ($([ "$is_mgr" = "true" ] && echo manager || echo worker))."
        state_set SWARM_INITIALIZED true
        [ "$is_mgr" = "true" ] && state_set NODE_TYPE manager || state_set NODE_TYPE worker
        return 0
    fi

    local role
    role="$(ask_choice "Qual o papel deste nó?" "1" \
        "manager-leader   (primeiro nó — executa 'docker swarm init')" \
        "manager-follower (2º/3º manager — join com token de manager)" \
        "worker           (join com token de worker)")"

    local node_role node_type
    case "$role" in
        manager-leader*)   node_role="manager-leader"   ; node_type="manager" ;;
        manager-follower*) node_role="manager-follower" ; node_type="manager" ;;
        worker*)           node_role="worker"           ; node_type="worker"  ;;
        *)  # catch-all silencioso vira degradação invisível — melhor falhar alto
            log_error "Papel de nó não reconhecido: '${role}'"
            return 1 ;;
    esac
    state_set NODE_ROLE "$node_role"
    state_set NODE_TYPE "$node_type"

    local default_ip advertise_ip
    default_ip="$(detect_primary_ip)"
    advertise_ip="$(ask_text "IP que este nó anuncia no Swarm" "$default_ip")"
    if ! [[ "$advertise_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        log_error "IP inválido: '${advertise_ip}'"; return 1
    fi
    if ! ip -4 addr show 2>/dev/null | grep -qw "$advertise_ip"; then
        log_warning "O IP ${advertise_ip} não aparece nas interfaces locais."
        ask_yn "Usar mesmo assim (NAT 1:1 / IP flutuante)?" "n" || return 1
    fi
    state_set NODE_ADVERTISE_IP "$advertise_ip"

    if [ "$node_role" = "manager-leader" ]; then
        log "Inicializando o Swarm em ${advertise_ip}…"
        # ATENÇÃO: --default-addr-pool só pode ser definido AQUI. Não existe
        # 'docker swarm update --default-addr-pool'. Errar agora custa recriar
        # o cluster inteiro depois.
        run docker swarm init \
            --advertise-addr "$advertise_ip" \
            --listen-addr "${advertise_ip}:2377" \
            --default-addr-pool "$SWARM_ADDR_POOL_BASE" \
            --default-addr-pool-mask-length "$SWARM_ADDR_POOL_SIZE" \
            --task-history-limit 3 || { log_error "docker swarm init falhou."; return 1; }

        local mtok wtok
        mtok="$(docker swarm join-token manager -q 2>/dev/null)"
        wtok="$(docker swarm join-token worker  -q 2>/dev/null)"

        {
            printf '# Tokens de join — gerados em %s\n' "$(date)"
            printf '# Leader: %s\n\n' "$advertise_ip"
            printf 'MANAGER_TOKEN=%s\n' "$mtok"
            printf 'WORKER_TOKEN=%s\n'  "$wtok"
            printf 'MANAGER_ADDR=%s:2377\n\n' "$advertise_ip"
            printf '# Em um manager adicional:\n'
            printf 'docker swarm join --token %s %s:2377\n\n' "$mtok" "$advertise_ip"
            printf '# Em um worker:\n'
            printf 'docker swarm join --token %s %s:2377\n' "$wtok" "$advertise_ip"
        } > "$TOKEN_FILE"
        run chmod 600 "$TOKEN_FILE"

        printf '\n%s══════════════════ COMANDOS DE JOIN ══════════════════%s\n' "$YELLOW" "$NC"
        printf '%sManager:%s docker swarm join --token %s %s:2377\n' "$CYAN" "$NC" "$mtok" "$advertise_ip"
        printf '%sWorker: %s docker swarm join --token %s %s:2377\n' "$CYAN" "$NC" "$wtok" "$advertise_ip"
        printf '%s══════════════════════════════════════════════════════%s\n\n' "$YELLOW" "$NC"
        log_info "Também salvos em ${TOKEN_FILE} (chmod 600). Trate como segredo."
    else
        printf '\n%sNo manager-leader, rode:%s  docker swarm join-token %s\n\n' "$CYAN" "$NC" "$node_type"
        local join_cmd
        join_cmd="$(ask_text "Cole o comando completo de join" "")"
        # Nada de `eval` em texto colado: extrai token e endereço e monta o
        # comando nós mesmos. Colar algo malicioso deixa de virar execução.
        local token addr
        token="$(printf '%s' "$join_cmd" | grep -oE 'SWMTKN-[A-Za-z0-9_-]+' | head -1)"
        addr="$(printf '%s' "$join_cmd"  | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]+' | head -1)"
        if [ -z "$token" ] || [ -z "$addr" ]; then
            log_error "Não consegui extrair o token (SWMTKN-…) e o endereço IP:porta do texto colado."
            return 1
        fi
        log_info "Ingressando em ${addr}…"
        run docker swarm join \
            --token "$token" \
            --advertise-addr "$advertise_ip" \
            --listen-addr "${advertise_ip}:2377" \
            "$addr" || { log_error "docker swarm join falhou."; return 1; }
    fi

    state_set SWARM_INITIALIZED true
    log_success "Nó no Swarm como ${node_role}."
}

# ============================================================================
#  LABELS
# ============================================================================
setup_swarm_labels() {
    step_skipped labels && return 0
    check_step SWARM_LABELS_CONFIGURED "Labels dos nós" || return 0
    log_step "Labels"

    [ "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)" = "true" ] || {
        log_info "Labels só podem ser aplicadas a partir de um manager. Pulando."; return 0; }

    local applied=0 pending=0

    if [ "${#CLUSTER_LABELS[@]}" -gt 0 ]; then
        local spec host labels lbl
        for spec in "${CLUSTER_LABELS[@]}"; do
            host="${spec%%=*}"; labels="${spec#*=}"
            if ! docker node ls --format '{{.Hostname}}' 2>/dev/null | grep -qx "$host"; then
                log_warning "Nó '${host}' ainda não ingressou — labels adiadas."
                pending=$((pending + 1)); continue
            fi
            for lbl in $labels; do
                run docker node update --label-add "$lbl" "$host" >/dev/null 2>&1 \
                    && log_info "  ${host} ← ${lbl}" \
                    || log_warning "  falha em ${host} ← ${lbl}"
            done
            applied=$((applied + 1))
        done
    else
        ask_yn "Aplicar labels neste nó agora?" "y" || { log_info "Labels puladas."; return 0; }
        local me role env tier region
        me="$(docker info --format '{{.Swarm.NodeID}}' 2>/dev/null)"
        [ -n "$me" ] || { log_error "Não obtive o NodeID local."; return 1; }

        role="$(ask_text   "role   (ex.: edge, backend, db)"                "")"
        env="$(ask_text    "env    (ex.: production, staging)"             "production")"
        tier="$(ask_text   "tier   (ex.: frontend, backend)"               "")"
        region="$(ask_text "region (ex.: br-sp, us-east)"                  "")"

        local k v
        for kv in "role=$role" "env=$env" "tier=$tier" "region=$region"; do
            k="${kv%%=*}"; v="${kv#*=}"
            [ -n "$v" ] || continue
            run docker node update --label-add "${k}=${v}" "$me" >/dev/null 2>&1 \
                && log_info "  ${k}=${v}" \
                || log_warning "  falha em ${k}=${v}"
        done
        applied=1
    fi

    if [ "$pending" -gt 0 ]; then
        log_warning "${pending} nó(s) ainda fora do cluster — rode este passo de novo depois que entrarem."
        return 0
    fi
    [ "$applied" -gt 0 ] && state_set SWARM_LABELS_CONFIGURED true
    log_success "Labels aplicadas."
}

# ============================================================================
#  REDE OVERLAY
# ============================================================================
create_overlay_network() {
    step_skipped network && return 0
    check_step NETWORK_CREATED "Criar rede overlay" || return 0
    log_step "Rede overlay"

    [ "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)" = "true" ] || {
        log_info "A overlay é criada no manager. Pulando neste nó."; return 0; }

    local name="$OVERLAY_NAME"
    if docker network ls --format '{{.Name}}' 2>/dev/null | grep -qx "$name"; then
        log_info "Rede '${name}' já existe."
    else
        local args=( --driver overlay --attachable --scope swarm )
        [ -n "$OVERLAY_SUBNET" ] && args+=( --subnet "$OVERLAY_SUBNET" )
        if [ "$OVERLAY_ENCRYPTED" = "true" ]; then
            args+=( --opt encrypted )
            log_warning "Overlay criptografada: o firewall PRECISA liberar o protocolo IP 50 (ESP) entre os nós — já contemplado na etapa de firewall."
        fi
        run docker network create "${args[@]}" "$name" || {
            log_error "Falha ao criar a rede '${name}'."; return 1; }
        log_success "Rede '${name}' criada (${OVERLAY_SUBNET}, encrypted=${OVERLAY_ENCRYPTED})."
    fi

    state_set NETWORK_NAME "$name"
    state_set NETWORK_CREATED true
}

# ============================================================================
#  TRAEFIK  (provider Swarm do Traefik v3)
# ============================================================================
#  Erros do arquivo antigo, todos verificados na doc do v3, e como ficaram:
#
#  • `traefik.docker.network`  →  `traefik.swarm.network`.
#    O nome antigo ainda funciona, mas gera "Labels traefik.docker.* for Swarm
#    provider are deprecated". Definir OS DOIS falha duro com
#    "both Docker and Swarm labels are defined".
#
#  • Middleware referenciado como `nome@docker` não existe no namespace do
#    provider Swarm — o Traefik registra `middleware "x@docker" does not exist`
#    e descarta o router. Referências dentro do mesmo provider vão SEM sufixo.
#
#  • `hostregexp(`{host:.+}`)` é sintaxe do v2. No v3 o matcher usa regexp Go,
#    então `{host:.+}` compila como literal e NUNCA casa — 404 silencioso, sem
#    erro no log. O router catch-all foi removido: a redireção HTTP→HTTPS é
#    feita no entrypoint, que é o caminho documentado.
#
#  • Labels `traefik.http.middlewares.*` no PRÓPRIO serviço do Traefik fazem o
#    provider fabricar um service sem porta e logar
#    `service "traefik@swarm" error: port is missing` a cada refresh. Por isso
#    o Traefik aqui não carrega nenhuma label `traefik.*`.
#
#  • `--api.insecure=true` publicado na 8080 em mode host expõe o dashboard
#    sem autenticação. Agora o dashboard é opcional e vai atrás de
#    HTTPS + BasicAuth + regra de Host.
#
#  • `loadbalancer.server.port` é OBRIGATÓRIO no Swarm (o Swarm não informa
#    porta ao Traefik) — está presente em todos os consumidores.
# ----------------------------------------------------------------------------

# Uma tag pode existir no registry e mesmo assim ser impossível de baixar
# (índice OCI publicado sem nenhum manifesto — foi o caso de traefik:v3.7.11).
# Descobrir isso só quando o service entra em loop de restart custa caro.
ensure_image() {
    local image="$1"
    if docker manifest inspect "$image" >/dev/null 2>&1 || docker image inspect "$image" >/dev/null 2>&1; then
        return 0
    fi
    log_error "A imagem '${image}' não pode ser baixada (tag inexistente ou índice sem manifesto)."
    log_info  "Verifique as tags disponíveis e ajuste a variável de versão no topo do script."
    return 1
}

install_traefik() {
    step_skipped traefik && return 0
    check_step TRAEFIK_INSTALLED "Instalar Traefik" || return 0
    log_step "Traefik ${TRAEFIK_VERSION}"

    [ "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)" = "true" ] || {
        log_warning "O Traefik precisa rodar em um manager. Pulando."; return 0; }

    ask_yn "Instalar o Traefik ${TRAEFIK_VERSION} agora?" "y" || { log_info "Traefik pulado."; return 0; }

    ensure_image "traefik:${TRAEFIK_VERSION}" || return 1

    local net="${NETWORK_NAME:-$OVERLAY_NAME}"
    if ! docker network ls --format '{{.Name}}' 2>/dev/null | grep -qx "$net"; then
        log_warning "Rede '${net}' não existe — criando."
        run docker network create --driver overlay --attachable "$net" || {
            log_error "Falha ao criar '${net}'."; return 1; }
    fi

    local acme_email
    acme_email="$(ask_text "E-mail para o Let's Encrypt (ACME)" "")"
    if ! [[ "$acme_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        log_error "E-mail inválido: '${acme_email}'"; return 1
    fi

    # --- Desafio ACME --------------------------------------------------------
    local resolver="letsencrypt" use_dns01="no" cf_secret_ok="no"
    local CF_TOKEN_SECRET="" CF_EMAIL_SECRET=""
    if ask_yn "Usar desafio DNS-01 da Cloudflare (necessário para certificado curinga)?" "n"; then
        use_dns01="yes"; resolver="cloudflare"
        local cf_token cf_email
        cf_token="$(ask_text "Cloudflare API Token (Zone:Read + DNS:Edit)" "" --secret)"
        cf_email="$(ask_text "E-mail da conta Cloudflare" "$acme_email")"
        if [ -z "$cf_token" ]; then
            log_error "Token vazio — voltando para HTTP-01."; use_dns01="no"; resolver="letsencrypt"
        else
            # Segredo vai como Docker secret: não fica no stack file nem em env
            # legível por `docker service inspect`.
            # Secret em uso por um service NÃO pode ser removido — o
            # `docker secret rm` falha e o create seguinte também, deixando o
            # Traefik com o token velho. A saída é versionar o nome: o
            # `stack deploy` troca a referência e o antigo fica órfão.
            local sec_ver
            sec_ver="$(date +%Y%m%d%H%M%S)"
            CF_TOKEN_SECRET="cloudflare_api_token_${sec_ver}"
            CF_EMAIL_SECRET="cloudflare_email_${sec_ver}"
            printf '%s' "$cf_token" | docker secret create "$CF_TOKEN_SECRET" - >/dev/null 2>&1 \
                && printf '%s' "$cf_email" | docker secret create "$CF_EMAIL_SECRET" - >/dev/null 2>&1 \
                && cf_secret_ok="yes"
            [ "$cf_secret_ok" = "yes" ] || { log_error "Falha ao criar os secrets da Cloudflare."; return 1; }
            unset cf_token
            log_info "Secrets criados: ${CF_TOKEN_SECRET} / ${CF_EMAIL_SECRET}"
            log_info "Os secrets antigos ficam órfãos — remova depois com 'docker secret ls'."
        fi
    fi
    state_set TRAEFIK_RESOLVER "$resolver"

    # --- Dashboard (opcional, sempre autenticado) ----------------------------
    local dash="no" dash_domain="" dash_htpasswd=""
    if ask_yn "Publicar o dashboard do Traefik (HTTPS + usuário e senha)?" "n"; then
        dash_domain="$(ask_text "Domínio do dashboard (ex.: traefik.seudominio.com)" "")"
        if [[ "$dash_domain" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}$ ]]; then
            local du dp
            du="$(ask_text "Usuário do dashboard" "admin")"
            dp="$(ask_text "Senha do dashboard" "" --secret)"
            if [ -n "$dp" ]; then
                if have htpasswd; then
                    dash_htpasswd="$(htpasswd -nbB "$du" "$dp" 2>/dev/null)"
                elif have openssl; then
                    dash_htpasswd="${du}:$(openssl passwd -apr1 "$dp" 2>/dev/null)"
                fi
                unset dp
            fi
            if [ -n "$dash_htpasswd" ]; then
                # No label do compose, cada $ precisa virar $$ ou o Compose
                # tenta interpolar o hash do bcrypt como variável.
                dash_htpasswd="${dash_htpasswd//\$/\$\$}"
                dash="yes"
            else
                log_warning "Não consegui gerar o hash da senha — dashboard NÃO será publicado."
            fi
        else
            log_warning "Domínio inválido — dashboard NÃO será publicado."
        fi
    fi

    run docker volume create volume_certificates >/dev/null 2>&1 || true

    # volume_certificates usa o driver 'local': existe SÓ no disco deste nó.
    # Com a constraint apenas em node.role==manager, qualquer reagendamento
    # para outro manager sobe um Traefik sem o acme.json — ele reemite tudo e
    # bate no rate limit do Let's Encrypt. Marcamos o nó e prendemos o serviço.
    local pin_label="swarm_installer.traefik_data"
    local self_node
    self_node="$(docker info --format '{{.Swarm.NodeID}}' 2>/dev/null)"
    if [ -n "$self_node" ]; then
        run docker node update --label-add "${pin_label}=true" "$self_node" >/dev/null 2>&1 || true
    fi

    local f="$STATE_DIR/traefik.yaml"
    # Sem a chave `version:` de propósito: o `docker stack deploy` ainda usa o
    # loader legado v3 e, sem essa chave, ele adota o schema mais novo. Colocar
    # um valor sem schema empacotado (ex. "3.14") é erro fatal.
    {
        cat <<EOF
services:
  traefik:
    image: traefik:${TRAEFIK_VERSION}
    command:
      - "--global.checknewversion=false"
      - "--global.sendanonymoususage=false"
      - "--providers.swarm.endpoint=unix:///var/run/docker.sock"
      - "--providers.swarm.exposedByDefault=false"
      - "--providers.swarm.network=${net}"
      - "--providers.swarm.refreshSeconds=15"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.websecure.http.tls.certresolver=${resolver}"
      - "--entrypoints.websecure.transport.respondingTimeouts.readTimeout=600s"
EOF
        if [ "$use_dns01" = "yes" ]; then
            cat <<EOF
      - "--certificatesresolvers.cloudflare.acme.dnschallenge=true"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.cloudflare.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
      - "--certificatesresolvers.cloudflare.acme.email=${acme_email}"
      - "--certificatesresolvers.cloudflare.acme.storage=/etc/traefik/letsencrypt/acme.json"
EOF
        else
            cat <<EOF
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencrypt.acme.email=${acme_email}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/etc/traefik/letsencrypt/acme.json"
EOF
        fi
        [ "$dash" = "yes" ] && cat <<'EOF'
      - "--api.dashboard=true"
EOF
        cat <<'EOF'
      - "--log.level=INFO"
      - "--accesslog=true"
      - "--accesslog.format=json"
      - "--accesslog.filters.statuscodes=400-599"
      # ping fica no entrypoint interno 'traefik' (:8080), que NÃO é publicado.
      # Não aponte para 'web': a redireção 80→443 engole o /ping e o CLI
      # `traefik healthcheck --ping` (que consulta :8080) recebe 404 — o
      # container vira unhealthy e o Swarm o reinicia em loop.
      - "--ping=true"
      - "--metrics.prometheus=true"
      - "--metrics.prometheus.addEntryPointsLabels=true"
      - "--metrics.prometheus.addRoutersLabels=true"
      - "--metrics.prometheus.addServicesLabels=true"
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 20s
      timeout: 5s
      retries: 3
      start_period: 20s
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - "node.role == manager"
          # Prende ao nó dono do volume_certificates (driver local).
          - "node.labels.swarm_installer.traefik_data == true"
EOF
        if [ "$dash" = "yes" ]; then
            cat <<EOF
      labels:
        - "traefik.enable=true"
        - "traefik.swarm.network=${net}"
        - "traefik.http.routers.traefik-dash.rule=Host(\`${dash_domain}\`)"
        - "traefik.http.routers.traefik-dash.entrypoints=websecure"
        - "traefik.http.routers.traefik-dash.tls.certresolver=${resolver}"
        - "traefik.http.routers.traefik-dash.service=api@internal"
        - "traefik.http.routers.traefik-dash.middlewares=traefik-auth"
        - "traefik.http.middlewares.traefik-auth.basicauth.users=${dash_htpasswd}"
        # Porta obrigatória: sem ela o provider Swarm loga
        # 'service "traefik@swarm" error: port is missing' a cada refresh.
        - "traefik.http.services.traefik-dash-svc.loadbalancer.server.port=8080"
EOF
        else
            cat <<'EOF'
      # Nenhuma label traefik.* aqui de propósito — labels de middleware sem
      # router/porta no próprio Traefik geram 'port is missing' em loop.
EOF
        fi
        cat <<EOF
      update_config:
        parallelism: 1
        # stop-first, NÃO start-first: com replicas=1 e portas em mode host, a
        # task nova nunca consegue fazer bind em 80/443 enquanto a antiga
        # segura — o update trava até dar timeout e reverter.
        order: stop-first
        failure_action: rollback
        delay: 10s
      rollback_config:
        parallelism: 1
        order: stop-first
      restart_policy:
        condition: any
        delay: 5s
      resources:
        limits:   { cpus: "1.0", memory: 1024M }
        reservations: { cpus: "0.10", memory: 128M }
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - volume_certificates:/etc/traefik/letsencrypt
    networks:
      - ${net}
    ports:
      # mode host preserva o IP real do cliente (o ingress mesh do Swarm faz
      # SNAT e o Traefik passaria a ver só o IP interno).
      - { target: 80,  published: 80,  protocol: tcp, mode: host }
      - { target: 443, published: 443, protocol: tcp, mode: host }
EOF
        if [ "$use_dns01" = "yes" ]; then
            cat <<EOF
    environment:
      CF_API_EMAIL_FILE: /run/secrets/cloudflare_email
      CF_DNS_API_TOKEN_FILE: /run/secrets/cloudflare_api_token
    secrets:
      - source: ${CF_EMAIL_SECRET}
        target: cloudflare_email
      - source: ${CF_TOKEN_SECRET}
        target: cloudflare_api_token
EOF
        fi
        cat <<EOF

volumes:
  volume_certificates:
    external: true

networks:
  ${net}:
    external: true
EOF
        if [ "$use_dns01" = "yes" ]; then
            cat <<EOF

secrets:
  ${CF_EMAIL_SECRET}:
    external: true
  ${CF_TOKEN_SECRET}:
    external: true
EOF
        fi
    } > "$f"

    run chmod 600 "$f"
    log_info "Stack file: ${f}"

    run docker stack deploy --detach=false -c "$f" traefik || {
        log_error "Deploy do Traefik falhou. Confira ${f}."; return 1; }

    local i ok=1
    for i in $(seq 1 24); do
        if [ "$(docker service ls --filter name=traefik_traefik --format '{{.Replicas}}' 2>/dev/null)" = "1/1" ]; then
            ok=0; break
        fi
        sleep 5
    done

    if [ "$ok" -eq 0 ]; then
        state_set TRAEFIK_INSTALLED true
        log_success "Traefik no ar (resolver=${resolver})."
        [ "$dash" = "yes" ] && log_info "Dashboard: https://${dash_domain} (BasicAuth)."
        log_info "Aponte o DNS dos seus domínios para este nó ANTES de esperar certificado do Let's Encrypt."
    else
        log_error "O serviço traefik_traefik não estabilizou. Diagnóstico:"
        docker service ps traefik_traefik --no-trunc 2>/dev/null | head -8 || true
        docker service logs --tail 30 traefik_traefik 2>/dev/null | tail -30 || true
        return 1
    fi
}

# ============================================================================
#  PORTAINER CE
# ============================================================================
#  Notas que mudaram em relação ao arquivo antigo:
#   • Versão pinada na linha LTS. A tag :latest do Portainer aponta para a LTS,
#     não para o maior número (a 2.44 é STS e a própria Portainer diz que STS
#     não é para produção).
#   • A doc exige que o agent esteja na MESMA versão exata do server.
#   • A porta 9001 do agent nunca é publicada — fica só na overlay.
#   • Existe uma janela de 5 minutos para criar o admin; passou disso, o
#     serviço interno para e é preciso reiniciar o service. Por isso o
#     instalador oferece semear a senha via secret e eliminar a corrida.
# ----------------------------------------------------------------------------

install_portainer() {
    step_skipped portainer && return 0
    check_step PORTAINER_INSTALLED "Instalar Portainer" || return 0
    log_step "Portainer CE ${PORTAINER_VERSION}"

    [ "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)" = "true" ] || {
        log_warning "O Portainer precisa de um manager. Pulando."; return 0; }

    ask_yn "Instalar o Portainer CE ${PORTAINER_VERSION} agora?" "y" || { log_info "Portainer pulado."; return 0; }

    ensure_image "portainer/portainer-ce:${PORTAINER_VERSION}" || return 1
    ensure_image "portainer/agent:${PORTAINER_VERSION}"        || return 1

    local net="${NETWORK_NAME:-$OVERLAY_NAME}"
    docker network ls --format '{{.Name}}' 2>/dev/null | grep -qx "$net" || {
        run docker network create --driver overlay --attachable "$net" || return 1; }

    # O agent tem o socket do Docker montado: quem alcança a porta 9001 dele
    # manda no host inteiro. Deixá-lo na overlay pública significa que QUALQUER
    # container de QUALQUER stack ali pode falar com ele. Rede dedicada, não
    # attachable, só entre portainer e agent.
    local agent_net="portainer_agent_net"
    if ! docker network ls --format '{{.Name}}' 2>/dev/null | grep -qx "$agent_net"; then
        run docker network create --driver overlay --opt encrypted "$agent_net" >/dev/null 2>&1 \
            || run docker network create --driver overlay "$agent_net" >/dev/null 2>&1 \
            || { log_error "Falha ao criar a rede '${agent_net}'."; return 1; }
        log_info "Rede interna '${agent_net}' criada para o agent do Portainer."
    fi

    local domain
    domain="$(ask_text "Domínio do Portainer (ex.: portainer.seudominio.com)" "")"
    if ! [[ "$domain" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}$ ]]; then
        log_error "Domínio inválido: '${domain}'"; return 1
    fi

    local resolver="${TRAEFIK_RESOLVER:-letsencrypt}"

    # --- Senha inicial ------------------------------------------------------
    # Semear o admin remove a corrida dos 5 minutos: se o certificado do
    # Let's Encrypt demorar a sair, você não perde a janela.
    local seed_admin="no" admin_pass=""
    if ask_yn "Definir a senha do admin agora (evita a janela de 5 min expirar)?" "y"; then
        admin_pass="$(ask_text "Senha do admin (ENTER gera uma aleatória, mín. 12 caracteres)" "" --secret)"
        if [ -z "$admin_pass" ]; then
            admin_pass="$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^_+=' </dev/urandom 2>/dev/null | head -c 24 || true)"
        fi
        if [ "${#admin_pass}" -lt 12 ]; then
            log_warning "Senha com menos de 12 caracteres — o Portainer vai recusar. Pulando o seed."
        else
            docker secret rm portainer_admin_password >/dev/null 2>&1 || true
            if printf '%s' "$admin_pass" | docker secret create portainer_admin_password - >/dev/null 2>&1; then
                seed_admin="yes"
            else
                log_warning "Não consegui criar o secret da senha — seguindo sem seed."
            fi
        fi
    fi

    run docker volume create portainer_data >/dev/null 2>&1 || true

    # Mesmo caso do Traefik: portainer_data é driver 'local'. Sem prender ao
    # nó, um reagendamento sobe um Portainer vazio (perde usuários/endpoints).
    local pin_label="swarm_installer.portainer_data"
    local self_node
    self_node="$(docker info --format '{{.Swarm.NodeID}}' 2>/dev/null)"
    if [ -n "$self_node" ]; then
        run docker node update --label-add "${pin_label}=true" "$self_node" >/dev/null 2>&1 || true
    fi

    local f="$STATE_DIR/portainer.yaml"
    {
        cat <<EOF
services:
  agent:
    image: portainer/agent:${PORTAINER_VERSION}
    # Sem AGENT_CLUSTER_ADDR: em Swarm o agent deriva 'tasks.<service>' sozinho,
    # e o stack oficial da Portainer também não define essa variável.
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks:
      # SÓ na rede interna — nunca na overlay pública.
      - ${agent_net}
    deploy:
      mode: global
      placement:
        constraints: [ "node.platform.os == linux" ]
      resources:
        limits: { memory: 256M }
      # Sem 'ports:' de propósito — a 9001 fica só dentro da overlay.

  portainer:
    image: portainer/portainer-ce:${PORTAINER_VERSION}
EOF
        if [ "$seed_admin" = "yes" ]; then
            cat <<'EOF'
    command: -H tcp://tasks.agent:9001 --tlsskipverify --admin-password-file /run/secrets/portainer_admin_password
    secrets:
      - portainer_admin_password
EOF
        else
            cat <<'EOF'
    command: -H tcp://tasks.agent:9001 --tlsskipverify
EOF
        fi
        cat <<EOF
    volumes:
      - portainer_data:/data
    networks:
      - ${net}         # exposição via Traefik
      - ${agent_net}   # canal privado até o agent
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - "node.role == manager"
          # Prende ao nó dono do portainer_data (driver local).
          - "node.labels.swarm_installer.portainer_data == true"
      labels:
        - "traefik.enable=true"
        # Provider Swarm do Traefik v3: 'swarm', não 'docker'.
        # Definir os dois nomes na mesma service falha com
        # "both Docker and Swarm labels are defined".
        - "traefik.swarm.network=${net}"
        - "traefik.http.routers.portainer.rule=Host(\`${domain}\`)"
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.tls.certresolver=${resolver}"
        - "traefik.http.routers.portainer.service=portainer"
        # Middleware do MESMO provider é referenciado sem sufixo.
        # 'nome@docker' resolveria em outro namespace e o router seria descartado.
        - "traefik.http.routers.portainer.middlewares=portainer-sec"
        - "traefik.http.middlewares.portainer-sec.headers.stsSeconds=31536000"
        - "traefik.http.middlewares.portainer-sec.headers.stsIncludeSubdomains=true"
        - "traefik.http.middlewares.portainer-sec.headers.stsPreload=true"
        - "traefik.http.middlewares.portainer-sec.headers.forceSTSHeader=true"
        - "traefik.http.middlewares.portainer-sec.headers.contentTypeNosniff=true"
        - "traefik.http.middlewares.portainer-sec.headers.browserXssFilter=true"
        - "traefik.http.middlewares.portainer-sec.headers.frameDeny=true"
        - "traefik.http.middlewares.portainer-sec.headers.referrerPolicy=strict-origin-when-cross-origin"
        # Obrigatório no Swarm: o Swarm não informa porta ao Traefik.
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"
      update_config:
        parallelism: 1
        # stop-first: o Portainer abre o BoltDB com lock exclusivo. Em
        # start-first a task nova encontra o /data travado pela antiga e morre.
        order: stop-first
        failure_action: rollback
      restart_policy:
        condition: any
        delay: 5s
      resources:
        limits:   { cpus: "1.0", memory: 1024M }
        reservations: { cpus: "0.10", memory: 128M }

volumes:
  portainer_data:
    external: true

networks:
  ${net}:
    external: true
  ${agent_net}:
    external: true
EOF
        [ "$seed_admin" = "yes" ] && cat <<'EOF'

secrets:
  portainer_admin_password:
    external: true
EOF
    } > "$f"

    run chmod 600 "$f"
    log_info "Stack file: ${f}"

    run docker stack deploy --detach=false -c "$f" portainer || {
        log_error "Deploy do Portainer falhou. Confira ${f}."; return 1; }

    # O portainer sobe antes do agent e a 1ª task costuma morrer com
    # "dial tcp tasks.agent:9001: connection refused". É corrida conhecida (o
    # stack oficial da Portainer tem a mesma) e o restart_policy resolve —
    # por isso esperamos com folga em vez de acusar falha no primeiro ciclo.
    local i ok=1
    for i in $(seq 1 24); do
        if [ "$(docker service ls --filter name=portainer_portainer --format '{{.Replicas}}' 2>/dev/null)" = "1/1" ]; then
            ok=0; break
        fi
        [ "$i" = "6" ] && log_info "Ainda convergindo (a 1ª task falha enquanto o agent não sobe — é esperado)…"
        sleep 5
    done

    if [ "$ok" -eq 0 ]; then
        state_set PORTAINER_INSTALLED true
        log_success "Portainer no ar em https://${domain}"
        if [ "$seed_admin" = "yes" ]; then
            # A senha vai para a tela e para o arquivo 600 — NUNCA para o setup.log.
            printf '\n%s┌─ CREDENCIAIS INICIAIS DO PORTAINER ─────────────────────────┐%s\n' "$YELLOW" "$NC"
            printf '%s│%s  usuário: admin\n' "$YELLOW" "$NC"
            printf '%s│%s  senha:   %s\n' "$YELLOW" "$NC" "$admin_pass"
            printf '%s└─────────────────────────────────────────────────────────────┘%s\n\n' "$YELLOW" "$NC"
            {
                printf '\n# Portainer (%s)\n' "$(date)"
                printf 'PORTAINER_URL=https://%s\n' "$domain"
                printf 'PORTAINER_USER=admin\n'
                printf 'PORTAINER_PASS=%s\n' "$admin_pass"
            } >> "$TOKEN_FILE"
            run chmod 600 "$TOKEN_FILE"
            log_info "Credenciais também em ${TOKEN_FILE} (chmod 600). Troque a senha depois do primeiro login."
        else
            log_warning "Você optou por NÃO semear a senha. A partir da 2.39.4 o primeiro acesso exige:"
            log_warning "  1) um SETUP TOKEN, que só aparece no log do serviço; e"
            log_warning "  2) concluir o cadastro em até 5 MINUTOS após o start."
            printf '\n  Pegue o token com:\n    docker service logs portainer_portainer 2>&1 | grep -o "setup_token=[a-f0-9]*"\n' 
            printf '  Reiniciar (nova janela de 5 min):\n    docker service update --force portainer_portainer\n\n'
            log_info "Para desativar a exigência do token, adicione --no-setup-token ao command do serviço."
        fi
        unset admin_pass
    else
        log_error "O serviço portainer_portainer não estabilizou. Diagnóstico:"
        docker service ps portainer_portainer --no-trunc 2>/dev/null | head -8 || true
        return 1
    fi
}

# ============================================================================
#  DIAGNÓSTICO
# ============================================================================
doctor() {
    log_step "Diagnóstico"

    printf '%sSistema%s\n' "$BOLD" "$NC"
    printf '  SO ............ %s\n' "${OS_PRETTY:-?}"
    printf '  Família ....... %s (pacotes: %s, init: %s)\n' "${OS_FAMILY:-?}" "${PKG_MGR:-?}" "${INIT_SYS:-?}"
    printf '  Arquitetura ... %s\n' "${CPU_ARCH:-?}"
    printf '  Kernel ........ %s\n' "$(uname -r)"
    printf '  Hostname ...... %s\n' "$(hostname -s 2>/dev/null || echo '?')"
    printf '  Uptime ........ %s\n' "$(uptime -p 2>/dev/null || echo '?')"
    printf '\n'

    printf '%sDocker%s\n' "$BOLD" "$NC"
    if have docker && docker version >/dev/null 2>&1; then
        printf '  Engine ........ %s\n' "$(docker version --format '{{.Server.Version}}' 2>/dev/null)"
        printf '  Compose ....... %s\n' "$(docker compose version --short 2>/dev/null || echo 'n/d')"
        printf '  Buildx ........ %s\n' "$(docker buildx version 2>/dev/null | awk '{print $2}' || echo 'n/d')"
        printf '  Log driver .... %s\n' "$(docker info --format '{{.LoggingDriver}}' 2>/dev/null)"
        printf '  Storage ....... %s\n' "$(docker info --format '{{.Driver}}' 2>/dev/null)"
        printf '  live-restore .. %s' "$(docker info --format '{{.LiveRestoreEnabled}}' 2>/dev/null)"
        [ "$(docker info --format '{{.LiveRestoreEnabled}}' 2>/dev/null)" = "true" ] \
            && printf ' %s← INCOMPATÍVEL COM SWARM%s' "$RED" "$NC"
        printf '\n\n'
    else
        printf '  %sDocker não instalado ou não responde.%s\n\n' "$RED" "$NC"
        return 0
    fi

    printf '%sSwarm%s\n' "$BOLD" "$NC"
    local st; st="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)"
    printf '  Estado ........ %s\n' "$st"
    if [ "$st" = "active" ]; then
        printf '  Manager ....... %s\n' "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)"
        printf '  Nós ........... %s (managers: %s)\n' \
            "$(docker info --format '{{.Swarm.Nodes}}' 2>/dev/null)" \
            "$(docker info --format '{{.Swarm.Managers}}' 2>/dev/null)"
        if docker node ls >/dev/null 2>&1; then
            printf '\n'; docker node ls 2>/dev/null
            printf '\n%sServiços%s\n' "$BOLD" "$NC"; docker service ls 2>/dev/null
            printf '\n%sRedes overlay%s\n' "$BOLD" "$NC"; docker network ls --filter driver=overlay 2>/dev/null

            # Réplicas que não convergiram são o sintoma nº1 de rede/label errada
            local bad
            bad="$(docker service ls --format '{{.Name}} {{.Replicas}}' 2>/dev/null \
                   | awk '{split($2,a,"/"); if (a[1]+0 != a[2]+0) print "  ⚠ " $0}')"
            [ -n "$bad" ] && { printf '\n%sServiços fora do alvo:%s\n%s\n' "$YELLOW" "$NC" "$bad"; }
        fi
    fi
    printf '\n'

    printf '%sRede / firewall%s\n' "$BOLD" "$NC"
    printf '  IP principal .. %s\n' "$(detect_primary_ip)"
    printf '  Backend fw .... %s\n' "$(fw_backend_detect)"
    if have nft && nft list table inet swarm_guard >/dev/null 2>&1; then
        printf '  swarm_guard ... presente\n'
    fi
    printf '\n'

    printf '%ssysctl relevante%s\n' "$BOLD" "$NC"
    local k
    for k in net.ipv4.ip_forward fs.file-max net.core.somaxconn vm.swappiness vm.max_map_count; do
        printf '  %-28s %s\n' "$k" "$(sysctl -n "$k" 2>/dev/null || echo 'n/d')"
    done
    printf '\n'

    printf '%sArquivos%s\n' "$BOLD" "$NC"
    printf '  Estado ........ %s\n' "$STATE_FILE"
    printf '  Log ........... %s\n' "$LOG_FILE"
    [ -f "$TOKEN_FILE" ] && printf '  Tokens ........ %s (600)\n' "$TOKEN_FILE"
    printf '\n'
}

print_status() {
    printf '\n%sEstado da instalação — %s%s\n\n' "$BOLD" "$STATE_FILE" "$NC"
    if [ ! -f "$STATE_FILE" ]; then
        printf '  Nenhuma execução anterior registrada.\n\n'; return 0
    fi
    local k v mark
    for k in "${STATE_KEYS[@]}"; do
        v="${!k:-}"
        case "$v" in
            true)  mark="${GREEN}✔${NC}" ;;
            false) mark="${YELLOW}·${NC}" ;;
            '')    mark=" " ; v="—" ;;
            *)     mark="${CYAN}◆${NC}" ;;
        esac
        printf '  %b %-32s %s\n' "$mark" "$k" "$v"
    done
    printf '\n'
}

reset_state() {
    printf '%sIsto apaga %s (o Docker, o Swarm e as stacks NÃO são tocados).%s\n' "$YELLOW" "$STATE_FILE" "$NC"
    ask_yn "Confirma?" "n" || { printf 'Cancelado.\n'; return 0; }
    rm -f "$STATE_FILE"
    printf 'Estado apagado. A próxima execução começa do zero.\n'
}

# ============================================================================
#  ARGUMENTOS
# ============================================================================
usage() {
    cat <<EOF
${BOLD}Setup Automatizado — Instalador de Cluster Docker Swarm v${SCRIPT_VERSION}${NC}

  sudo bash ${SCRIPT_NAME} [opções]

${BOLD}Opções${NC}
  -h, --help              Esta ajuda
  -V, --version           Versão do instalador
      --status            Mostra o estado das etapas e sai
      --doctor            Diagnóstico do host e do cluster e sai
      --reset             Apaga o arquivo de estado (não desinstala nada)
  -y, --yes               Responde "sim" a tudo
  -n, --non-interactive   Nunca pergunta; usa os padrões
      --dry-run           Só imprime o que faria
      --no-color          Sem cores
      --profile ARQUIVO   Carrega o perfil do cluster deste arquivo
      --skip LISTA        Pula etapas (vírgula). Nomes válidos:
                          hostname, hosts, machineid, kernelnotif, update,
                          prereqs, timesync, swap, sysctl, docker, daemon,
                          permissions, firewall, ssh, swarm, labels, network,
                          traefik, portainer

${BOLD}Exemplos${NC}
  sudo bash ${SCRIPT_NAME}
  sudo bash ${SCRIPT_NAME} --skip ssh,traefik,portainer
  sudo bash ${SCRIPT_NAME} --non-interactive --yes --skip ssh
  sudo bash ${SCRIPT_NAME} --doctor
  curl -fsSL <url> | sudo bash

${BOLD}Perfil${NC}
  As variáveis do bloco "PERFIL DO CLUSTER" podem vir de
  /etc/swarm-installer.conf (ou --profile ARQUIVO), que tem precedência
  sobre o que está escrito no script.
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)             usage; exit 0 ;;
            -V|--version)          printf '%s\n' "$SCRIPT_VERSION"; exit 0 ;;
            --status)              OPT_STATUS_ONLY=1 ;;
            --doctor)              OPT_DOCTOR_ONLY=1 ;;
            --reset)               OPT_RESET=1 ;;
            -y|--yes)              OPT_ASSUME_YES=1 ;;
            -n|--non-interactive)  OPT_NONINTERACTIVE=1 ;;
            --dry-run)             OPT_DRY_RUN=1 ;;
            --no-color)            OPT_NO_COLOR=1; setup_colors ;;
            --profile)             shift; OPT_PROFILE_FILE="${1:-}" ;;
            --profile=*)           OPT_PROFILE_FILE="${1#*=}" ;;
            --skip)                shift; OPT_SKIP="${1:-}" ;;
            --skip=*)              OPT_SKIP="${1#*=}" ;;
            *) printf 'Opção desconhecida: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
        esac
        shift
    done
}

load_profile_file() {
    local f="${OPT_PROFILE_FILE:-/etc/swarm-installer.conf}"
    [ -r "$f" ] || return 0
    # É um arquivo de configuração do root, com sintaxe bash. Só é lido se
    # pertencer ao root e não for gravável por outros.
    local owner perms
    owner="$(stat -c '%u' "$f" 2>/dev/null || stat -f '%u' "$f" 2>/dev/null || echo 0)"
    perms="$(stat -c '%a' "$f" 2>/dev/null || stat -f '%Lp' "$f" 2>/dev/null || echo 600)"
    if [ "$owner" != "0" ]; then
        log_warning "Ignorando ${f}: não pertence ao root."; return 0
    fi
    if [ -L "$f" ]; then
        log_warning "Ignorando ${f}: é um symlink."; return 0
    fi
    # O padrão antigo (*[2367]) ancorava no ÚLTIMO caractere, então só via o
    # bit de "outros" — um arquivo 664 (gravável pelo grupo) passava batido.
    # Aqui checamos grupo E outros de forma explícita.
    perms="$(printf '%04d' "$((10#${perms:-600}))")"
    local g="${perms:2:1}" ot="${perms:3:1}"
    case "$g$ot" in
        *[2367]*) log_warning "Ignorando ${f}: gravável por grupo ou outros (use chmod 600)."; return 0 ;;
    esac
    # shellcheck source=/dev/null
    . "$f"
    log_info "Perfil carregado de ${f}"
}

# ============================================================================
#  BANNER
# ============================================================================
show_logo() {
    [ "$OPT_NONINTERACTIVE" = "1" ] && return 0
    clear 2>/dev/null || true
    printf '\n'
    printf '%s███████╗██╗   ██╗██╗     ██╗         ███████╗████████╗ █████╗  ██████╗██╗  ██╗%s\n' "$PURPLE" "$NC"
    printf '%s██╔════╝██║   ██║██║     ██║         ██╔════╝╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝%s\n' "$PURPLE" "$NC"
    printf '%s█████╗  ██║   ██║██║     ██║         ███████╗   ██║   ███████║██║     █████╔╝ %s\n' "$PURPLE" "$NC"
    printf '%s██╔══╝  ██║   ██║██║     ██║         ╚════██║   ██║   ██╔══██║██║     ██╔═██╗ %s\n' "$PURPLE" "$NC"
    printf '%s██║     ╚██████╔╝███████╗███████╗    ███████║   ██║   ██║  ██║╚██████╗██║  ██╗%s\n' "$PURPLE" "$NC"
    printf '%s╚═╝      ╚═════╝ ╚══════╝╚══════╝    ╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝%s\n' "$PURPLE" "$NC"
    printf '\n'
    printf '%s════════════════════════════════════════════════════════════════════════════%s\n' "$MAGENTA" "$NC"
    printf '                        💻 Setup Automatizado LTDA 🤖\n'
    printf '%s════════════════════════════════════════════════════════════════════════════%s\n' "$MAGENTA" "$NC"
    printf '\n'
    printf '%s🚀 Docker Swarm — Instalador de Cluster v%s%s\n' "$YELLOW" "$SCRIPT_VERSION" "$NC"
    printf '   Traefik %s · Portainer CE %s · perfil: %s\n' "$TRAEFIK_VERSION" "$PORTAINER_VERSION" "$CLUSTER_PROFILE_NAME"
    printf '   Guilherme Jansen\n\n'
}

# ============================================================================
#  MAIN
# ============================================================================
on_err()  { log_error "Falha inesperada na linha ${1:-?} (comando: ${2:-?})."; }
on_int()  { printf '\n'; log_warning "Interrompido. O progresso está em ${STATE_FILE} — rode de novo para continuar."; exit 130; }

main() {
    parse_args "$@"
    setup_colors
    open_tty

    trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR
    trap on_int INT TERM

    load_profile_file

    if [ "$(id -u)" -ne 0 ]; then
        printf '%sEste instalador precisa de root: sudo bash %s%s\n' "$RED" "$SCRIPT_NAME" "$NC" >&2
        exit 1
    fi

    initialize_environment
    state_set INSTALLER_VERSION "$SCRIPT_VERSION"

    if [ "$OPT_RESET" = "1" ];       then reset_state; exit 0; fi
    if [ "$OPT_STATUS_ONLY" = "1" ]; then print_status; exit 0; fi
    # (doctor logo abaixo — ambos são somente-leitura e saem sem tocar no host)
    if [ "$OPT_DOCTOR_ONLY" = "1" ]; then
        OS_ID="$(osr ID || true)"; OS_PRETTY="$(osr PRETTY_NAME || true)"
        OS_ID_LIKE="$(osr ID_LIKE || true)"; OS_VERSION_ID="$(osr VERSION_ID || true)"
        CPU_ARCH="$(uname -m)"; detect_family; detect_pkg_mgr; detect_init_system
        doctor; exit 0
    fi

    show_logo

    # ---- Fase 0: contexto ----
    preflight
    detect_os
    reconcile_state

    local default_user="${SUDO_USER:-root}"
    SYSTEM_USER="$(ask_text "Usuário que entrará no grupo docker" "$default_user")"
    state_set SYSTEM_USER "$SYSTEM_USER"

    # ---- Fase 1: sistema ----
    configure_hostname
    configure_hosts_file
    regenerate_machine_id
    ask_yn "Desabilitar upgrades automáticos de pacotes/kernel?" "y" && disable_kernel_notifications
    ask_yn "Atualizar os pacotes do sistema agora?"              "y" && update_upgrade
    install_prerequisites
    configure_timesync
    ask_yn "Desabilitar swap (recomendado para Swarm)?"          "y" && disable_swap_persistent
    ask_yn "Aplicar tuning de sysctl?"                           "y" && apply_sysctl_tuning

    # ---- Fase 2: Docker ----
    install_docker           || die "Instalação do Docker falhou — nada além disso faz sentido."
    configure_docker_daemon  || log_warning "daemon.json não aplicado — seguindo."
    setup_docker_permissions || log_warning "Permissões não aplicadas — seguindo."

    # ---- Fase 3: Swarm ----
    # O Swarm vem ANTES do firewall de propósito: collect_cluster_peers
    # descobre os peers com `docker node ls`, o que só funciona depois do
    # init/join. Na ordem inversa, um cluster sem CLUSTER_PEERS preenchido
    # cairia sempre no caminho "sem peers" e abriria as portas para todos.
    ask_yn "Configurar o Docker Swarm agora?" "y" && setup_docker_swarm

    # ---- Fase 4: segurança ----
    ask_yn "Configurar o firewall do host?" "y" && configure_firewall
    configure_ssh_hardening

    if [ "$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)" = "active" ]; then
        if [ "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)" = "true" ]; then
            setup_swarm_labels
            create_overlay_network
            install_traefik   || log_warning "Traefik não instalado."
            install_portainer || log_warning "Portainer não instalado."
        else
            log_info "Este nó é worker — labels, overlay, Traefik e Portainer são feitos no manager."
        fi
    fi

    # ---- Fase 5: fechamento ----
    doctor
    print_status

    log_success "Instalação concluída."
    printf '\n%sPróximos passos%s\n' "$BOLD" "$NC"
    [ "${SYSTEM_USER}" != "root" ] && printf '  • Faça logout/login com %s para o grupo docker valer.\n' "$SYSTEM_USER"
    [ -f "$TOKEN_FILE" ] && printf '  • Comandos de join e credenciais: %s\n' "$TOKEN_FILE"
    printf '  • Rode este script nos demais nós e escolha manager-follower/worker.\n'
    printf '  • Depois que todos entrarem, rode de novo no manager para completar as labels.\n'
    printf '  • Diagnóstico a qualquer momento: sudo bash %s --doctor\n' "$SCRIPT_NAME"
    printf '  • Log completo: %s\n\n' "$LOG_FILE"
}

main "$@"
