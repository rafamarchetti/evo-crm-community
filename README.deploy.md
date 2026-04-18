# Deploy do EvoCRM — Minhas notas

## Ambiente

- VPS: Oracle Cloud Free Tier (ARM64, 4 vCPU, 24 GB RAM)
- OS: Ubuntu 22.04
- Docker: gerenciado pelo Dokploy
- Proxy: Traefik do Dokploy (rede `dokploy-network`)

## Domínios

- Frontend: <https://crm.daios.com.br>
- CRM API: <https://api-crm.daios.com.br>
- Auth: <https://auth-crm.daios.com.br>
- Core: <https://core-crm.daios.com.br>
- Processor: <https://processor-crm.daios.com.br>

## Comandos úteis

### Subir

docker compose up -d

### Logs

docker compose logs -f evo-crm

### Update

./update.sh

### Backup manual

docker compose exec -T postgres pg_dump -U postgres evo_community | gzip > backup.sql.gz

### Restaurar backup

gunzip -c backup.sql.gz | docker compose exec -T postgres psql -U postgres evo_community

## Secrets

Guardados no 1password em "EvoCRM - Produção"
