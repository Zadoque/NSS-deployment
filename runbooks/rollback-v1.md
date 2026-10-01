# Runbook - rollback NSS 1.0

Objetivo: retornar à última combinação integrada conhecida sem destruir dados persistentes.

## Regra principal

Nunca use `docker compose down -v` durante rollback operacional: isso remove volumes persistentes.

## Rollback de aplicação

1. interrompa temporariamente ngrok web se a versão atual estiver incorreta;
2. identifique tags/SHAs da última release homologada;
3. ajuste `.env`;
4. execute:

```bash
docker compose pull || true
docker compose up -d --force-recreate java frontend caddy
```

5. valide login e consulta local antes de reabrir ngrok.

## Banco de dados

Não execute downgrade Flyway/Alembic automaticamente para acompanhar rollback de imagem. Primeiro determine compatibilidade. Se migration destrutiva exigir estado anterior, use backup aprovado e documente a restauração. Crie `pg_dump` antes de migrations relevantes.

## Pipeline

Se um batch Serving incorreto foi publicado: impeça novas cargas, identifique doença/ano/batch, reexecute versão conhecida a partir de fonte/artefato válido e reconcilie Gold/PostgreSQL antes de reabrir a aplicação. Não corrija números no frontend ou Grafana.

## Ngrok/SSH

Rollback da aplicação não exige remover SSH. O túnel SSH pode permanecer para administração enquanto seguro. O endpoint web deve ficar fechado se a stack não passar o smoke local.
