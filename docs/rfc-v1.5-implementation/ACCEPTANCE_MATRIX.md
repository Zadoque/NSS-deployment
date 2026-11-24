# Matriz de aceite RFC NSS v1.5

Status: `PASS` significa que existe teste reproduzível cobrindo o cenário descrito; `PARCIAL` significa que há cobertura relacionada, mas não prova todo o cenário; `PENDENTE` significa que ainda não foi executado ou requer infraestrutura/homologação externa.

| Teste | Situação atual | Evidência reproduzível | Lacuna explícita |
|---|---|---|---|
| TST-AUD-001 | PASS | `NSS-database/tests/last-chief-concurrency.sh`: duas transações paralelas, exatamente uma remoção aceita, uma rejeitada e um Chefe Geral ativo preservado | Nenhuma conhecida no escopo automatizado |
| TST-AUD-002 | PASS | `JwtAuthorizationRevocationPostgresIT`: o mesmo JWT é aceito antes e rejeitado após incremento transacional de `authorization_version` | Nenhuma conhecida no escopo automatizado |
| TST-AUD-003 | PASS | `AuthControllerContractIT`, `IdentityAuthorizationControllerTest` | Nenhuma conhecida no escopo automatizado |
| TST-AUD-004 | PASS | `AuthRateLimiterRedisIT`: 20 tentativas concorrentes para a mesma conta, distribuídas entre duas instâncias do limiter Redis, aceitaram exatamente o limite configurado e rejeitaram o excedente; `AuthRateLimitContractIT`: 20 requests HTTP de login aceitaram 5 e rejeitaram 15 com `Retry-After` | O teste HTTP usa autenticação/mock de serviços downstream e Redis efêmero local; não substitui teste de carga institucional |
| TST-AUD-005 | PASS | `AuthRateLimiterRedisIT` com Redis efêmero; comportamento fail-closed testado | Alertas operacionais dependem do ambiente de observabilidade |
| TST-AUD-006 | PASS | `PublicAccessRequestControllerIT` e testes de não enumeração | Nenhuma conhecida no escopo automatizado |
| TST-AUD-007 | PASS | `FirstAccessIntegrationIT` (primeiro acesso/reset expirados), `RefreshSessionIntegrationIT`, `ClinicInvitationPostgresIT`, JWT expirado e `PublicAccessRequestPostgresIT` (verificação de e-mail e consulta por protocolo expiradas) | Nenhuma conhecida no escopo automatizado; tokens emitidos por provedores externos ficam fora do serviço |
| TST-AUD-008 | PASS | `ClinicInvitationPostgresIT`: representante aceito, revogado, convidado novamente e aceito; dois registros históricos permanecem e somente um vínculo fica ativo | Nenhuma conhecida no escopo automatizado |
| TST-AUD-009 | PASS | `ClinicInvitationPostgresIT`: Chefe Geral recupera clínica sem gestor atribuindo agente; agente sem papel de chefia recebe 403 | Nenhuma conhecida no escopo automatizado |
| TST-AUD-010 | PASS | `VeterinaryNotificationPostgresIT`: retry idêntico e corpo diferente retornando 409 | Nenhuma conhecida para a rota clínica |
| TST-AUD-011 | PASS | `MunicipalUploadPostgresIT` + `MunicipalUploadSafetyTest`: CSV idêntico 409, hash novo encadeado, fórmula em quarentena e extensão `.xlsm` rejeitada antes do parsing | Formatos futuros exigem regra explícita e teste correspondente |
| TST-AUD-012 | PASS | `MunicipalUploadPostgresIT`: upload antigo conserva `effectiveLimitBytes`; novo upload obedece teto reduzido | Nenhuma conhecida no escopo automatizado |
| TST-AUD-013 | PASS | metadata expõe `publicationFingerprint`; `tests/cache-window.spec.ts` prova que v1 reutiliza o cache IndexedDB e v2 força uma nova consulta; Playwright ESPORO/SIFA | Nenhuma conhecida no escopo automatizado |
| TST-AUD-014 | PASS | `BulletinPublicationPostgresIT`: duas aprovações concorrentes sobre a mesma versão produziram exatamente uma publicação e um conflito 409 de versão obsoleta; epoch avançou uma vez | Nenhuma conhecida no escopo automatizado |
| TST-AUD-015 | PASS | `BulletinPublicationPostgresIT`: v2 aprovado, despublicação limpa o ponteiro público, não restaura v1 e incrementa o cache epoch | Nenhuma conhecida no escopo automatizado |
| TST-AUD-016 | PASS | testes de faixas etárias da pipeline e Gold; datas ausentes explícitas | Nenhuma lacuna conhecida na pipeline histórica exercitada |
| TST-AUD-017 | PASS | `CmsSharedAssetPostgresIT`: asset referenciado por dois posts permanece acessível após retirar o primeiro e retorna 404 após retirar o último | Nenhuma conhecida no escopo automatizado |
| TST-AUD-018 | PASS | `PublicSearchPostgresIT`: massa de 45 notícias, busca portuguesa acentuada, limite máximo de 20 e paginação 20/20/4; conteúdo não publicado permanece fora da consulta | Nenhuma conhecida no escopo automatizado |
| TST-AUD-019 | PASS | `IdentityAuthorizationPostgresIT`: Admin sem papel de Chefe Geral não atribui `CHEFE_GERAL` nem gera auditoria; usuário comum recebe 403 no proxy CEP | Nenhuma conhecida no escopo automatizado |
| TST-AUD-020 | PASS | `tests/veterinary-form.spec.ts`: percorre as seis etapas sem persistir rascunho e, em outra aba, troca a identidade da sessão; o formulário é desmontado e retorna ao login | A troca de identidade usa respostas HTTP interceptadas no Playwright; autenticação contra um IdP externo não faz parte deste checkout |
| TST-AUD-021 | PASS | `OutboxWorkerPostgresIT` prova envio único, não seleção novamente após `SENT` e `FAILED_PERMANENT` na sexta tentativa; `MailpitDeliveryIT` prova SMTP real; `Smtp550DeliveryIT` prova rejeição 550 sanitizada; upload municipal e notificação veterinária provam criação de eventos no outbox | Entrega dos novos eventos depende de SMTP/outbox habilitados no ambiente de implantação |
| TST-AUD-022 | PARCIAL | `tests/restore-smoke.sh` restaura PostgreSQL e mídia em containers separados, valida manifesto SHA-256, simula storage separado, verifica backup cifrado com HMAC e mede RTO local (`171 ms` na execução atual); reproduzível em NixOS com `nix shell nixpkgs#openssl --command bash tests/restore-smoke.sh` | Ainda não é restore em host/storage externo nem valida gestão institucional de chaves/backup |

## Comandos-base

```bash
cd /home/dock/dev/Site-Sala-de-Situa-o-de-Saude-Java
JWT_SECRET="$(head -c 32 /dev/zero | base64 -w0)" ./mvnw -q test -DskipITs
JWT_SECRET="$(head -c 32 /dev/zero | base64 -w0)" ./mvnw -q -DskipITs -Dtest=VeterinaryNotificationPostgresIT,ClinicInvitationPostgresIT,CmsPublicationPostgresIT test

cd /home/dock/dev/NSS-database
docker build -t nss-database:upgrade-smoke .
NSS_DATABASE_IMAGE=nss-database:upgrade-smoke sh tests/schema-smoke.sh

cd /home/dock/dev/nss-pipeline
nix develop --no-update-lock-file --command pytest -q

cd /home/dock/dev/nss-deployment
uv run --with pyyaml python RFC_NSS_v1_5_Pacote_Desenvolvimento/check_contracts.py
```

Os itens `PENDENTE` não são declarados como aprovados. Os gates institucionais GOV-01..GOV-07 permanecem separados da conclusão técnica.
