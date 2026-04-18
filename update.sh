#!/usr/bin/env bash
# =============================================================
# EvoCRM — Update em produção
# Uso: ./update.sh
# =============================================================
set -euo pipefail

cd "$(dirname "$0")"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo ">>> Backup do banco antes de atualizar..."
mkdir -p backups
docker compose exec -T postgres pg_dump -U postgres evo_community \
    | gzip > "backups/pre-update-${TIMESTAMP}.sql.gz"
echo "Backup salvo em backups/pre-update-${TIMESTAMP}.sql.gz"
echo ""

echo ">>> Pull do fork..."
git pull --ff-only
echo ""

echo ">>> Atualizando submódulos..."
git submodule update --init --recursive --remote --merge
echo ""

echo ">>> Rebuild (pode levar alguns min em ARM)..."
docker compose build --pull
echo ""

echo ">>> Force recreate pra pegar eventuais mudanças no .env..."
docker compose up -d --force-recreate
echo ""

echo ">>> Aguardando containers ficarem healthy (60s)..."
sleep 60

echo ">>> Rodando migrations (se houver novas)..."
docker compose exec -T evo-crm bundle exec rails db:migrate 2>&1 | tail -5 || true
docker compose exec -T evo-auth bundle exec rails db:migrate 2>&1 | tail -5 || true

echo ""
echo ">>> Status final:"
docker compose ps

echo ""
echo "Update concluído."
echo "Se algo quebrar, rollback:"
echo "  git log --oneline -5"
echo "  git reset --hard <HASH_ANTERIOR>"
echo "  git submodule update --init --recursive"
echo "  docker compose up -d --build"
echo "  gunzip -c backups/pre-update-${TIMESTAMP}.sql.gz | docker compose exec -T postgres psql -U postgres evo_community"
