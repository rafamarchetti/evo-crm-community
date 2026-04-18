#!/usr/bin/env bash
# =============================================================
# EvoCRM — Install script (primeira instalação)
# Uso: ./install.sh
# Requisitos: Docker, Docker Compose, Dokploy ou Traefik preexistente
# =============================================================
set -euo pipefail

cd "$(dirname "$0")"
REPO_DIR="$(pwd)"

echo "================================================================"
echo "   EvoCRM — Instalação automática"
echo "================================================================"
echo ""

# --- 1. Checagem de pré-requisitos ---
echo ">>> Verificando pré-requisitos..."
for cmd in docker git openssl python3; do
    command -v $cmd >/dev/null 2>&1 || { echo "ERRO: $cmd não instalado"; exit 1; }
done
docker compose version >/dev/null 2>&1 || { echo "ERRO: docker compose v2 não disponível"; exit 1; }
echo "OK"
echo ""

# --- 2. Arquitetura ---
ARCH=$(uname -m)
echo ">>> Arquitetura detectada: $ARCH"
if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
    echo ">>> ARM64 detectado — habilitando substituição do Mailhog por Mailpit"
    IS_ARM=true
else
    IS_ARM=false
fi
echo ""

# --- 3. Coleta de informações ---
if [[ ! -f .env ]]; then
    echo ">>> Configuração inicial"
    echo ""
    read -rp "Domínio raiz (ex: daios.com.br): " ROOT_DOMAIN
    read -rp "Nome da organização (ex: DAIOS): " ORG_NAME
    read -rp "Email para notificações (sender, ex: noreply@daios.com.br): " NOREPLY

    if [[ -z "$ROOT_DOMAIN" || -z "$ORG_NAME" ]]; then
        echo "ERRO: domínio e organização são obrigatórios"
        exit 1
    fi

    # --- 4. Gera .env a partir do template ---
    echo ""
    echo ">>> Gerando .env a partir do template..."
    cp .env.production.example .env

    # Substitui placeholders de domínio
    sed -i "s/SEUDOMINIO\.com\.br/$ROOT_DOMAIN/g" .env
    sed -i "s/^ORGANIZATION_NAME=.*/ORGANIZATION_NAME=$ORG_NAME/" .env
    sed -i "s|^MAILER_SENDER_EMAIL=.*|MAILER_SENDER_EMAIL=$NOREPLY|" .env

    # Gera secrets
    POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/')
    REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/')
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    JWT_SECRET_KEY=$(openssl rand -hex 64)
    ENCRYPTION_KEY=$(openssl rand -base64 32)
    BOT_RUNTIME_SECRET=$(openssl rand -hex 32)
    AI_PROCESSOR_API_KEY=$(openssl rand -hex 32)
    EVOAI_CRM_API_TOKEN=$(cat /proc/sys/kernel/random/uuid)

    # Substitui no .env
    sed -i "s|CHANGE_ME_POSTGRES|$POSTGRES_PASSWORD|g" .env
    sed -i "s|CHANGE_ME_REDIS|$REDIS_PASSWORD|g" .env
    sed -i "s|CHANGE_ME_SECRET_KEY_BASE|$SECRET_KEY_BASE|g" .env
    sed -i "s|CHANGE_ME_JWT|$JWT_SECRET_KEY|g" .env
    sed -i "s|CHANGE_ME_ENCRYPTION|$ENCRYPTION_KEY|g" .env
    sed -i "s|CHANGE_ME_BOT_SECRET|$BOT_RUNTIME_SECRET|g" .env
    sed -i "s|CHANGE_ME_PROCESSOR_API_KEY|$AI_PROCESSOR_API_KEY|g" .env
    sed -i "s|CHANGE_ME_CRM_TOKEN|$EVOAI_CRM_API_TOKEN|g" .env

    chmod 600 .env

    # Valida
    if grep -q CHANGE_ME .env; then
        echo "ERRO: ainda tem CHANGE_ME no .env"
        exit 1
    fi

    echo "OK — .env gerado"
    echo ""
    echo ">>> IMPORTANTE: faça backup do .env no Bitwarden/1Password"
    echo "    Perder o ENCRYPTION_KEY depois de ter dados = dados perdidos"
    echo ""
    read -rp "Pressione ENTER depois de fazer backup pra continuar..."
else
    echo ">>> .env já existe, mantendo configuração atual"
    ROOT_DOMAIN=$(grep ^FRONTEND_URL .env | sed 's|.*https://crm\.||' | sed 's|/.*||')
fi

# --- 5. Instala config dinâmica do Traefik ---
TRAEFIK_DYNAMIC_DIR="/etc/dokploy/traefik/dynamic"
if [[ -d "$TRAEFIK_DYNAMIC_DIR" ]]; then
    echo ">>> Instalando config dinâmica do Traefik..."
    # Gera o arquivo com o domínio correto
    sudo tee "$TRAEFIK_DYNAMIC_DIR/evocrm-frontend.yml" > /dev/null << EOF
http:
  routers:
    evocrm-front-file:
      rule: "Host(\`crm.$ROOT_DOMAIN\`)"
      entryPoints:
        - websecure
      service: evocrm-front-service
      tls:
        certResolver: letsencrypt
  services:
    evocrm-front-service:
      loadBalancer:
        servers:
          - url: "http://evo-crm-community-evo-frontend-1:80"
        passHostHeader: true
EOF
    echo "OK"
else
    echo "!!! Diretório $TRAEFIK_DYNAMIC_DIR não encontrado"
    echo "!!! Se você não usa Dokploy/Traefik, ignore. Caso contrário, verifique"
    echo "!!! e copie manualmente traefik-dynamic/evocrm-frontend.yml"
fi
echo ""

# --- 6. Verifica Dokploy network ---
if ! docker network inspect dokploy-network >/dev/null 2>&1; then
    echo "!!! Rede 'dokploy-network' não encontrada"
    echo "!!! Se Dokploy não está instalado, o docker-compose.override.yml não vai funcionar"
    echo "!!! Instale Dokploy antes: curl -sSL https://dokploy.com/install.sh | sh"
    echo ""
    read -rp "Continuar mesmo assim? [s/N] " CONT
    [[ "$CONT" != "s" ]] && exit 1
fi

# --- 7. Aviso ARM sobre build demorado ---
if $IS_ARM; then
    echo "================================================================"
    echo "  AVISO: builds em ARM64 levam 25-40 min na primeira execução"
    echo "  Ruby/Rails gems compilam do zero. NÃO cancele."
    echo "================================================================"
    echo ""
fi

# --- 8. Swap (recomendado pra ARM) ---
SWAP_MB=$(free -m | awk '/^Swap:/ {print $2}')
if [[ $SWAP_MB -lt 4000 ]] && $IS_ARM; then
    echo ">>> Swap atual: ${SWAP_MB}MB — recomendado 8GB em ARM"
    read -rp "Criar 8GB de swap agora? [S/n] " SWAP_CONFIRM
    if [[ "$SWAP_CONFIRM" != "n" ]]; then
        sudo fallocate -l 8G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        grep -q "/swapfile" /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        echo "OK — swap adicionada"
    fi
fi
echo ""

# --- 9. Build e subida ---
echo ">>> Build + up (primeira execução leva 25-40 min em ARM)"
docker compose up -d --build

echo ""
echo ">>> Aguardando containers ficarem healthy..."
sleep 60
docker compose ps

echo ""
echo "================================================================"
echo "   Próximo passo: rode ./post-install.sh"
echo "   Ele vai rodar migrations pendentes e validar a stack"
echo "================================================================"
