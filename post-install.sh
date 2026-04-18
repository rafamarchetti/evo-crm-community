#!/usr/bin/env bash
# =============================================================
# EvoCRM — Post-install (migrations + ajustes pós-boot)
# Uso: ./post-install.sh
# =============================================================
set -euo pipefail

cd "$(dirname "$0")"

echo ">>> Rodando migrations pendentes no evo-crm..."
docker compose exec -T evo-crm bundle exec rails db:migrate 2>&1 | tail -10

echo ""
echo ">>> Rodando migrations do evo-auth..."
docker compose exec -T evo-auth bundle exec rails db:migrate 2>&1 | tail -10

echo ""
echo ">>> Verificando status da stack..."
docker compose ps

echo ""
echo ">>> Verificando se há certificado SSL emitido pros 5 domínios..."
ROOT_DOMAIN=$(grep ^FRONTEND_URL .env | sed 's|.*https://crm\.||' | sed 's|/.*||')
for sub in crm api-crm auth-crm core-crm processor-crm; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$sub.$ROOT_DOMAIN" || echo "000")
    echo "  $sub.$ROOT_DOMAIN -> HTTP $CODE"
done

echo ""
echo "================================================================"
echo "   Setup completo!"
echo ""
echo "   Acesse: https://crm.$ROOT_DOMAIN/setup"
echo "   A tela de setup vai pedir pra criar o usuário admin"
echo ""
echo "   Se algum domínio acima retornou 000 ou 404:"
echo "   - Confirme DNS dos 5 subdomínios apontando pra essa VPS"
echo "   - Confirme portas 80 e 443 abertas na Security List da Oracle"
echo "   - Aguarde 1-3 min pra Let's Encrypt emitir certificado"
echo "================================================================"
