# Validação nacional de bairros — 5.571 municípios

**Data:** 15/11/2026  
**Recorte homologado:** DENG/2026, publicação atual do PostgreSQL  
**Suíte:** Playwright no Chromium do Nix, API real do Compose

## Resultado

| Indicador | Resultado |
|---|---:|
| Municípios catalogados | 5.571 |
| Testes Playwright executados | 5.571 |
| Testes aprovados | 5.571 |
| Testes falhos | 0 |
| Municípios com notificações ainda sem vinculação territorial | 115 |
| Notificações ainda sem vinculação | 1.000 |
| Unidades notificadoras sem registro no lote CNES atual | 150 |

Cada teste consultou, contra a API real, os endpoints de distritos e bairros do município. O banco utilizado foi o PostgreSQL homologado no Compose; não foram usados mocks para essa suíte.

## Correção aplicada

Os registros `NOTIFICATION_NEIGHBORHOOD_NAME_ONLY` já possuíam município, distrito e nome de bairro CNES, mas o filtro Java de distritos os tratava como não mapeados por aceitar somente `NOTIFICATION_DISTRICT_ONLY` e `NOTIFICATION_NEIGHBORHOOD`. O predicado foi corrigido para incluir o status nominal.

Também foram reduzidos o raio, a opacidade e a espessura do contorno dos pontos vermelhos na visão de bairros. A visão de distritos não foi alterada.

## Caso Itapemirim

Após a correção, o município `3202801 — Itapemirim/ES` retornou:

- 390 notificações totais;
- 390 notificações mapeadas;
- 0 notificações não mapeadas;
- cobertura `AVAILABLE`.

Esse era um falso não mapeado de cobertura: as notificações estavam vinculadas por bairro nominal CNES, mas não eram contabilizadas no nível de distrito.

## Municípios ainda não mapeados

Restaram 115 municípios e 1.000 notificações com status `UNMAPPED_NOTIFICATION_UNIT`. A análise do lote CNES confirmou que os 150 códigos de unidade notificadora envolvidos não existem no lote CNES publicado `20261115T042236Z`. Portanto, o motivo comum é:

> A unidade notificadora do SINAN não está presente no cadastro CNES utilizado na publicação atual; sem o cadastro da unidade não há coordenada, endereço ou bairro confiável para vincular.

A lista completa, com código IBGE, município, UF, quantidade de notificações, quantidade de unidades e motivo, está em [municipios-sem-bairro-DENG-2026-11-15.csv](../reports/municipios-sem-bairro-DENG-2026-11-15.csv).

Distribuição dos municípios restantes por UF:

| UF | Municípios | Notificações |
|---|---:|---:|
| GO | 11 | 279 |
| MG | 22 | 203 |
| BA | 17 | 131 |
| PA | 3 | 72 |
| MT | 6 | 58 |
| RJ | 4 | 50 |
| ES | 3 | 49 |
| SP | 12 | 43 |
| MA | 7 | 35 |
| PR | 9 | 28 |
| PE | 10 | 19 |
| MS | 2 | 10 |
| CE | 2 | 9 |
| RN | 1 | 5 |
| RS | 3 | 4 |
| PI | 1 | 3 |
| RO | 1 | 1 |
| SE | 1 | 1 |

## Verificações adicionais

- Java: suíte completa com 113 testes aprovados.
- Front-end: build e lint aprovados.
- Compose: PostgreSQL, Redis e Java saudáveis após a recriação das imagens.
- Playwright nacional: 5.571/5.571 aprovados.
- A lista não mapeada foi conferida diretamente no PostgreSQL e cruzada com o lote CNES reclassificado; nenhum dos 150 códigos ausentes foi encontrado no lote atual.

## Próximo dado necessário para resolver os 115 municípios

É necessário disponibilizar um lote CNES que contenha essas unidades ou uma fonte confiável de endereço/coordenadas para os códigos de unidade do SINAN. Tentar inferir bairro apenas pelo município produziria uma vinculação incorreta.

