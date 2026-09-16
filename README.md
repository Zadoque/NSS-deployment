# Núcleo de Situação de Saúde — Deployment e Arquitetura

Este repositório centraliza a **documentação arquitetural** e os artefatos de **integração, execução e deployment** do sistema do Núcleo de Situação de Saúde (NSS) da Universidade Estadual do Norte Fluminense Darcy Ribeiro (UENF).

O NSS é mantido em repositórios independentes. **Não é um monorepo.** A separação existe para permitir evolução, testes, versionamento e deployment independentes de cada componente.

## Repositórios de aplicação

| Componente | Repositório | Responsabilidade principal |
|---|---|---|
| Front-end | `Zadoque/nss-front-end` | Interface web, homepage institucional, mapa geográfico, filtros e experiência de consulta |
| Java | `ArtursPereira/Site-Sala-de-Situa-o-de-Saude-Java` | API principal, autenticação, autorização, regras de negócio e PostgreSQL |
| Python / Pipeline | `Zadoque/Nucleo-de-Situacao-De-Saude` | Ingestão PySUS/SINAN, Bronze → Silver → Gold e preparação dos dados |
| Deployment | `Zadoque/nss-deployment` | Arquitetura, integração, decisões e documentação operacional |

## Arquitetura-alvo

```text
                    ┌──────────────────────┐
                    │      Front-end       │
                    │ React + TypeScript   │
                    │ Vite + TanStack      │
                    └──────────┬───────────┘
                               │ HTTPS
                               ▼
                    ┌──────────────────────┐
                    │   Java / Spring Boot │
                    │ REST API             │
                    │ Auth / Business      │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │      PostgreSQL      │
                    └──────────▲───────────┘
                               │
                          batch / ETL
                               │
                    ┌──────────┴───────────┐
                    │   Python Pipeline    │
                    │ PySUS / SINAN        │
                    │ Bronze→Silver→Gold   │
                    └──────────┬───────────┘
                               │
                               ▼
                         DATASUS / PySUS
```

O Python **não deve fazer parte do caminho síncrono definitivo de consulta do usuário**. A função principal da pipeline é manter dados processados, auditáveis e prontos para persistência/consumo.

## Estado da V1 geográfica do front-end

A V1 está sendo desenvolvida em `Zadoque/nss-front-end`, branch `feat/v1-geographic-dashboard`.

O que já existe nessa V1:

- aplicação React + TypeScript com Vite;
- TanStack Query para o ciclo de consulta;
- mapa com `react-simple-maps`;
- navegação geográfica progressiva **Região → Estado → Município**;
- recorte inicial do Sudeste, Rio de Janeiro e municípios cobertos na V1;
- filtros de doença, ano e mês;
- painel desktop e drawer de filtros para telas menores;
- estados explícitos de carregamento, erro, ausência de registros e cobertura parcial;
- camada `EpidemiologyDataSource`, permitindo trocar mock/API sem acoplar os componentes visuais ao transporte HTTP.

### Ampliação da V1 em andamento

O escopo da V1 passa também a incluir:

1. **Homepage institucional antes do mapa**, apresentando o que é o NSS, seus objetivos em saúde humana e animal, estágio inicial da iniciativa, parceria em estabelecimento com a Prefeitura de Campos dos Goytacazes e localização no Hospital Veterinário Darcy Ribeiro/UENF, Av. Alberto Lamego, 3000.
2. **Acesso claro da homepage ao mapa interativo**.
3. **Seletor geográfico sincronizado com o mapa** para Região/Estado/Município, especialmente importante em telas abaixo de `md`, evitando depender exclusivamente do toque em geometrias pequenas.
4. Manutenção do princípio **mobile first** e de acessibilidade por teclado/leitores de tela.

O seletor geográfico deve compartilhar o mesmo estado de navegação do mapa; não deve existir uma segunda seleção independente capaz de divergir do que está visível no mapa.

## Situação transitória de integração

A branch da V1 possui uma abstração de data source e contrato HTTP próprio para permitir desenvolvimento e demonstração antes de toda a arquitetura-alvo estar integrada. Essa situação é **transitória**.

A arquitetura definitiva continua sendo:

1. frontend envia consultas à API Java;
2. Java aplica regras de negócio e consulta PostgreSQL;
3. pipeline Python atualiza os dados a partir do PySUS;
4. PostgreSQL contém os dados consolidados usados na consulta síncrona.

Portanto, qualquer adaptador HTTP temporário usado para validar a V1 não deve ser interpretado como mudança dessa decisão arquitetural.

## Fonte de dados atual

No estágio atual, a fonte efetivamente incorporada à pipeline é o **SINAN via PySUS**. O PySUS também disponibiliza outros sistemas do SUS, que serão avaliados conforme as perguntas que o Núcleo decidir responder: SIM, SINASC, SIH, SIA, PNI, CNES, CIHA, IBGE e temas OpenDataSUS.

A decisão sobre quais novas fontes incorporar deve partir de **perguntas de negócio e vigilância**, e não apenas da disponibilidade técnica dos dados. O material para essa decisão está em `perguntas/main.tex`.

## Papel deste repositório

Este repositório **não contém código de negócio da aplicação**. Ele é o ponto de integração e documentação do sistema, registrando:

- decisões arquiteturais;
- responsabilidades entre repositórios;
- contratos de integração;
- ambientes de execução/deployment;
- evolução da V1;
- decisões sobre dados e perguntas que a aplicação precisa responder.

## Documentação completa

A documentação técnica detalhada está em [`documentacao/`](documentacao/). Para compilar em NixOS:

```bash
cd documentacao
nix develop
make pdf
```

ou:

```bash
cd documentacao
nix run .#pdf
```

## Princípios arquiteturais

1. Cada componente de aplicação possui seu próprio repositório.
2. O projeto não deve voltar a ser documentado como monorepo.
3. O frontend é responsável por apresentação, interação, acessibilidade e visualização.
4. A API Java é o ponto de entrada definitivo para as consultas da aplicação.
5. O PostgreSQL é a persistência compartilhada dos dados consolidados.
6. A pipeline Python mantém Bronze, Silver e Gold para rastreabilidade e reprocessamento.
7. Novos datasets devem ser incorporados para responder perguntas aprovadas pelo Núcleo.
8. Contratos de dados e APIs devem ser versionados e testáveis.
9. O ambiente de integração pode orquestrar imagens independentes dos componentes via Docker Compose.

## Equipe atual

O desenvolvimento atual é realizado por três estagiários:

- **Zadoque Carneiro:** arquitetura e documentação;
- **Artur Pereira:** Java + Spring Boot;
- **Gabriel Costa:** Python + pipeline de dados.

A separação por repositórios foi mantida deliberadamente para permitir que a arquitetura cresça sem exigir uma migração posterior de monorepo.
