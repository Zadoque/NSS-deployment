---
title: "Manual de Marca e Interfaces — NSS/UENF"
subtitle: "Revisão 1.1 | Anexo normativo de design do RFC-NSS-001 v1.5"
author: "NSS / UENF — proposta para homologação da Comunicação Institucional"
date: "20 de novembro de 2026"
lang: pt-BR
---

# 1. Aplicação, responsáveis e estado de aprovação

Este Manual v1.1 especifica a identidade e a implementação visual dos produtos digitais NSS/UENF: portal, páginas de autenticação, dashboard humano, dashboard veterinário, notícias, boletins PDF/HTML, página Sobre, formulários de clínica/município e e-mails transacionais. A redação é **normativa para desenvolvimento**, mas a imagem ilustrada da marca, logos oficiais e qualquer alegação de filiação institucional só poderão ser publicadas depois de autorização dos responsáveis. Esta revisão harmoniza o Manual v1.0 e o RFC-NSS-001 v1.5, prevalecendo sobre o checklist incompatível do antigo manual.

A Comunicação Institucional da UENF aprova identidade, proporção, aplicação e marcas oficiais. A direção/Coordenação do NSS aprova a representação factual da equipe e dos setores envolvidos. A administração de conteúdo institucional é exclusiva do papel **CHEFE_GERAL** e não atribui propriedade sobre marcas da UENF ao operador da plataforma. O Encarregado LGPD e o Jurídico revisam textos legais, avisos e critérios de exposição de integrantes; a Epidemiologia aprova legendas e símbolos epidemiológicos.

# 2. Ativo da marca, proveniência e política de fallback

A marca ilustrada criada por IA foi identificada como `public/logo.jpg` na branch `feat/preview-portal-mock-2026` do repositório `Zadoque/NSS-front-end`. O Manual v1.0 registra o SHA do blob Git `4b94b0068e2e0f14d33910914bdb74664614e7fc`; esse valor serve como referência de auditoria, **não** como validação de direitos ou licença. O arquivo original, quando homologado, deve ser copiado preservando checksum, dimensões e proporções; derivações WebP/PNG/SVG somente mediante conversão sem introduzir novo desenho e mantendo sua rastreabilidade.

**Antes da homologação**: utilizar a marca textual "NSS" em azul como implementada em `src/features/home/pages/HomePage.tsx` na branch nacional, acompanhada de “Núcleo de Situação de Saúde”, e nunca simular visualmente uma logomarca oficial. A Comunicação pode rejeitar o ativo ilustrado sem interromper o funcionamento, pois o fallback tipográfico é completo e acessível.

**Inventário obrigatório de marca** em `institutional.brand_assets`: `id, entity_code, variant, original_filename, mime_type, source_url, rights_basis, approval_reference, approved_by, approved_at, sha256, version, is_active`. Não disponibilizar `is_active=true` sem o registro formal apropriado. Recursos oficiais são servidos em rota de mídia institucional versionada; não permitir que o CMS arbitrário substitua logos da universidade.

# 3. Hierarquia visual da página Sobre

A sequência horizontal (desktop) ou vertical (mobile) de instituições reflete **ordem de apresentação aprovada**, não cria automaticamente vínculo jurídico ou de subordinação:

1. **UENF** — marca da Universidade Estadual do Norte Fluminense Darcy Ribeiro, visibilidade principal.
2. **PROPPG / PROEX** — Pró-Reitoria de Pesquisa e Pós-Graduação e Pró-Reitoria de Extensão, quando houver vínculo comprovado e autorização de ambas as marcas.
3. **CCTA / CCT / CBB** — unidades/centros citados no RFC; utilizar apenas as pertinentes e formalmente confirmadas.
4. **LSA / LCCOMP / LRB** — laboratórios, mediante verificação do nome completo, sigla, autorização e vínculo. A sigla **LRB não está homologada**; não inferir seu significado.
5. **NSS** — identidade do núcleo, com nome por extenso e créditos institucionais.

A hierarquia é armazenada como `institutional.brand_entities`/`institutional.brand_assets` com `hierarchy_level`, `display_order` e `approval_reference`. Não substituir logotipo ausente por logotipo semelhante, e não publicar a sigla contestada como fato institucional. O componente de logos deverá incluir `alt` com nome da instituição e ser funcional com imagens desabilitadas.

# 4. Design tokens: tema claro (V1)

A paleta adota como base os tokens encontrados no frontend e no Manual v1.0. Eles são **tokens de implementação propostos**, não uma identidade visual oficial da UENF. Substituições institucionais posteriores exigem QA visual e contraste.

| Token semântico | Valor de referência | Uso |
|---|---|---|
| `--nss-blue` | `#174A7E` | marca tipográfica, ação primária, links |
| `--nss-blue-deep` | `#113B66` | títulos e links de alto contraste |
| `--nss-ink` | `#233E50` | texto principal |
| `--nss-muted` | `#475569` | texto auxiliar em fundo branco |
| `--nss-surface` | `#FFFFFF` | cartões e superfície |
| `--nss-background` | `#F3F6F8` | fundo de páginas |
| `--nss-border` | `#CBD8DF` | borda informativa, não único indicador |
| `--nss-focus` | `#C77C1B` | contorno de foco visível (≥3px) |
| `--nss-success-text` | `#14532D` | texto de confirmação |
| `--nss-success-bg` | `#DCFCE7` | fundo auxiliar de sucesso |
| `--nss-warning-text` | `#854D0E` | texto de alerta |
| `--nss-warning-bg` | `#FEF3C7` | fundo auxiliar de alerta |
| `--nss-error-text` | `#991B1B` | texto de erro |
| `--nss-error-bg` | `#FEE2E2` | fundo auxiliar de erro |
| `--nss-info-text` | `#113B66` | aviso epidemiológico |
| `--nss-info-bg` | `#DBEAFE` | fundo auxiliar de informação |
| `--nss-disabled` | `#64748B` | controles indisponíveis sempre com texto explicativo |

Os tokens acima exigem verificação automática de contraste para cada par efetivamente usado. Para texto normal, o alvo é **WCAG 2.2 AA, contraste ≥4,5:1**; para texto grande, ≥3:1; para elementos não textuais essenciais, ≥3:1. Não assumir conformidade apenas pela escolha da cor isolada. Reprovar componentes que indiquem sucesso, falha, espécie, doença ou gravidade exclusivamente pela cor: usar ícone, legenda, padrão e texto redundantes.

**Espaçamento**: escala base `4,8,12,16,24,32px`, com extensões `40,48,64px` somente para seções e grid; a revisão corrige a omissão do token `32px` no antigo Apêndice B do RFC. Fontes: pilha de interface de sistema ou IBM Plex Sans mediante licença/documentação; monospace para hashes e IDs; tamanho base ≥16px em formulários, legibilidade em 320px de viewport. CTA primário claramente distinto do secundário, sem transmitir privilégio por cor isolada.

## 4.1 Modo escuro

**Não faz parte da V1.** O checklist do antigo Manual v1.0 que exigia dark mode não se aplica ao gate de lançamento. O frontend deverá funcionar adequadamente em modo claro mesmo quando o sistema operacional solicitar dark mode, sem inversões automáticas que corrompam paletas, mapas ou logos oficiais. Um tema escuro só pode ser incluído na revisão futura que defina tokens completos, contraste, fundos e QA por componente.

# 5. Indicadores e mapas epidemiológicos

As séries humana e animal têm legendas próprias; nenhuma cor deve ser interpretada como diagnóstico de risco clínico sem nota metodológica. Para mapas quantitativos, usar escala sequencial com legenda textual, padrões para cobertura indisponível, categoria `UNKNOWN_TERRITORY` e informação de `sourceDataset`/`publicationFingerprint` visíveis. **Zero verdadeiro** é distinto de `UNAVAILABLE`, `PARTIAL`, `NO_DATA` e território não mapeado; um polígono de bairro não é fabricado a partir de nome textual.

No painel humano, declarar “notificações” e “território da unidade notificadora”; no painel animal, indicar “fonte histórica Gabriel” ou “notificações clínicas verificadas” sem soma entre as séries, e delimitar “residência animal verificada” quando houver bairro. Tabelas acessíveis são alternativa obrigatória a mapa puramente visual. Texto legível e teclado devem operar filtros e zoom sem interação exclusiva por arrastar.

# 6. Portal, conteúdo editorial e mídia

Home pública preserva navegação `Início / Notícias / Boletins / Sobre / Entrar`; dashboard protegido fica após login/grant. Posts mostram título, data, fonte, resumo, imagem com crédito, texto alternativo e situação de publicação; não exibir conteúdo em revisão a visitantes. O editor JSONB (`schemaVersion=1`) oferece blocos com legenda/fonte/alt obrigatórios quando aplicável, autosave somente conforme autorização, revisão com `If-Match`, comparação de versão e conflito claramente recuperável. Mídia despublicada sem outra referência ativa deve retornar `404` mesmo com URL antiga; `Cache-Control:no-store` para assets com retirada possível.

Documentos PDF e CSV têm cabeçalhos acessíveis, metadados de origem, data, status de cobertura, fonte e aviso de que **notificações não equivalem a casos confirmados**. Fotos de pessoas e nomes publicados exigem registro de fundamento e autorização quando cabível; usar fotografia de integrantes só quando fornecida legitimamente.

# 7. Página Sobre: equipe administrável por Chefe Geral

`/sobre` terá missão, escopo, hierarquia institucional, unidades e laboratórios com marcas homologadas, fontes de financiamento/vínculos quando comprovados, equipe do NSS, contatos e documentos institucionais. Cada cartão individual pode exibir **nome público, cargo/função, descrição curta e redes sociais**, com ordem definida pelo Chefe Geral, booleano `visible`, data de vigência, link validado (HTTPS) e possibilidade de ocultação sem excluir histórico. O Chefe Geral **edita e publica sozinho**; o Escritor-Chefe não recebe permissão implícita. Toda alteração registra versão, autor, data, diff e invalida `institutional_epoch` de cache público.

A equipe que deixa o núcleo não desaparece automaticamente do histórico institucional, mas a exibição pública deve poder ser revista por quem administra a página mediante critério e base legal. Links externos têm indicação acessível de nova aba quando aplicável e não recebem parâmetros de rastreamento invasivos. Caso o laboratório ainda não tenha autorização de uso da marca, registrar apenas nome institucional homologado — nunca substituir pelo brasão da UENF sem permissão.

# 8. Templates transacionais: 10 chaves, 9 grupos

Há **nove categorias funcionais de comunicação** e **dez templates técnicos** porque aprovação e recusa da solicitação têm chaves separadas. A tabela abaixo substitui o catálogo de oito do manual anterior. O sistema sempre oferece texto puro equivalente e layout HTML acessível.

| Chave normativa | Destinatário mínimo | Gatilho | Conteúdo essencial |
|---|---|---|---|
| `INVITATION` | Convidado de clínica ou usuário | convite emitido | tipo de convite, organização/clínica, link único, prazo 72h |
| `PASSWORD_RESET` | titular da conta | reset solicitado | link de uso único, prazo 1h, alerta se não solicitou |
| `VERIFY_EMAIL` | e-mail do solicitante | pedido público submetido | confirmação, prazo 24h, contato NSS |
| `ACCESS_REQUEST_RECEIVED` | destinatários configurados/chefes fallback | e-mail verificado | protocolo interno, resumo sem dados clínicos |
| `ACCESS_REQUEST_REVIEW` | solicitante | situação relevante | status/encaminhamento, sem revelar conta de terceiros |
| `ACCESS_APPROVED` | solicitante aprovado | decisão aprovada | primeiro acesso ou login, link 72h, papéis aprovados |
| `ACCESS_DENIED` | solicitante recusado | decisão recusada | status, motivo apropriado, canal para esclarecimento, intervalo 72h |
| `BULLETIN_PENDING_REVIEW` | aprovador habilitado | Gold elegível gera revisão | doença, competência, fingerprint, link autenticado |
| `FILE_RECEIVED` | representante municipal | recebimento consolidado | protocolo, município, status de validação |
| `VET_NOTIFICATION_RECEIPT` | **representante autor da notificação** | submissão veterinária aceita | protocolo, clínica e estado, **sem dados clínicos identificáveis** |

**Arquitetura do template:** cabeçalho com fallback tipográfico NSS/UENF ou logo aprovado, corpo principal com ação simples, links HTTPS no domínio institucional, texto alternativo para imagem de cabeçalho, rodapé de privacidade e identificação institucional **aprovada**. E-mails nunca incluem access JWT, hash, senha, planilha, anexo clínico, dados pessoais de tutor ou animal. Tokens de ação não aparecem em logs e têm URL com expiração de uso único. Nunca solicitar senha por resposta ao e-mail.

**Entrega SMTP:** a transação de negócio grava evento em `messaging.email_outbox`; worker tenta envio até 6 vezes sob backoff aproximado `1min,5min,15min,1h,4h,12h`; erros permanentes geram `FAILED_PERMANENT`, alerta e reenvio auditado por operador competente com conteúdo revisado. `SENT` indica aceitação do SMTP, **não confirmação de leitura ou entrega final**; evitar prometer “exatamente uma entrega” diante de queda após aceite remoto.

# 9. Páginas legais e acessibilidade institucional

As rotas públicas `/privacidade`, `/termos`, `/acessibilidade` e um canal de contato ao encarregado devem ser acessíveis sem login, com versão, data da atualização, escopo do controlador/operador definido em parecer, finalidade de cada dado tratado, canal de exercício de direitos e detalhes de cookies/sessões. A plataforma deve observar a **LGPD (Lei 13.709/2018)**, **LBI (Lei 13.146/2015)** e Marco Civil da Internet conforme enquadramento jurídico efetivo; o art. 15 do Marco Civil não implica automaticamente uma mesma obrigação de retenção para toda organização universitária. O CDC não é presumido aplicável a cada ação do núcleo sem parecer. O texto exato de rodapé e dos termos será homologado pelo setor competente.

Boas práticas técnicas: HTTPS válido com TLS, controle de sessão e CSRF conforme arquitetura, cabeçalhos e CSP testados, opção de acesso sem autoplay/vídeos piscantes, avisos claros em erros, formulários operáveis por teclado, preservação de foco e escalabilidade de zoom, avaliações axe/Playwright e inspeção manual de leitor de tela. O checklist não substitui revisão jurídica, DPO e validação institucional da Comunicação.

# 10. Checklist de homologação e critérios verificáveis

| Gate | Responsável | Evidência necessária |
|---|---|---|
| Marca ilustrada IA e licença/uso | Comunicação UENF | aprovação e proveniência; hash original |
| Logos UENF/PROPPG/PROEX/CCTA/CCT/CBB/LSA/LCCOMP/LRB | Comunicação e unidades | autorização de cada ativo, sigla LRB confirmada |
| Hierarquia e nomes da página Sobre | Coordenação NSS | cadastro aprovado, membros ativos, autorização de exposição |
| Política de privacidade/termos/rodapé | Jurídico/Encarregado | parecer e texto final versionado |
| Legendas de mapa e cobertura animal | Epidemiologia/Veterinária | dicionário de espécies/raça, origem, limites |
| E-mails e links de ação | Produto/SRE/Comunicação | testes HTML e plain-text, links, TTL, bounce e fallback |
| WCAG 2.2 AA | UX/QA | relatório automático/manual, desktop/mobile, 320px, teclado, foco |
| Marca e páginas não ficarem stale | QA | mudança de `institutional_epoch`, testes com Redis offline |
| Backup/restore da mídia institucional | TI | manifesto SHA-256 e restauração em host distinto |

**Fontes normativas e de contexto:** Manual de Marca NSS v1.0 (20/11/2026), RFC-NSS-001 v1.4, RFC-NSS-001 v1.5; [LGPD](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709compilado.htm); [LBI](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2015/lei/l13146.htm); [Marco Civil](https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2014/lei/l12965.htm); [WCAG 2.2](https://www.w3.org/TR/WCAG22/). Revisão do enquadramento jurídico é requisito de governança, não conclusão jurídica deste manual.
