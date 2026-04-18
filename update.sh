#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# Update EvoCRM em produção
# Uso: ./update.sh
# =============================================================

cd "$(dirname "$0")"

echo ">>> Fazendo backup do banco antes de atualizar..."
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p backups
docker compose exec -T postgres pg_dump -U postgres evo_community \
  | gzip > "backups/evo_community-${TIMESTAMP}.sql.gz"
echo ">>> Backup salvo em backups/evo_community-${TIMESTAMP}.sql.gz"

echo ">>> Atualizando código do fork..."
git pull --ff-only

echo ">>> Atualizando submódulos (código dos serviços)..."
git submodule update --init --recursive --remote --merge

echo ">>> Rebuildando containers (isso pode levar alguns minutos)..."
docker compose build --pull

echo ">>> Subindo nova versão..."
docker compose up -d

echo ">>> Esperando serviços ficarem healthy..."
sleep 30
docker compose ps

echo ""
echo ">>> Update concluído!"
echo ">>> Últimas migrations (se houver) rodam automaticamente no entrypoint do Rails."
echo ">>> Para acompanhar os logs: docker compose logs -f"