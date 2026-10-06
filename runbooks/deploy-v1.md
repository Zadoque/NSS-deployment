# Runbook - deployment NSS 1.0

Este runbook executa os gates G0-G9 definidos na documentação normativa.

## G0 - contratos

Confirme `contracts/api-v1.md`, `contracts/auth-v1.md` e `contracts/serving-v1.md`. Nenhuma LLM deve alterar silenciosamente os contratos para fazer o código passar.

## Preparar imagens

Nos clones dos respectivos repositórios, construa e identifique imagens com SHA/tag explícita:

```bash
docker build -t nss-java:<sha> ./java-repo
docker build -t nss-frontend:<sha> ./frontend-repo
docker build -t nss-pipeline:<sha> ./pipeline-repo
```

Atualize `.env` com as tags. Frontend deve produzir imagem HTTP que sirva build estático na porta 80. Java expõe internamente 8080. Pipeline não é serviço web.

## Preparar segredos

```bash
cp .env.example .env
chmod 600 .env
```

Substitua todos os `CHANGE_ME`. Gere uma chave JWT Base64 forte com
`openssl rand -base64 64` e não versione `.env`.

## Backup antes de migração

Se o banco já contiver estado relevante:

```bash
docker compose up -d db
docker compose up db-provision
docker compose exec -T db pg_dump -U "$NSS_BACKUP_USER" -d "$POSTGRES_DB" -Fc > nss-before-v1.dump
```

## G1/G2 - pipeline e PostgreSQL

```bash
docker compose up -d db
docker compose up db-provision
docker compose --profile jobs run --rm pipeline-migrate
docker compose --profile jobs run --rm --entrypoint python pipeline -m app.pipeline.run_load --disease DENG --year 2026
```

Aplique Alembic conforme a imagem atual antes da carga quando necessário. Não execute Toxoplasmose até o código/base estar validado.

Exija: Serving 1.0, publicação transacional, soma Gold=PostgreSQL e não-mapeados contabilizados.

## G3/G4 - Java e autenticação

```bash
docker compose up -d java
curl --fail http://127.0.0.1:${NSS_HTTP_PORT:-8080}/actuator/health
```

Verifique Flyway, login, endpoint protegido, refresh rotacionado e logout. Confirme auto-registro bloqueado e ausência de CRUD irrestrito de usuários.

## G5 - Frontend

```bash
docker compose up -d frontend caddy
curl -I http://127.0.0.1:${NSS_HTTP_PORT:-8080}/
```

O frontend deve usar `/api/v1` na mesma origem, não `localhost:8080` hardcoded no navegador.

## Grafana mínimo

```bash
docker compose --profile monitoring up -d prometheus pushgateway node-exporter grafana
curl --fail http://127.0.0.1:9090/-/ready
curl --fail http://127.0.0.1:3000/api/health
```

Grafana fica em `127.0.0.1:3000` e recebe o datasource Prometheus automaticamente.
Prometheus e Grafana não devem ser expostos no Caddy/ngrok. Prioridade: Bronze,
Silver, Gold, PostgreSQL/reconciliação, saúde JVM e capacidade do host.

## G6/G7 - servidor e acesso externo

```bash
docker compose ps
ss -lntup
```

Esperado: DB e Java sem porta pública; Caddy/Grafana em loopback; SSH key-only. Depois execute `runbooks/bootstrap-ngrok.md`.

## G8 - E2E

Smoke: `Home -> /mapa -> login -> dashboard -> consulta API real -> refresh -> logout -> /mapa protegido`.

## G9 - registro da release

Registrar SHAs/tags de frontend, Java, pipeline, deployment e NixOS; batch de dados; reconciliação Gold/PostgreSQL; resultado E2E; pendências epidemiológicas.

A NSS 1.0 não está pronta apenas porque containers estão `Up`.
