# Matriz de requisitos P/T/DT

Esta matriz é um inventário executável do estado local. `VALIDADO` exige código e teste; `PARCIAL` indica cobertura incompleta; `GATE` depende de aprovação institucional ou infraestrutura externa.

| Requisito | Evidência atual | Lacuna real | Repositório | Dependências | Teste necessário / estado |
|---|---|---|---|---|---|
| P-01 | portal público, mapas protegidos, grants e nove papéis | acessibilidade manual e gates | Java, frontend, database | PostgreSQL, Redis | identidade/epidemiologia: VALIDADO |
| P-02 | autenticação, outbox, auditoria e rate limit | entrega SMTP institucional e observabilidade externa | Java, database | SMTP, Redis | auth/outbox e catálogo dos 10 templates: VALIDADO técnico; entrega/alertas: PARCIAL |
| P-03 | clínicas N:M, CEP, sucessão e convites | homologação de papéis clínicos | Java, database | PostgreSQL | `ClinicInvitationPostgresIT`: VALIDADO |
| P-04 | conteúdo versionado, créditos e auditoria | revisão editorial institucional | Java, frontend | PostgreSQL | CMS/asset: VALIDADO |
| P-05 | representantes, vínculos e upload municipal | fluxo municipal E2E com ambiente institucional | Java, database, frontend | storage | backend upload/quota + página multipart protegida por `MUNICIPAL_UPLOAD`: VALIDADO técnico; E2E institucional: PARCIAL |
| P-06 | CMS, slugs, busca, revisão e SEO básico | auditoria SEO e acessibilidade visual | Java, frontend | PostgreSQL | CMS/search: VALIDADO |
| P-07 | About, legal, brand fallback e assets aprovados | conteúdo e aprovação institucional | Java, frontend | Comunicação | brand/legal: VALIDADO; GOV: GATE |
| P-08 | boletins, checkpoints, aprovação e retirada | volume institucional e homologação editorial | Java, database | analytics reader | `BulletinPublicationPostgresIT` cobre analytics → checkpoint → revisão idempotente; geração técnica: VALIDADO; escala/homologação: PARCIAL |
| P-09 | clínica, seis etapas, correção/cancelamento e recibo | revisão veterinária do domínio | Java, frontend, database | PostgreSQL, SMTP | veterinary IT/Playwright: VALIDADO |
| P-10 | municípios, memberships e arquivos versionados | aprovação de dados recebidos | Java, database | storage | municipal IT: VALIDADO |
| P-11 | Gold histórica e clínica separadas | publicação clínica em volume institucional e homologação epidemiológica | pipeline, Java, database | analytics | Gold ESPORO e Gold clínica independente, publicador idempotente e API Java consumindo somente `fato_clinical`: VALIDADO técnico; escala/homologação: PARCIAL |
| P-12 | proveniência, coverage, fingerprint e metadata | publicação clínica em escala institucional | pipeline, Java, frontend | analytics | metadata/cache + resposta animal com `publicationFingerprint`, `definitionVersion` e `publishedAt`: VALIDADO técnico |
| P-13 | mapas territoriais e escopo municipal histórico | fonte clínica ainda depende de cobertura | Java, frontend | Gold clínica | ESPORO/SIFA Playwright + API clínica municipal sobre Gold persistida: VALIDADO técnico |
| P-14 | publicação atomicamente identificada e cache por fingerprint | consumidores externos do fingerprint | pipeline, Java, frontend | PostgreSQL, IndexedDB | cache-window 15/15: VALIDADO |
| P-15 | APIs humanas e animais independentes | carga nacional e reconciliação clínica | Java, pipeline | analytics | APIs separadas, fonte clínica persistida e contrato OpenAPI sincronizado: VALIDADO técnico; carga/reconciliação: PARCIAL |
| P-16 | competência, idade, desconhecido e CNES explícitos | benchmark nacional em escala institucional | pipeline, Java | dados sanitizados | Gold/faixas etárias: VALIDADO; benchmark sintético 1M: VALIDADO técnico; escala nacional: PARCIAL |
| P-17 | JWT, refresh, roles/grants e step-up | prova completa de fail-closed 503 em todas as rotas | Java | PostgreSQL, Redis | `AuthRateLimitUnavailableContractIT` cobre login, primeiro acesso, reset (solicitação/conclusão) e refresh com Redis indisponível: VALIDADO técnico; matriz de autorização adversarial: PARCIAL |
| P-18 | schemas, migrations, quotas e restore local | backup externo/cifrado institucional | database, Java | storage externo | schema-smoke/restore: VALIDADO; externo: GATE |
| P-19 | auditoria e eventos operacionais sanitizados | retenção e consulta institucional | Java, database | observabilidade | identity/audit: VALIDADO |
| P-20 | logs, request IDs, outbox e health existentes | alertas institucionais e SLOs homologados | Java, deployment | observabilidade | Java Actuator/Prometheus, Grafana, alertas de pipeline/Redis e scrape `nss-java`: VALIDADO técnico; operação/SLO: PARCIAL |
| T-01 | migrations 0003..0007 e schemas separados | planos em volume real e roles de infraestrutura | database | PostgreSQL | schema-smoke com analytics 0003 e app 0007: VALIDADO |
| T-02 | JSONB/revisão, uploads e validação | revisão editorial institucional | Java | PostgreSQL | CMS/media + `CmsPostContentSafetyTest`: VALIDADO; homologação editorial: GATE |
| T-03 | checkpoint/worker e fingerprint | volume analytics institucional | Java, pipeline | analytics reader | `BulletinPublicationPostgresIT`: 3/3, incluindo segunda execução idempotente: VALIDADO; escala: PARCIAL |
| T-04 | clínica, convite, notificação e eventos | revisão clínica/homologação | Java, database | PostgreSQL | veterinary tests: VALIDADO |
| T-05 | municipal upload, quota, hash e quarentena | ingestão de planilha real aprovada | Java, database | storage | municipal tests: VALIDADO |
| T-06 | identidade, grants e autorização por escopo | auditoria adversarial completa | Java | PostgreSQL, Redis | authorization tests: VALIDADO; pentest: GATE |
| T-07 | frontend separado por hooks/API/cache | auditoria manual completa de teclado, foco, zoom e fluxos críticos | frontend | Chromium/axe | `tests/accessibility.spec.ts` axe WCAG 2 A/AA em home/login a 320px, mobile keyboard tests, build/lint: TÉCNICO VALIDADO; auditoria manual: GATE |
| T-08 | problem JSON, idempotência, paginação e OpenAPI | contrato automático para todos os 61 endpoints | Java, deployment | OpenAPI | `check_contracts.py`: VALIDADO |
| T-09 | pipeline Bronze/Silver/Gold e publicação | benchmark de reprocessamento/concurrent consumers | pipeline | PostgreSQL, dados sanitizados | `aggregate_file` 1M/10 lotes e `test_publicacoes_concorrentes_do_mesmo_recorte_preservam_um_snapshot_atual`: VALIDADO técnico; escala nacional: PARCIAL |
| DT-02 | grants humano/animal independentes | catálogo final de papéis aprovado | Java, database | PostgreSQL | identity/animal tests: VALIDADO |
| DT-03 | Redis fail-closed e quotas por fluxo | alerta operacional real | Java | Redis/observabilidade | Redis IT + `AuthRateLimitUnavailableContractIT` em rotas HTTP + métricas Actuator/Prometheus e scrape Compose: VALIDADO técnico; alerta institucional: PARCIAL |
| DT-04 | fontes humanas/veterinárias separadas | reconciliação interfonte futura | pipeline, Java | Gold clínica | source separation: VALIDADO |
| DT-05 | territórios desconhecidos e municipal-only | homologação epidemiológica | pipeline, frontend | dados Gold | ESPORO tests: VALIDADO |
| DT-06 | competência original e faixas normativas | benchmark nacional | pipeline | dados sanitizados | age/date tests: VALIDADO |
| DT-07 | migrations aditivas e preservação de `public.users` | simulação sobre cópia institucional | database | PostgreSQL | `schema-smoke.sh` agora atualiza um banco versionado em `0001` até `0007`, preserva usuário existente e valida checksum sem reaplicar DDL antigo: VALIDADO técnico; cópia institucional: PARCIAL |
| DT-08 | concorrência via locks/idempotência | deadlock/load test em volume | Java, database | PostgreSQL | concurrency ITs: VALIDADO; load: PARCIAL |
| DT-09 | problem JSON, request ID e headers | filtro Java propaga/valida `X-Request-Id`; Caddy preserva o header e encaminha o IP confiável | Java, deployment | Caddy | `RequestIdFilterTest`, `tests/proxy-forwarding.sh` e controller tests: VALIDADO técnico; proxy/Caddy de produção: PARCIAL |
| DT-10 | cache epoch/fingerprint e IndexedDB | consumidores externos | Java, frontend | Redis/IndexedDB | cache-window: VALIDADO |
| DT-11 | marca com fallback tipográfico e sem logo candidata | aprovação dos ativos oficiais | frontend, Java | Comunicação | brand tests: VALIDADO; GOV: GATE |
| DT-12 | catálogo dos 10 templates, HTML/plain text, `VERIFY_EMAIL`, primeiro acesso, reset, decisões de acesso, upload municipal, recibo veterinário e boletim condicionado a destinatário explícito integrados ao outbox, retry/DLQ, versões `ACTIVE` semeadas em migration 0007 e verificação SHA-256 com fallback compilado | destinatário de boletim permanece opt-in por configuração; aprovação editorial dos textos ainda é institucional | Java, database | SMTP, Comunicação | `EmailTemplateCatalogTest`, `EmailTemplateRendererTest`, `MailServiceTest`, `FirstAccessServiceTest`, `OutboxWorkerPostgresIT`, `PublicAccessRequestPostgresIT`, `MunicipalUploadPostgresIT`, `VeterinaryNotificationPostgresIT`, schema-smoke 0007: VALIDADO; homologação editorial: GATE |
| DT-13 | minimização, auditoria, acessibilidade e gates | jurídico, LGPD, axe/manual e runbook | todos | institucional | técnico: PARCIAL; homologação: GATE |

## Critério de leitura

Esta matriz não converte `PARCIAL` ou `GATE` em aprovação. O próximo trabalho prioritário é medir carga em escala institucional, completar verificações operacionais externas e concluir os gates de homologação sem alterar dados publicados ou infraestrutura produtiva.
