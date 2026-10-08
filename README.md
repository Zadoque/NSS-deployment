# Núcleo de Situação de Saúde - Deployment e Arquitetura

## Esta branch: somente front estático + Caddy

**`feat/frontend-static-only` substitui o Compose desta branch por dois serviços.**
Não inicia Java, PostgreSQL, pipeline ou observabilidade. A arquitetura integrada
documentada abaixo permanece como referência histórica, não como comando de operação
desta branch. Consulte [o procedimento de publicação estática](runbooks/frontend-static.md).

Use o front da branch `feat/prod-mock-real-snapshot` (ou uma imagem construída
a partir dela). O modo `prod-mock` contém um snapshot real agregado dos quatro
municípios, incluindo distritos de Campos e bairros da sede; não são dados sintéticos.


Este repositório é a **fonte normativa de integração e deployment** do sistema do Núcleo de Situação de Saúde (NSS) da Universidade Estadual do Norte Fluminense Darcy Ribeiro (UENF). Ele registra o escopo aprovado da NSS 1.0, os contratos entre componentes, a arquitetura de execução e os runbooks necessários para colocar a primeira versão integrada em funcionamento.

O NSS **não é um monorepo**. Frontend, backend Java, pipeline Python e configuração NixOS permanecem versionados em repositórios independentes. Este repositório não concentra código de negócio; ele define como os componentes devem convergir para formar um único sistema.

## Release-alvo

A release integrada alvo desta documentação é a **NSS 1.0**, com Frontend V2, prevista inicialmente para homologação em **02/10/2026**.

A NSS 1.0 responde, com dados do SINAN/PySUS, perguntas sobre **notificações** de Dengue, Febre Maculosa e Toxoplasmose, dentro do recorte aprovado. O termo "casos" só poderá substituir "notificações" quando a regra epidemiológica de classificação estiver formalmente validada para cada agravo.

### Escopo funcional congelado

- municípios: Campos dos Goytacazes, São João da Barra, Macaé e Itaperuna;
- perspectiva geográfica da V1.0: **local da notificação**, não residência do paciente;
- detalhamento intramunicipal apenas para Campos dos Goytacazes;
- hierarquia em Campos: município -> distrito -> bairro/localidade da **unidade notificadora**;
- período oficial: ano e mês derivados de `DT_NOTIFIC`;
- sexo: Todos, Masculino e Feminino; valores ignorados continuam preservados nos dados;
- faixa etária: `<1`, `1-4`, `5-9`, `10-14`, `15-19`, `20-39`, `40-59`, `60-64`, `65-69`, `70-74`, `75-79`, `80+`;
- múltiplas faixas etárias simultâneas ficam fora da V1.0;
- bairro de residência fica para versão futura dependente da parceria com o CIEVS;
- CEP e identificadores pessoais diretos não são necessários para esta versão e não devem ser solicitados para esse objetivo;
- o CIDAC é apenas referência conceitual da hierarquia distrito -> bairro/localidade; os GeoJSON continuam sendo produzidos por Python para o frontend;
- localização pública de UBS no mapa é um artefato de visualização client-side e não faz parte do grão analítico da Gold Serving.

## Repositórios

| Componente | Repositório | Responsabilidade |
|---|---|---|
| Frontend | `Zadoque/nss-front-end` | React/TypeScript, login, mapas, filtros, acessibilidade e consumo da API Java |
| Backend Java | `ArtursPereira/Site-Sala-de-Situa-o-de-Saude-Java` | Spring Boot, autenticação, autorização, sessão, API REST e leitura do PostgreSQL |
| Pipeline | `Zadoque/NSS-pipeline` | PySUS/SINAN, CNES, Bronze -> Silver -> Gold, validação e carga do schema `analytics` |
| Deployment | `Zadoque/NSS-deployment` | Contratos, arquitetura integrada, Compose, Caddy, runbooks e documentação normativa |
| Host NixOS | `Zadoque/nss-NixOS-Configuration` | Configuração declarativa do servidor, firewall, SSH, Docker, ngrok temporário e WireGuard definitivo |

O repositório Java poderá permanecer no repositório atual com acesso de colaborador ou ser trabalhado por fork/PR, sem alterar o contrato de integração documentado aqui.

## Arquitetura da NSS 1.0

```text
                         INTERNET
                            |
                    ngrok HTTPS (temporário)
                            |
                            v
                         Caddy
                       /       \
                      v         v
                 Frontend     /api/*
                                |
                                v
                          Java/Spring Boot
                                |
                                v
                           PostgreSQL
                         /             \
                        v               v
                tabelas de app      analytics.*
                  Java/Flyway      Python/Alembic
                                       ^
                                       |
                             Gold Serving V1
                                       ^
                                       |
PySUS/SINAN -> Bronze -> Silver -----+----- Gold Ad Hoc
                         ^
                         |
                       CNES
```

O frontend nunca acessa diretamente o PostgreSQL ou os Parquets. A API Java é o único caminho síncrono oficial da aplicação. O pipeline roda fora do caminho crítico de consulta e publica dados já processados.

## Autenticação da V1.0

- homepage pública;
- dashboard `/mapa` protegido;
- login por e-mail e senha;
- senha armazenada com Argon2;
- access token JWT curto;
- refresh token opaco, rotacionado e armazenado no navegador apenas como cookie `HttpOnly`, `Secure` e `SameSite=Strict`;
- logout revoga o refresh token;
- auto-registro público desabilitado;
- CRUD de usuários não é uma API comum do dashboard na V1.0;
- frontend e Java ficam sob a mesma origem via Caddy, reduzindo a superfície de CORS e cookies cross-site.

O contrato completo está em [`contracts/auth-v1.md`](contracts/auth-v1.md).

## Dados e Gold Serving

### Pré-condição territorial e recuperação

O CNES deve estar no **mesmo volume `pipeline_data`** da carga SINAN. O diretório
`data/` do repositório do pipeline não é compartilhado automaticamente com este
Compose. Antes de publicar a Gold Serving, execute:

```sh
docker compose --profile jobs run --rm --entrypoint python pipeline -m app.pipeline.run_cnes
```

A publicação territorial sem CNES é bloqueada. Latitude/longitude permanecem na
Silver para classificar a unidade notificadora; valores ausentes/ inválidos não
eliminam notificações. O mapeamento não representa endereço de residência.

Para reconstruir um recorte sem baixar novamente o SINAN, use o módulo
`app.pipeline.reprocess_serving` com `--silver CAMINHO_NO_VOLUME`,
`--database situacao_saude` e `--expected-total TOTAL_VALIDADO`. O padrão é simulação;
`--publish` substitui atomicamente o recorte no PostgreSQL e registra a nova Gold
Serving. Faça backup antes. A data original da Silver é preservada e conferida
contra o histórico de publicação. Falha de escrita do Parquet após o commit exige
reconciliação/reexecução; PostgreSQL e filesystem não compartilham uma transação.

Auditoria somente leitura:

```sh
docker compose --profile jobs run --rm -T --entrypoint python pipeline - < e2e/audit_gold.py
```

O resultado precisa apresentar `passed: true`, incluindo igualdade de todas as
dimensões (não apenas totais). Ver [relatório da correção territorial](e2e/TERRITORY_REPAIR.md).

A pipeline passa a distinguir formalmente:

```text
Silver
  |-- Gold Ad Hoc       -> exploração, auditoria e debugging
  `-- Gold Serving V1   -> contrato fixo aceito pelo loader/PostgreSQL
```

O menor grão analítico necessário à NSS 1.0 é composto por doença, ano, mês, município da notificação, distrito/bairro da unidade notificadora, sexo e faixa etária. As agregações solicitadas pela interface são executadas no PostgreSQL/Java por `SUM` e `GROUP BY`; o frontend não soma dados epidemiológicos.

O contrato está em [`contracts/serving-v1.md`](contracts/serving-v1.md).

## Observabilidade

A V1.0 incorpora uma auditoria mínima em Grafana, mantendo a capacidade de comparar quatro checkpoints:

1. Bronze - quantidade recebida;
2. Silver - quantidade após limpeza/deduplicação;
3. Gold - soma da métrica publicada;
4. PostgreSQL - soma equivalente após a carga.

O objetivo imediato é provar conservação/reconciliação entre camadas. Dashboards históricos, alertas avançados, DuckDB e observabilidade distribuída ficam para evoluções posteriores.

## Deployment temporário e definitivo

### Bancos PostgreSQL

O Compose integrado usa dois bancos no mesmo servidor PostgreSQL:

- `POSTGRES_DB` (por padrão `situacao_saude`): banco analítico da pipeline, lido pelo Java através do datasource somente leitura;
- `POSTGRES_APP_DB` (por padrão `nss`): banco operacional do Java, usado por usuários e Flyway.

O serviço único `db-provision` é idempotente e deve sempre rodar antes do Java ou
da pipeline. Ele cria/atualiza papéis distintos: `NSS_APP_MIGRATOR_USER` é dono do
schema operacional e executa Flyway; `NSS_APP_RUNTIME_USER` só usa tabelas; a
pipeline escreve como `NSS_ANALYTICS_WRITER_USER`; Java lê analytics como
`NSS_ANALYTICS_READER_USER`; e `NSS_BACKUP_USER` apenas faz backup. Nunca aponte
o Flyway para `situacao_saude` nem reutilize a credencial administrativa em uma
aplicação.

Em um volume PostgreSQL já existente, preencha as seis credenciais novas no
`.env` e execute `docker compose up db-provision`. Não use `docker compose down
-v`: isso apagaria o volume.

### Imagens da integração

Construa as imagens a partir dos repositórios independentes, mantendo o frontend em modo same-origin:

```bash
docker build --build-arg VITE_USE_MOCKS=false --build-arg VITE_API_BASE_URL= \
  -t nss-frontend:local ../NSS-front-end
docker build -t nss-java:local ../Site-Sala-de-Situa-o-de-Saude-Java
docker build -t nss-pipeline:local ../NSS-pipeline
```

Preencha um `.env` local a partir de `.env.example`, sem versionar segredos, e valide:

```bash
docker compose config
docker compose up -d db-provision java frontend caddy
curl --fail http://127.0.0.1:${NSS_HTTP_PORT:-8080}/actuator/health
```

### Observabilidade local

O perfil `monitoring` mantém Prometheus, Pushgateway, node-exporter e Grafana
fora da internet: Prometheus e Grafana escutam somente em `127.0.0.1`, e
Pushgateway/node-exporter só existem na rede interna do Compose. Suba-o com:

```bash
docker compose --profile monitoring up -d prometheus pushgateway node-exporter grafana
curl --fail http://127.0.0.1:9090/-/ready
curl --fail http://127.0.0.1:3000/api/health
```

O datasource Prometheus é provisionado automaticamente no Grafana. A API expõe
`/actuator/prometheus` exclusivamente à rede interna; Caddy não o publica. A
pipeline publica cardinalidade e perdas de Bronze/Silver/Gold somente quando
`PROMETHEUS_PUSHGATEWAY_URL=http://pushgateway:9091` estiver configurado.

### Bootstrap temporário

```text
Web:  Internet -> ngrok HTTPS -> Caddy -> Front/Java
Admin: Internet -> ngrok TCP -> SSH key-only
```

O ngrok existe apenas enquanto a GINFO não libera a conectividade institucional necessária. PostgreSQL e Java não são publicados diretamente.

### Estado definitivo

```text
Web:   Internet -> domínio institucional -> Caddy -> NSS
Admin: WireGuard -> SSH key-only
```

A configuração do host vive em `nss-NixOS-Configuration`. Este repositório documenta somente o contrato entre o host e a aplicação.

## Artefatos operacionais

- [`compose.yaml`](compose.yaml): stack integrada mínima;
- [`caddy/Caddyfile`](caddy/Caddyfile): entrada HTTP única da aplicação;
- [`.env.example`](.env.example): variáveis esperadas, sem segredos reais;
- [`contracts/`](contracts/): contratos da API, autenticação e Gold Serving;
- [`runbooks/`](runbooks/): bootstrap ngrok, deployment e rollback;
- [`documentacao/`](documentacao/): arquitetura detalhada em LaTeX/PDF;
- [`perguntas/`](perguntas/): registro das perguntas de negócio, decisões já tomadas e itens futuros.

## Definition of Done - NSS 1.0

A release só pode ser declarada pronta quando, no mínimo:

- login, refresh e logout funcionarem;
- `/mapa` exigir autenticação;
- pipeline real produzir a Gold Serving V1;
- PostgreSQL receber somente artefato Serving compatível;
- Gold e PostgreSQL reconciliarem seus totais;
- Java responder os endpoints analíticos contratados;
- Frontend consumir a API Java real e não realizar somas epidemiológicas;
- filtros de ano, mês, sexo e faixa etária funcionarem;
- Campos permitir drill-down distrito -> bairro/localidade da unidade notificadora;
- ausência de cobertura não for exibida como zero;
- Caddy for o único ponto de entrada HTTP da stack;
- PostgreSQL e Java não forem expostos diretamente à Internet;
- HTTPS temporário via ngrok funcionar;
- SSH remoto usar somente chave pública;
- um fluxo E2E validar login -> consulta -> refresh -> logout.

Os gates completos da release estão em `documentacao/Section-10-NSS-1-0-Escopo-e-Plano-de-Entrega.tex` e em [`runbooks/deploy-v1.md`](runbooks/deploy-v1.md).

## Princípios que continuam válidos

1. Componentes permanecem em repositórios independentes.
2. Java é a fronteira síncrona oficial do frontend.
3. Python prepara/publica dados; não atende consultas do usuário.
4. PostgreSQL é a persistência compartilhada, com responsabilidades separadas entre Flyway e Alembic.
5. Parquet continua sendo parte da rastreabilidade da pipeline.
6. Secrets nunca são versionados.
7. Zero, ausência de registro e ausência de cobertura são estados diferentes.
8. Dados restritos futuros do CIEVS deverão seguir minimização e isolamento próprios; esse problema não é antecipado artificialmente na V1.0.
