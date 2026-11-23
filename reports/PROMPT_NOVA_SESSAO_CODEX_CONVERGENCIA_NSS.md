# Prompt para nova sessão Codex — Convergência integral da matriz NSS

Copie o conteúdo deste arquivo como instrução inicial de uma nova sessão Codex. A sessão deve executar o trabalho abaixo, não apenas propor um plano.

---

## Objetivo

Levar a matriz `reports/MATRIZ_CONFORMIDADE_E_PLANO_CONVERGENCIA_RFC_NSS.md` à convergência integral, conforme o plano aprovado pelo usuário. Isso significa fechar os gaps implementáveis com mudanças mínimas, seguras e verificadas; manter evidência atualizada requisito a requisito; e deixar explicitamente identificados apenas bloqueios que dependem de decisão/aprovação institucional ou ação externa do usuário.

Não assuma que o RFC é um oráculo literal. Preserve comportamento existente que seja mais completo, seguro ou coerente com uma decisão aprovada, desde que registre evidência e justificativa como **CONVERGENTE COM MELHORIA**. Não remova compatibilidade nem mude interpretação epidemiológica para forçar correspondência textual. Quando fontes normativas conflitarem sem resolução segura, registrar a reconciliação necessária e perguntar apenas a decisão que não possa ser descoberta no código, nos documentos ou no histórico aprovado.

## Repositórios e documentos de referência

Workspace principal: `/home/dock/dev/nss-deployment`.

Repositórios NSS relacionados:

- `/home/dock/dev/nss-deployment`
- `/home/dock/dev/NSS-database`
- `/home/dock/dev/Site-Sala-de-Situa-o-de-Saude-Java`
- `/home/dock/dev/nss-front-end`
- `/home/dock/dev/nss-pipeline`
- `/home/dock/dev/nss-NixOS-Configuration`

Leia primeiro todos os `AGENTS.md` aplicáveis e `/home/dock/.codex/RTK.md`. A linha de base é `RFC_NSS_v1_5_Pacote_Desenvolvimento/RFC_NSS_v1_5_consolidado.md`, com OpenAPI, DDL, Manual de Marca e regras locais. A matriz é o ledger de estado e plano aprovado. O relatório `reports/VALIDACAO_E2E_2026-11-21.md` é evidência histórica, não autoridade automática para estado vivo: reconciliar checkpoints contraditórios com a fonte atual antes de marcar qualquer item como validado.

## Regras invioláveis de execução

1. **Preserve worktrees.** Antes de editar, registrar branches/HEAD/status/diff/untracked de cada repo. Não descartar, formatar em massa, resetar, limpar, sobrescrever nem assumir autoria de mudanças preexistentes. Faça a menor alteração isolada possível e relacione os caminhos tocados ao diff prévio. Não faça commit/push/merge/publicação sem pedido explícito.
2. **Ambiente isolado.** Não substitua o ambiente ativo. Para Compose, use nome de projeto distinto, valide `docker compose config` efetivo e respeite a topologia/ordem: migration e permissões NSS-database antes de consumidores. Use `deployment.env` existente em `/home/dock/dev/nss-deployment/deployment.env` sem copiar segredos; o usuário autorizou usar esse arquivo mesmo com modo `0777` e confirmou que os segredos de teste serão trocados antes da migração para outro computador. Não exiba valores, não os coloque em logs, arquivos versionados ou relatório. Não use `docker system prune`, `down -v`, remoção de volume ou dados de produção.
3. **Escopo de e-mail e dados.** E-mails reais foram autorizados anteriormente para os destinatários explicitamente fornecidos na conversa; não acrescente destinatários nem revele endereços/tokens no relatório. Prefira SMTP local determinístico para testes de falha. Não enviar email real de falha ou convite repetido sem necessidade funcional. Não criar dados epidemiológicos fictícios, não expor PHI/PII e não usar dados de produção para teste.
4. **Mudanças protegidas.** Mudanças em schema, autenticação/autorização, interpretação epidemiológica ou contratos exigem critérios de aceite explícitos, testes adequados e aprovação correspondente indicada nos `AGENTS.md`. O usuário aprovou executar este plano e autorizou correções alinhadas a boas práticas, mas isso não autoriza decisões institucionais que dependam de Comunicação, Jurídico/LGPD, Epidemiologia Veterinária ou TI. Trabalhe tudo que for independente e mantenha esses gates identificados.
5. **Verificação e QA.** Rodar verificações relevantes ao diff, inclusive PostgreSQL/Redis reais para contratos críticos, Playwright nos fluxos afetados e pytest/Maven conforme os repositórios. Testes não executados permanecem pendentes. Faça revisão independente QA somente leitura, como exigem as regras; se limite/disponibilidade de agentes impedir, registre a limitação e não alegue revisão. Mutation testing é dirigido a invariantes críticas quando aplicável.
6. **Confidencialidade e comunicação.** Não registrar senhas, JWT, refresh tokens, links de email, tokens de convite, conteúdo clínico, destinatários ou payloads sensíveis. Reportar identificadores não secretos e resultados sanitizados. Envie atualizações breves durante execução longa; não interrompa o trabalho para pedir preferência já aprovada. Pergunte apenas quando houver decisão humana não inferível e bloqueadora.

## Método de execução

### Fase 0 — Reconstruir estado real e baseline

- Ler a matriz aprovada, RFC, OpenAPI, DDL, Manual e regras de todos os repositórios.
- Reinspecionar o estado atual de branches, SHAs, worktrees e diffs; atualizar a seção de snapshot da matriz antes de usar evidência antiga.
- Resolver a linha do tempo do relatório E2E com consultas/artefatos autorizados e atuais. Não apagar histórico contraditório: anexar checkpoint e data, marcar o antigo como supersedido quando houver prova.
- Converter cada requisito P/T/DT, decisão global, modelo, contrato, estado, teste e regra aplicável em critério observável; separar código encontrado, teste executado, validação visual, gate institucional e deploy.

### Fase 1 — Convergir banco, papéis e autorização

- Comparar schema autoritativo versionado com migrations/DDL do RFC, migrations locais e schema implantado no Compose isolado.
- Fechar os requisitos de roles/grants, limites Chefe Geral/Admin, proteção do último Chefe Geral, versão de autorização, step-up, idempotência e auditoria. Testar comportamento no PostgreSQL sob concorrência e invalidar JWT antigo após mudança de autorização.
- Fechar discrepância de produto: a UI `AdminUsersPage` atualmente cobre conta `USER/ADMIN`, ativação, reset e convites; não oferece gestão dos nove papéis/grants, embora Java exponha endpoints de atribuição/revogação. Implementar UI segura e acessível apenas após validar endpoint/contrato/escopo. A regra visual deve respeitar exatamente o RFC e o backend, sem conceder poderes novos.
- Garantir grants SQL mínimos e coerentes, clean install/re-run/upgrade/checksum, e compatibilidade com dados existentes. Sem `DROP` ou migração destrutiva não ensaiada.

### Fase 2 — Fluxos de acesso, e-mail e tokens

- Confirmar API ↔ template ↔ frontend para solicitação, confirmação, decisão, primeiro acesso, convite, reset e reenvio.
- Usar token aleatório criptograficamente seguro de 32 bytes; persistir somente hash (ou HMAC-SHA-256 com segredo separado), manter material recuperável somente no outbox cifrado pelo tempo estritamente necessário e sanitizar após entrega/falha terminal; token nunca em resposta de API, log ou URL de analytics. Link de email deve ser HTTPS público autorizado e funcionar na UI real.
- Confirmar uso único, TTL, replay, host/scheme corretos, ausência de enumeração, outbox, classificação SMTP, retry limitado, DLQ/alerta e limpeza. Separar aceitação SMTP (`SENT`) de entrega em inbox/bounce assíncrono. Não depender de uma conta inexistente/full mailbox como única estratégia de teste; simular 4xx, 5xx e desconexão em SMTP local controlado.

### Fase 3 — Clínica, notificação veterinária e upload municipal

- Alinhar UI, API, banco e email para cadastro/gestão clínica, membership N:M, convite/aceite/revogação, agente, estado e concorrência `If-Match`.
- Validar notificação clínica, vínculo e clínica ativos no início e commit, protocolo, recibo mínimo, faixa etária, idempotência mesmo payload/diferente payload, autorização de representante/admin, outbox e evento auditável.
- Validar recepção de CSV/XLS/XLSX com limites, streaming, signature/MIME, extensão, estrutura/encoding, ZIP bomb, macro/link externo, formula injection, quarentena/malware, cleanup de temporários, limite efetivo e escopo municipal. Nunca promover planilha automaticamente para SINAN/Gold.
- Separar dependência de usuário externo (receber email/clicar link/validar visual) de trabalho técnico independente. Se uma etapa realmente depender de ação do usuário, fazer todos os demais testes possíveis, marcar BLOCKED com pedido objetivo e sem solicitar compartilhamento de token.

### Fase 4 — Pipeline, PostgreSQL analítico e API

- Revalidar CNES exclusivamente por PySUS e SINAN por fonte oficial usando os contratos atuais do pipeline; preservar a remoção da antiga implementação HTTP/código morto se essa decisão continua vigente.
- Validar Bronze → Silver → Gold → PostgreSQL analítico: manifestos, lotes explícitos, fingerprint, contagens, territórios, exclusões, cobertura, competência, transação atômica, idempotência e rollback. Documentar riscos da fonte (por exemplo, `NU_NOTIFIC` ausente e dedupe por igualdade de campos); não chamar a semântica de validada sem aprovação epidemiológica quando aplicável.
- Confirmar `nss` operacional versus `situacao_saude` analítico e o banco/schema real consultado pela API. Testar metadata, doença, município, filtros, total, coverage, publicação corrente e invalidação cache Java/IndexedDB por fingerprint. Não somar históricos e notificações clínicas sem reconciliação homologada.

### Fase 5 — Portal, conteúdo, marca, mídia e acessibilidade

- Fechar por requisito as notícias, revisões, boletins/checkpoints, busca/paginação, mídia, despublicação, Sobre, hierarquia, templates, cache epoch e contratos públicos.
- Executar fluxo visual real nas rotas aplicáveis, incluindo autenticação, acesso negado, loading/empty/error, desktop/mobile, teclado, leitor de tela, foco e WCAG 2.2 AA. Incorporar observações do usuário sem descartá-las.
- Preservar fallback tipográfico e manter qualquer marca/nome/conteúdo ainda não aprovado como gate, não trocar por asset inventado.

### Fase 6 — Deployment, GINFO/NixOS, observabilidade e continuidade

- Validar Compose efetivo com projeto isolado e sem expor serviço interno; confirmar job de DB antes dos consumidores.
- Tratar o perfil NixOS atual como estático: GINFO termina TLS e encaminha ao host em HTTP/80; Nginx publica para Caddy loopback 8080. Não interpretar esse perfil como API/SMTP integrado. Confirmar com a configuração GINFO qual forwarded header é confiável para IP de cliente e garantir confiança restrita ao proxy autorizado; não confiar em headers arbitrários do usuário.
- Verificar origin HTTPS público para links, CORS, forwarded scheme, headers, Request-ID, logs sanitizados, métricas, alertas e recuperação controlada de Redis/SMTP/API.
- Não declarar RPO/RTO cumpridos antes de backup e restore completo PostgreSQL + manifesto/arquivos, SHA-256 e medição em host separado.

### Fase 7 — Revisão requisito a requisito e fechamento

- Atualizar a matriz durante a execução, com snapshot/branch/commit e distinção de dirty worktree, comandos, resultado exato, evidência e limitação.
- Marcar linha como `VALIDADO` somente se critério completo e evidência atual cobrirem o requisito. Usar `CONVERGENTE COM MELHORIA` quando implementação superior estiver demonstrada. Usar `N/A` apenas com justificativa do modo/escopo. Bloqueios institucionais devem ter autoridade/responsável/ação necessária, sem ficarem disfarçados como PASS.
- Uma matriz está convergida quando não restarem gaps implementáveis abertos, e cada item restante estiver validado, justificado como melhoria, N/A ou bloqueado por ação externa identificada. Para cada bloqueio, concluir todo trabalho independente antes de pedir a ação do usuário.
- Rever se matriz e comportamento realmente convergiram; manter o plano de fases e o prompt consistente com alterações realizadas. Produzir resumo final com arquivos modificados, critérios fechados, comandos/resultados, achados, bloqueios, riscos, estado de ambientes e procedimento de limpeza segura.

## Critério de sucesso

Não encerrar após inspeção ou documentação inicial. Continuar corrigindo gaps implementáveis e verificando-os até a regra de fechamento da Fase 7. Não reduzir critérios, falsificar evidência, apagar alterações existentes, executar em produção, nem encerrar todo o objetivo só porque surgiu um gate externo: concluir o restante independente e deixar o gate claramente delimitado.

---

## Registro desta sessão

Este prompt é orientação de execução para uma sessão nova. A matriz e o plano base estão em `reports/MATRIZ_CONFORMIDADE_E_PLANO_CONVERGENCIA_RFC_NSS.md`; o relatório E2E em `reports/VALIDACAO_E2E_2026-11-21.md` contém históricos contraditórios a reconciliar com estado atual. O usuário aprovou o planejamento da matriz e autorizou a execução das correções alinhadas à segurança e boas práticas dentro das aprovações e gates descritos acima.
