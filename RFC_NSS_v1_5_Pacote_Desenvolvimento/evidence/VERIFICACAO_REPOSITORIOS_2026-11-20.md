# Evidências da auditoria de repositórios NSS (corte: 20/11/2026)

**Escopo:** inspeção das árvores e de arquivos relevantes pela integração GitHub, utilizando branches/SHAs exatos identificados. Não houve checkout, build, CI disparada, acesso a segredos, PostgreSQL ou produção. Portanto, “encontrado” significa presente no código daquela revisão, e não funcionalidade executada/homologada.

## Repositórios, commits e versões

| Repositório | Branch | HEAD observado |
|---|---|---|
| [NSS-pipeline](https://github.com/Zadoque/NSS-pipeline) | `feat/national-coverage-validation` | `767c46e6ceb1b1dbf847ce7a7904ea86f6dd0c42` |
| [NSS-pipeline](https://github.com/Zadoque/NSS-pipeline) | `main` | `daf0918b000c0a15fc2dddd9bbb1638468102c6f` |
| [NSS-pipeline](https://github.com/Zadoque/NSS-pipeline) | `feature/pipeline` | `d22171eee7a9b9ce3e4e17d3123636c8d0d69c99` |
| [NSS-pipeline](https://github.com/Zadoque/NSS-pipeline) | `work/nss-pipeline` | `257cc1d1b3aa36089669927c2d1be68193f7473d` |
| [NSS-front-end](https://github.com/Zadoque/NSS-front-end) | `feat/national-coverage-validation` | `93c889a1d2bfd93c1cbd9d95c28ec4b5d36e5b67` |
| [NSS-front-end](https://github.com/Zadoque/NSS-front-end) | `feat/preview-portal-mock-2026` | `17b6689443dd5d3000e60b2b1ca806ea3ee2be28` |
| [Site-Sala-de-Situa-o-de-Saude-Java](https://github.com/Zadoque/Site-Sala-de-Situa-o-de-Saude-Java) | `feat/national-coverage-validation` | `815fdf2e66e53f83ff08b43f6cf10b29b55a8639` |
| [NSS-deployment](https://github.com/Zadoque/NSS-deployment) | `feat/national-coverage-validation` | `8a7f99deb877e8cc94fd28f1a24992268c9ad128` |
| [NSS-database](https://github.com/Zadoque/NSS-database) | `feat/national-coverage-validation` | `00300620f34abb2419feaf6a0bda239277571d36` |

## Achados verificados com evidência específica

| AUD | Parecer técnico após código | Evidência e consequência |
|---|---|---|
| 001 | **Confirmado** | [Gold animal na main](https://github.com/Zadoque/NSS-pipeline/blob/main/app/pipeline/esporo/gold.py) tem `COLUMN_MAP` com somente data/especie/sexo/idade/castração; não existem raça/bairro/clínica. [Load](https://github.com/Zadoque/NSS-pipeline/blob/main/app/pipeline/esporo/load.py) substitui snapshot sem chave de vínculo com notificações web. |
| 002 | **Parcialmente incorreto** | [JwtAuthenticationFilter](https://github.com/Zadoque/Site-Sala-de-Situa-o-de-Saude-Java/blob/feat/national-coverage-validation/src/main/java/com/example/nss/user/security/JwtAuthenticationFilter.java) já busca UserDetails e compara `accountRevision` a cada request autenticada; [JwtService](https://github.com/Zadoque/Site-Sala-de-Situa-o-de-Saude-Java/blob/feat/national-coverage-validation/src/main/java/com/example/nss/user/security/JwtService.java) emite claim. Falta propagação de novas roles/grants e autorização no resource. |
| 004 | **Parcial** | [FirstAccessService](https://github.com/Zadoque/Site-Sala-de-Situa-o-de-Saude-Java/blob/feat/national-coverage-validation/src/main/java/com/example/nss/user/service/FirstAccessService.java) já tem expiração de tokens; a lacuna é unificar TTLs dos novos casos e fluxos de e-mail existente. |
| 008 | **Parcial e relevante** | Publicações já são registradas em [migrations/0001/analytics.sql](https://github.com/Zadoque/NSS-database/blob/feat/national-coverage-validation/migrations/0001/analytics.sql) (`pipeline_publications`, `pipeline_current_publication`). O consumer editorial, checkpoint e sincronização de dados ainda exigem novo contrato. |
| 009 | **Parcialmente incorreto** | [AuthRateLimiter](https://github.com/Zadoque/Site-Sala-de-Situa-o-de-Saude-Java/blob/feat/national-coverage-validation/src/main/java/com/example/nss/user/service/AuthRateLimiter.java) já usa Lua/HMAC e falha fechada quando Redis não responde. Faltam limites transversais para novas rotas, política declarada de leitura e critérios de falha vs tentativa. |
| 010 | **Parcial** | [dailyCache.ts](https://github.com/Zadoque/NSS-front-end/blob/feat/national-coverage-validation/src/features/dashboard/cache/dailyCache.ts) já isola IndexedDB por usuário/revisão/URL e invalida ao trocar a sessão. Não inclui `publicationFingerprint` da Gold. [AnalyticsResponseCache](https://github.com/Zadoque/Site-Sala-de-Situa-o-de-Saude-Java/blob/feat/national-coverage-validation/src/main/java/com/example/nss/analytics/repository/AnalyticsResponseCache.java) usa revisão estática. |
| 015 | **Parcial** | O controle HMAC e scripts Lua já existem, mas step-up e reservas concorrentes de Argon2 para novas operações não foram verificados. [Compose](https://github.com/Zadoque/NSS-deployment/blob/feat/national-coverage-validation/compose.yaml) define `AUTH_RATE_LIMIT_LOGIN_MAXIMUM` default **50**, diferente da proposta final de **10 falhas/15min**. Essa variável tem de ser reconciliada antes de go-live. |
| 016 | **Parcialmente incorreto** | [sinan/silver.py](https://github.com/Zadoque/NSS-pipeline/blob/feat/national-coverage-validation/app/pipeline/sinan/silver.py) já utiliza `DT_NOTIFIC` como filtro de competência humana, e [gold_rules.py](https://github.com/Zadoque/NSS-pipeline/blob/feat/national-coverage-validation/app/pipeline/sinan/gold_rules.py) usa fallback de semana ISO. O componente animal e nulos continuam lacuna. |
| 024 | **Confirmado para projeto, não para código atual** | [AccountType](https://github.com/Zadoque/Site-Sala-de-Situa-o-de-Saude-Java/blob/feat/national-coverage-validation/src/main/java/com/example/nss/user/entity/AccountType.java) contém apenas `ADMIN`, `USER`, não os nove novos papéis previstos no RFC v1.4. |
| 030 | **Confirmado como gate, não como bug de código** | [HomePage](https://github.com/Zadoque/NSS-front-end/blob/feat/national-coverage-validation/src/features/home/pages/HomePage.tsx) exibe fallback tipográfico. O candidato `public/logo.jpg` é registrado no Manual v1.0 e na branch `feat/preview-portal-mock-2026`, mas a inspeção GitHub não constitui prova de licença/homologação institucional. |

**Topologia de infraestrutura:** [NSS-deployment/compose.yaml](https://github.com/Zadoque/NSS-deployment/blob/feat/national-coverage-validation/compose.yaml) contém `redis`, `redis-rate-limit` e `redis-analytics`; **não** contém `redis-public-cache` na revisão inspecionada. O 4º serviço é novo trabalho de implementação, e a documentação não deve marcá-lo como já implantado.

**Migração animal:** [NSS-database/migrations/0001/analytics.sql](https://github.com/Zadoque/NSS-database/blob/feat/national-coverage-validation/migrations/0001/analytics.sql) define `analytics_animal.fato_esporo` com colunas textuais, enquanto `gold/load.py` da main exige colunas com sufixo `_codigo`. A `0003` deve verificar vazios/migrar sem perda de dados. A branch nacional [esporo/run.py](https://github.com/Zadoque/NSS-pipeline/blob/feat/national-coverage-validation/app/pipeline/esporo/run.py) chama Bronze/Silver, mas ainda não chama Gold/Load. **Não copiar a main inteira por merge automático**: fazer integração cirúrgica e testes nacionais.

**Contratos preservados:** [api-v1.md](https://github.com/Zadoque/NSS-deployment/blob/feat/national-coverage-validation/contracts/api-v1.md) já define semântica humana (`notifications`, estados `AVAILABLE/PARTIAL/UNAVAILABLE`), enquanto [auth-v1.md](https://github.com/Zadoque/NSS-deployment/blob/feat/national-coverage-validation/contracts/auth-v1.md) fixa access 15min, refresh 7d. A v1.5 é uma extensão aditiva, não autorização para remover rotas ativas.

## Classificação de todos os 32 achados

A tabela ao final do `RFC_NSS_v1_5_consolidado.md` dá a regra resolutiva para cada AUD-001 até AUD-032. Os itens listados nesta página possuem **confronto específico com arquivo de código**; para os restantes, o grau de evidência é **documental/arquitetural** (o que a v1.4 especificava ou deixava aberto), sem afirmação de ausência absoluta em todas as branches. A incerteza é preservada intencionalmente.

## Gates não substituíveis por testes de código

- **Comunicação UENF:** direitos/uso de marca ilustrada e logs oficiais; confirmar LRB e as entidades da hierarquia.
- **Coordenação NSS / Epidemiologia Veterinária:** ficha e dicionário clínico e concordância com coexistência de Gold histórica e clínica, sem soma.
- **Encarregado LGPD / Jurídico da UENF:** base legal, temporalidade e redação definitiva de privacidade, termos e rodapé; aprovação de fotos de membros quando exigível.
- **TI institucional:** armazenamento externo de backup, RPO/RTO e restore com manifesto; rede, proxy e certificados.
- **QA:** testes reais de concorrência, Java, React, pipeline e OpenAPI. Não foram executados nesta revisão documental.
