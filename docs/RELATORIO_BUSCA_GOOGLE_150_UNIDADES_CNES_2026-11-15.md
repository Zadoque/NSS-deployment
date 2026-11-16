# Busca Google das unidades CNES não vinculadas

**Data:** 15/11/2026  
**Recorte:** 150 códigos de unidade presentes nas notificações DENG/2026 com status `UNMAPPED_NOTIFICATION_UNIT`.

## Resultado

| Classificação | Quantidade |
|---|---:|
| Códigos analisados | 150 |
| Códigos pesquisáveis | 149 |
| `0000000` — sentinela “não identificado” | 1 |
| Página direta de estabelecimento encontrada | 13 |
| Sem página direta inequívoca | 136 |

Foram feitas buscas individuais no Google, usando o código entre aspas e o contexto CNES Brasil. Considerei “encontrada” somente quando apareceu uma página dedicada ao estabelecimento contendo o mesmo código CNES. Menções em listagens históricas, páginas de especialidades, equipamentos ou processos foram classificadas como insuficientes para confirmar a unidade atual.

Exemplos de páginas diretas encontradas:

- [CNES 2039702 — Santa Casa de Atibaia](https://hospitaleclinicas.com.br/cnes/2039702/santa-casa-de-atibaia)
- [CNES 2097796 — Vigilância Epidemiológica Municipal de Valinhos](https://hospitaleclinicas.com.br/cnes/2097796/vigilancia-epidemiologica-municipal-de-valinhos)
- [CNES 2136953 — Hemolab](https://hospitaleclinicas.com.br/cnes/2136953/hemolab)
- [CNES 2190737 — Unidade de Vigilância em Saúde](https://hospitaleclinicas.com.br/cnes/2190737/unidade-de-vigilancia-em-saude)

O próprio Portal CNES informa que a consulta oficial aceita o número CNES e pode mostrar a ficha detalhada do estabelecimento. [Documentação do Portal CNES/DATASUS](https://wiki.saude.gov.br/cnes/index.php/Portal_CNES)

## Códigos com página direta encontrada

`2039702`, `2097796`, `2136953`, `2190737`, `2456893`, `2510677`, `2573660`, `3575586`, `3828867`, `4048482`, `5784999`, `6607624`, `6774911`.

## Códigos sem página direta inequívoca

Os 136 códigos restantes estão listados individualmente no arquivo CSV. O resultado “sem página direta” não prova que a unidade nunca existiu; indica apenas que o código não foi localizado em uma página pública indexada que permita confirmar nome, município e endereço da unidade.

## Implicação para a vinculação

A busca web não é evidência suficiente para preencher automaticamente coordenadas ou bairro. Mesmo para os 13 códigos encontrados, a aplicação só deve ser corrigida após validar a ficha oficial atual do CNES e confirmar que o município, endereço e situação cadastral correspondem à unidade notificadora do SINAN.

Lista completa por código e classificação: [google-cnes-search-2026-11-15.csv](../reports/google-cnes-search-2026-11-15.csv).

