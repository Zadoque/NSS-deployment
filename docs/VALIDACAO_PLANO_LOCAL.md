# Validação local do plano técnico

Data da execução: 2026-11-10  
Branch: `feat/national-coverage-validation`

Este documento registra as evidências locais usadas para auditar o plano publicado em
`/home/dock/dev/nss-runtime-data/plan-public/index.html`. Ele não substitui um teste
de pré-produção nem autoriza a troca do ambiente ativo.

## Estado dos repositórios

Todos os repositórios do projeto estão na branch `feat/national-coverage-validation`.
Os commits de implementação e documentação foram enviados ao GitHub. Alterações locais
de geometrias e do catálogo territorial permanecem deliberadamente fora dos commits,
pois já existiam antes desta etapa.

## Evidências executadas

| Área | Evidência | Resultado |
|---|---|---|
| Schema central | Criação/reexecução em PostgreSQL descartável, permissões e consumidores | Aprovado nos testes do NSS-database e CI |
| Sessões/rate limit | Redis real para integração de sessão e `AuthRateLimiter` | Testes Redis aprovados; decisão distribuída não depende do `HashMap` |
| Cache analítico | Redis dedicado, chave versionada, TTL, fail-open e teste unitário | 3 testes de cache aprovados; imagem Java iniciou com Redis dedicado |
| Java | Maven/Docker build | 112 testes passaram na imagem `nss-java:cache-validation` |
| CI Java | `verify`, `mutation`, `container` | Todos passaram no PR |
| Paridade SQL | Cenários Brasil, UF, município, distrito, bairro e filtros | Respostas equivalentes entre alternativas de 3, 2 e 1 consulta |
| Carga Dengue 2024 | Parquet nacional e publicação em banco descartável | 6.564.924 linhas de entrada; 6.177.144 resolvidas; 5.571 municípios |
| API concorrente | Endpoint autenticado local, 500 e 1.000 requisições | 100% HTTP 200; p95 de 3,88 s e 4,94 s, respectivamente |
| HTTP estático | Caddy local, 10.000 requisições concorrentes controladas | 100% HTTP 200; p95 de 443 ms |
| Frontend | `npm run build` e `npm run lint` | Aprovados; bundle produzido (aviso não bloqueante de chunk acima de 500 kB) |
| Frontend QA | CI com Chromium: `npm run test:builds` e `npx playwright test tests/auth-resilience.spec.ts --workers=1` | Aprovado; build snapshots e teste de resiliência executados no browser |
| Frontend smoke visual | Navegação local em `http://127.0.0.1:8088/` | Homepage carregou com título, links de login/mapa, missão e aviso explícito de cobertura parcial |
| Navegação RJ one-district | Vite mock + fluxo Sudeste → RJ → Rio de Janeiro → bairros → Voltar | Reproduziu a regressão, corrigiu o ramo demo e confirmou retorno direto à tela de municípios sem tela de distritos |

### Reconciliação dos GeoJSON

Os diretórios não são réplicas byte a byte. A pipeline preserva fontes e candidatos
territoriais para ingestão e fallback; o frontend publica uma versão canônica promovida
para servir a aplicação. Na validação atual:

| Repositório | Conteúdo | Quantidade aproximada |
|---|---|---:|
| `nss-pipeline/territories` | IBGE, OSM, fontes oficiais, RJ e assets de Campos | 14.070 GeoJSON / 362 MiB |
| `nss-front-end/public/maps/national` | asset nacional canônico por município para distritos e bairros, mais índices | 16.769 GeoJSON / 257 MiB |

O critério de equivalência é o catálogo e os códigos, não o tamanho dos arquivos:
o frontend contém 5.571 assets de distrito e 5.571 de bairros, além de 5.571 mapas
municipais; a pipeline contém múltiplos candidatos por território (por exemplo, IBGE
e OSM), que são selecionados pela prioridade documentada antes da promoção. Um asset
da pipeline não publicado no frontend não significa necessariamente perda: pode ser
uma fonte alternativa, um município sem geometria nacional promovível ou um artefato
de fallback. A reconciliação deve comparar manifestos, códigos e status de promoção.
| Pipeline | `nix develop --command python -m pytest -q` | 748 passaram, 23 ignorados, 1 warning de dependência |
| Pipeline territorial | `feat(territories)` após validar todos os GeoJSON | Normalização de parent district, precedência de fontes, exportação catálogo/API e classificação CNES vetorizada versionadas em `8aaaebcc` |
| Dependências frontend | `npm audit --omit=dev --audit-level=high` | 0 vulnerabilidades info/low/moderate/high/critical no snapshot local |
| Higiene de diff | `git diff --check` nos cinco repositórios | Sem erro de whitespace nos diffs presentes |
| Deployment TTY | `bash -n scripts/nss-deploy.sh`, `docker compose --env-file .env.example config --quiet` e inspeção do fluxo `up` | Sintaxe e Compose válidos; fluxo sobe DB, três Redis, migration, Java, web e status |

Os artefatos detalhados da carga, paridade e dimensionamento estão no diretório local
de validação (`nss-runtime-data/implementation-validation`) e não contêm credenciais.

## Cache analítico

O cache é opcional e desativado por padrão. Quando habilitado, usa uma instância Redis
dedicada, política `allkeys-lfu`, chave com revisão e digest SHA-256 dos filtros
normalizados, TTL configurável e tratamento fail-open. A autorização continua ocorrendo
antes da leitura do cache. O Redis de analytics não compartilha volume nem orçamento com
sessões ou rate limiting.

O teste de runtime confirmou:

```text
GET /actuator/health/readiness -> {"status":"UP"}
Redis dedicado -> PONG
PostgreSQL operacional e analítico -> conexões aceitas
```

## Segurança e qualidade

- O limitador de autenticação usa Redis e scripts atômicos no caminho distribuído; não
  há dependência operacional do mapa local de 10 mil entradas.
- Sessões de refresh são armazenadas como hashes no Redis, com TTL e rotação.
- O cache não é consultado antes da autorização e não contém credenciais.
- O CI executou testes, mutação e construção da imagem.
- O teste unitário do cache cobre acerto, ausência e falha do Redis.

## Limitações que permanecem explícitas

1. A máquina local não certifica a meta de 100 mil sessões nem o cenário de 5 mil RPS;
   os testes locais são smoke/load tests de capacidade e não um SLO de produção.
2. A execução do backend cacheado foi validada até readiness e conectividade Redis;
   um benchmark comparativo aquecido/vazio em HTTP deve ser repetido em pré-produção
   com identidades e dados representativos.
3. O `up` do deployment foi validado por sintaxe, composição e componentes isolados;
   a execução destrutiva de bootstrap completo deve ocorrer em servidor TTY descartável
   ou janela aprovada.
4. A validação local não usa ngrok e não substitui revisão de segurança operacional,
   observabilidade e rollback no ambiente de produção.
5. O `.env` local não contém todos os segredos necessários para executar o Compose
   real; por isso a composição foi validada com `.env.example`, sem iniciar uma stack
   de produção nem expor credenciais.

## Critério de encerramento

O plano pode ser considerado tecnicamente implementado nos repositórios quando os
checks do CI permanecerem verdes e os artefatos acima forem reproduzidos. A validação
integral de capacidade e a liberação operacional continuam pendentes até a execução em
pré-produção com os cenários de carga definidos no HTML.

## Matriz de aceite auditada

| Requisito do HTML | Estado atual | Evidência ou pendência |
|---|---|---|
| Banco centralizado e migration inicial | **Comprovado localmente** | NSS-database, CI e PostgreSQL descartável |
| Sessões Redis e rate limiter distribuído | **Comprovado localmente** | Integração Redis real, scripts atômicos e testes Java |
| Cache diário do frontend até 02h | **Comprovado por código/build** | Implementação, build, lint e 51 testes descobertos |
| Cache analítico Redis dedicado | **Comprovado localmente** | Testes unitários, imagem Docker e readiness com Redis dedicado |
| Comparação de 3/2/1 consultas | **Comprovado localmente** | Paridade e benchmark SQL no mesmo snapshot |
| Carga nacional Dengue 2024 | **Comprovado localmente** | Lote completo processado e reconciliado |
| Segurança de dependências e higiene | **Comprovado no snapshot** | `npm audit`, `git diff --check`, CI e testes de mutação |
| QA browser Playwright executado | **Comprovado no CI** | Chromium instalado no runner; `test:builds` e `auth-resilience` passaram |
| Meta de 100 mil sessões / 5 mil RPS | **Pendente** | Exige pré-produção; testes locais não certificam esse SLO |
| Bootstrap completo em servidor TTY | **Parcial** | Script, Compose e componentes validados; execução real requer `.env` e servidor descartável |
| Liberação/rollback operacional | **Pendente** | Requer janela aprovada e ensaio no ambiente alvo |
