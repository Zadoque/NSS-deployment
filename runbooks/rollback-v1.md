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

## Transição das sessões Redis

A versão de autenticação que registra família e identificador de credencial exige um corte coordenado. Tokens emitidos pela versão anterior não contêm o identificador de credencial e exigem novo login. Versões antigas não verificam todos os marcadores novos de revogação, portanto não devem atender tráfego ao mesmo tempo que a versão nova.

Antes de qualquer troca, registre a imagem e a configuração em uso e ensaie o procedimento em ambiente isolado. Retire todas as réplicas da API do tráfego e confirme que pararam. Faça a troca integral para a nova versão, verifique Redis, login, refresh e logout e só então libere o tráfego. A janela, o efeito de reautenticação e a ativação do ambiente existente devem ser aprovados previamente.

Para voltar a uma imagem anterior, retire todas as réplicas de ambas as versões do tráfego e invalide as sessões nos repositórios Redis efetivamente usados pelas duas versões antes de iniciar a imagem antiga. Confirme a remoção dos tokens e dos marcadores da aplicação, sem apagar dados de outros serviços. A localização e os prefixos da versão de origem devem ser verificados no código e na configuração usados no ambiente. Em seguida suba a imagem anterior, valide os fluxos de autenticação e libere o tráfego. O procedimento de limpeza e seus efeitos precisam ser ensaiados em cópia antes de operar dados reais.
