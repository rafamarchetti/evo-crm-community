# EvoCRM — Runbook de Deploy

Documentação operacional do deploy deste fork.

## Ambiente atual

- **VPS**: Oracle Cloud Free Tier
- **Arquitetura**: ARM64 (Ampere A1)
- **Recursos**: 4 vCPU, 24 GB RAM, 8 GB swap
- **OS**: Ubuntu 22.04
- **Orquestração**: Docker Compose standalone (não Swarm)
- **Proxy reverso**: Traefik do Dokploy (rede `dokploy-network`)

## Domínios (produção)

| Subdomínio | Serviço interno | Porta |
|---|---|---|
| crm.daios.com.br | evo-frontend (Nginx) | 80 |
| api-crm.daios.com.br | evo-crm (Rails) | 3000 |
| auth-crm.daios.com.br | evo-auth (Rails) | 3001 |
| core-crm.daios.com.br | evo-core (Go) | 5555 |
| processor-crm.daios.com.br | evo-processor (FastAPI) | 8000 |

## Primeira instalação em nova VPS

Requisitos: Docker + Docker Compose + Dokploy instalado, DNS dos 5 subdomínios
apontando pro IP da VPS, portas 80/443 liberadas.

```bash
cd /opt
git clone --recurse-submodules https://github.com/rafamarchetti/evo-crm-community
cd evo-crm-community
./install.sh           # configura .env, swap, build
./post-install.sh      # migrations, verificação SSL
```

Acesse `https://crm.seudominio.com.br/setup` e crie o usuário admin.

## Atualização

```bash
cd /opt/evo-crm-community
./update.sh
```

Faz backup automático do banco antes, pull do fork, rebuild, restart, migrations.

## Rollback

```bash
cd /opt/evo-crm-community
git log --oneline -10                            # ver commits recentes
git reset --hard <HASH>                          # voltar commit
git submodule update --init --recursive
docker compose up -d --build

# Se precisar restaurar banco:
gunzip -c backups/pre-update-TIMESTAMP.sql.gz \
  | docker compose exec -T postgres psql -U postgres evo_community
```

## Gotchas importantes (coisas que me pegaram de surpresa)

### 1. `RAILS_ENV=production` quebra o build atual
O projeto tem bug de middleware (`ActionDispatch::Static`) quando se tenta rodar
em production. O `.env.production.example` já mantém `RAILS_ENV=development`.
**Não mude até a Evolution Foundation resolver upstream.**

### 2. Mailhog não tem imagem ARM nativa
No override trocamos por `axllent/mailpit:latest` (funcional, UI similar).

### 3. Healthcheck do evo-core tem path errado no upstream
`/api/v1/health` retorna 404. O endpoint correto é `/health`. Override corrige.

### 4. `CORS_ORIGINS` também é usado pro Rails Host Authorization
Se adicionar novo subdomínio, precisa adicionar nessa variável, não é só CORS.

### 5. `docker compose restart` NÃO relê `.env`
Pra pegar mudanças no `.env`, use `docker compose up -d --force-recreate <servico>`.

### 6. Traefik com providers Swarm + Docker simultâneos
O container `evo-frontend` às vezes não é descoberto por labels (bug de race
condition). Workaround: config dinâmica em `traefik-dynamic/evocrm-frontend.yml`,
copiada durante `install.sh` pra `/etc/dokploy/traefik/dynamic/`.

### 7. Seeds do Rails falham (bug do 7.1.5.1)
`NoMethodError: undefined method 'visit_ActiveModel_Attribute_FromUser'`.
Não usa `db:seed` — cria usuário admin pela UI em `/setup`.

### 8. Migrations não rodam sozinhas no boot em alguns casos
Se `evo-crm` fica unhealthy com `PendingMigrationError`, rode:
`docker compose exec evo-crm bundle exec rails db:migrate`

### 9. Primeira emissão SSL do `crm.daios.com.br` pode travar
Se o Traefik não vir o router do frontend, use `traefik-dynamic/evocrm-frontend.yml`
(já resolvido no install.sh).

## Comandos úteis do dia a dia

```bash
# Status
docker compose ps

# Logs de um serviço
docker compose logs -f evo-crm

# Restart de um serviço
docker compose restart evo-frontend

# Backup manual do banco
docker compose exec -T postgres pg_dump -U postgres evo_community \
  | gzip > backups/manual-$(date +%F-%H%M).sql.gz

# Rails console (auth)
docker compose exec evo-auth bundle exec rails console

# Rails console (crm)
docker compose exec evo-crm bundle exec rails console

# Parar tudo
docker compose down

# Parar + apagar volumes (CUIDADO: apaga banco)
docker compose down -v
```

## Backup automático diário

Cron configurado em `/etc/cron.d/` (via `crontab -e`):
30 3 * * * /opt/evo-crm-community/backup.sh >> /opt/evo-crm-community/backups/backup.log 2>&1

Retenção: 14 dias. Pra upload externo (S3, Backblaze), ver `backup.sh`.

## Onde estão os secrets

`.env` na VPS. **Cópia no Bitwarden** em "EvoCRM - Produção - .env".
NUNCA versionar `.env` no git.

## Quando considerar migrar pra VPS separada

Sinais pra migrar o EvoCRM pra VPS dedicada (sem Dokploy):
- Mais de 10 atendentes simultâneos
- SLA de uptime pra cliente externo
- Build demorando demais junto com outros projetos
- Restart do Dokploy afetando disponibilidade do CRM

Em VPS sem Dokploy, o deploy vira o `make setup` oficial da Evolution Foundation
(sem Traefik dinâmico necessário). Este fork + kit continua funcionando:
`install.sh` detecta ausência de `dokploy-network` e avisa.
