# Núcleo de Situação de Saúde - Deployment e Arquitetura

Este repositório é a **fonte normativa de integração e deployment** do sistema do Núcleo de Situação de Saúde (NSS) da Universidade Estadual do Norte Fluminense Darcy Ribeiro (UENF). Ele registra o escopo aprovado da NSS 1.0, os contratos entre componentes, a arquitetura de execução e os runbooks necessários para colocar a primeira versão integrada em funcionamento.

O NSS **não é um monorepo**. Frontend, backend Java, pipeline Python e configuração NixOS permanecem versionados em repositórios independentes. Este repositório não concentra código de negócio; ele define como os componentes devem convergir para formar um único sistema.

## Release-alvo

A release integrada alvo desta documentação é a **NSS 1.0**, com Frontend V2, prevista inicialmente para homologação em **02/10/2026**.

A NSS 1.0 responde, com dados do SINAN/PySUS, perguntas sobre **notificações** de Dengue, Febre Maculosa e Toxoplasmose, dentro do recorte aprovado. O termo "casos" só poderá substituir "notificações" quando a regra epidemiológica de classificação estiver formalmente validada para cada agravo.

### Escopo funcional congelado

- municípios: cobertura nacional por UF e município; a validação obrigatória de referência inclui os 92 municípios do Estado do Rio de Janeiro;
- perspectiva geográfica da V1.0: **local da notificação**, não residência do paciente;
- detalhamento intramunicipal disponível para os municípios com território resolvido, com validação obrigatória de todos os distritos/bairros dos 92 municípios do Rio de Janeiro;
- hierarquia nacional: região -> UF -> município -> distrito/bairro/localidade da **unidade notificadora**;
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

Além do fato analítico, a pipeline mantém `analytics.pipeline_current_publication`, uma tabela de controle com a chave doença/ano/município, `batch_id`, `source_extracted_timestamp` e `added_at`. O Java usa essa tabela por igualdade com o lote publicado; assim, consultas e metadados exibidos no frontend pertencem exatamente à publicação corrente, sem depender de `MAX()`.

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

No Compose integrado, o pipeline envia métricas ao Pushgateway, o Prometheus faz a retenção/consulta e o Grafana consome o Prometheus por datasource provisionado. Grafana, Prometheus e Pushgateway ficam presos ao loopback do host; não são pontos públicos do Caddy.

## Deployment temporário e definitivo

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

## Subida completa da aplicação

Esta seção é o procedimento operacional para subir a NSS do zero no host de
deployment. Execute os comandos a partir de `NSS-deployment`. Os quatro
repositórios devem estar lado a lado:

```text
NSS-deployment/
NSS-pipeline/
NSS-front-end/
Site-Sala-de-Situa-o-de-Saude-Java/
```

### 1. Pré-requisitos

Instale Docker Engine com Docker Compose v2, Git, `curl` e ngrok. Confirme:

```bash
docker version
docker compose version
git --version
curl --version
ngrok version
```

Use a branch `main` dos repositórios e confira as imagens antes de publicar:

```bash
for repo in NSS-deployment NSS-pipeline NSS-front-end Site-Sala-de-Situa-o-de-Saude-Java; do
  git -C "../$repo" switch main
  git -C "../$repo" pull --ff-only
done
```

### 2. Configurar o ambiente e os segredos

```bash
cp .env.example .env
chmod 600 .env
```

Edite `.env` e substitua todos os valores obrigatórios. `JWT_SECRET` deve ser
um segredo aleatório com pelo menos 32 bytes. `POSTGRES_PASSWORD`,
`GRAFANA_ADMIN_PASSWORD` e `BOOTSTRAP_ADMIN_PASSWORD` nunca devem ser
versionados nem colados em comandos gravados no histórico do shell.

Para gerar um segredo JWT:

```bash
openssl rand -base64 48
```

O `BOOTSTRAP_ADMIN_EMAIL` e o `BOOTSTRAP_ADMIN_PASSWORD` criam o administrador
inicial do Java. Depois do primeiro login, remova esses valores do `.env` e
recrie o serviço Java para que a credencial de bootstrap não permaneça na
configuração operacional.

### 3. Construir as imagens

O frontend precisa ser construído com `VITE_USE_MOCKS=false` e com API relativa
(`VITE_API_BASE_URL=`), pois o Caddy encaminha `/api/*` para o Java:

```bash
docker build -t nss-java:local ../Site-Sala-de-Situa-o-de-Saude-Java
docker build \
  --build-arg VITE_USE_MOCKS=false \
  --build-arg VITE_API_BASE_URL= \
  -t nss-frontend:local ../NSS-front-end
docker build -t nss-pipeline:local ../NSS-pipeline
```

Em uma release imutável, prefira tags com o SHA dos commits e configure as
variáveis `NSS_JAVA_IMAGE`, `NSS_FRONTEND_IMAGE` e `NSS_PIPELINE_IMAGE` no
`.env`. Nunca use `latest` para as imagens da aplicação em produção.

### 4. Subir o PostgreSQL e aplicar o schema Java

```bash
docker compose up -d db
docker compose ps db
```

O Java aplica o Flyway na inicialização. O banco precisa estar saudável antes
de iniciar o Java:

```bash
docker compose up -d java
docker compose logs --tail=100 java
```

O Compose do deployment usa o mesmo PostgreSQL para as tabelas operacionais
do Java e o schema `analytics` publicado pela pipeline. O Flyway administra o
schema do Java; o Alembic da pipeline administra o schema `analytics`.

### 5. Aplicar o schema analítico e carregar dados

O serviço `pipeline` pertence ao profile `jobs`, portanto é um job sob demanda
e não um servidor web. Execute a migration da pipeline com o próprio checkout
da pipeline antes da carga:

```bash
docker compose run --rm migrate
```

Depois execute a carga usando a imagem construída no deployment. Para uma
primeira validação:

```bash
docker compose --profile jobs run --rm pipeline \
  --disease DENG --year 2026
```

Repita para cada doença/ano liberado. A carga só deve ser promovida depois de
validar o manifesto, o batch CNES/IBGE e a reconciliação Gold = PostgreSQL.
Consulte o README do `NSS-pipeline` para carga nacional, CNES, escopo IBGE e
opções de atualização SINAN.

### 6. Subir frontend, Caddy e Grafana

```bash
docker compose up -d frontend caddy grafana
docker compose ps
```

O único ponto HTTP da aplicação é:

```text
http://127.0.0.1:8080
```

O Caddy envia `/api/*` para `java:8080` e o restante para `frontend:80`.
PostgreSQL e Java não possuem `ports` publicados. Grafana fica disponível
somente em `127.0.0.1:3000` e não deve ser exposto pelo ngrok da aplicação.

Valide localmente:

```bash
curl -fsSI http://127.0.0.1:8080/
curl -fsS http://127.0.0.1:3000/api/health
docker compose ps
```

### 7. Configurar CORS e ngrok

O frontend servido pelo Caddy usa a mesma origem e normalmente não exige CORS
para chamar `/api`. Quando a URL HTTPS do ngrok for usada, configure-a também
como origem autorizada no Java:

```bash
./scripts/configure-ngrok.sh https://seu-endereco.ngrok-free.dev
```

O script valida o formato HTTPS, grava `CORS_ALLOWED_ORIGINS`, força
`NSS_HTTP_PORT=8080`, valida o Compose e recria somente `java` e `caddy`. Ele
não abre portas adicionais e não publica Java, banco ou Grafana.

Em outro terminal, mantendo o script do ngrok em execução:

```bash
ngrok http http://127.0.0.1:8080
```

Se o endereço for aleatório, execute novamente o script com o novo endereço e
aguarde a recriação do Java. O endereço compartilhado deve ser o HTTPS do
ngrok, nunca `:8080`, `:3000`, `:5432` ou a porta interna `8080` do Java.

### 8. Smoke test completo

```bash
PUBLIC_URL=https://seu-endereco.ngrok-free.dev
curl -fsSI "$PUBLIC_URL/"
curl -fsSI "$PUBLIC_URL/mapa"
```

No navegador, valide nesta ordem:

```text
Home pública
  -> /mapa redireciona para login
  -> login com o administrador bootstrap
  -> consulta real no mapa
  -> refresh da sessão
  -> logout
  -> /mapa volta a exigir autenticação
```

Para diagnosticar falhas:

```bash
docker compose logs --tail=200 java frontend caddy grafana
docker compose ps
ss -lntup
```

O `ss` deve mostrar apenas Caddy em `127.0.0.1:8080` e Grafana em
`127.0.0.1:3000`; não deve mostrar Java ou PostgreSQL publicados em interfaces
externas.

### 9. Parar e atualizar

Para reiniciar sem remover dados:

```bash
docker compose restart java frontend caddy grafana
```

Para atualizar uma imagem, reconstrua-a, recrie somente o serviço e repita os
smoke tests:

```bash
docker build -t nss-java:local ../Site-Sala-de-Situa-o-de-Saude-Java
docker compose up -d --force-recreate java
```

Não use `docker compose down -v` em operação normal: isso remove volumes
persistentes do PostgreSQL, Grafana e Caddy. O procedimento de rollback está
em [`runbooks/rollback-v1.md`](runbooks/rollback-v1.md).

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
