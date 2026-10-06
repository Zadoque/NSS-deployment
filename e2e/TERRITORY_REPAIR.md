# Correção territorial — 2026-10-06

## Causa e correção

O agrupamento pandas produzia float NaN para territórios ausentes; o driver o
adaptava como `'NaN'::float`, convertido em texto nas colunas VARCHAR. O loader
agora converte ausências para None após agrupar, valida IDs/status/catálogo e
compara todas as dimensões persistidas dentro da transação, revertendo divergências.
O Java usa catálogo e status para determinar cobertura, não apenas IS NOT NULL.
O frontend também foi corrigido: ao visualizar os bairros da Sede, o total do
distrito vem do total do recorte, não da busca do código distrital na lista de
bairros. Isso elimina a mensagem incorreta de "sem registros" nesse contexto.

O volume do deployment não tinha CNES. Foi carregado o snapshot
`20261006T131004Z`, com 3.808 unidades. Coordenadas permanecem na Silver;
ausências, valores não finitos e pontos fora das malhas não inventam território.

## Recuperação executada

Backup completo de `situacao_saude` em
`artifacts/territory-repair-20261006/situacao_saude_before_territory_20261006.dump`
(ignorado pelo Git). Índice do arquivo conferido com pg_restore. Snapshots antigos
foram preservados. Nenhum usuário ou volume foi removido.

Reprocessamento a partir das Silvers originais, sem nova coleta SINAN:

| Agravo | Linhas | Notificações | Novo batch |
|---|---:|---:|---|
| DENG | 218 | 219 | 20261006T131421Z |
| FMAC | 65 | 65 | 20261006T131421Z |
| TOXC | 6 | 6 | 20261006T131422Z |
| TOXG | 13 | 13 | 20261006T131422Z |

Auditoria Gold × PostgreSQL aprovada nos quatro recortes: todas as chaves, totais
e batches reconciliados; nenhum recorte no banco sem Gold correspondente.

Campos: 86 notificações com distrito, sendo 83 com bairro e 3 apenas com distrito.
Outros municípios: 217 notificações com detalhamento intramunicipal indisponível
(Itaperuna 127, Macaé 79, São João da Barra 11). Não confundir com ausência de
notificações ou falha de mapeamento em Campos.

## Validação

105 testes do pipeline aprovados, incluindo 18 de integração em PostgreSQL 16
isolado. Os 11 testes Java passaram. Testes de regressão Java verificam IDs inválidos, status incoerente e
contabilização distrital/bairro. Esses testes não são a suíte de 100+ E2E solicitada.
Os 11 testes Playwright já existentes no frontend também passaram (fixtures/mocks).

`npm run smoke:territory`, nesta pasta, usa o Compose/ngrok real e a identidade de
teste do `.env` ignorado. As expectativas numéricas desse smoke são específicas
do snapshot preservado de 2026. A identidade foi fornecida exclusivamente para
testes; os dados epidemiológicos continuam sendo dados reais da origem.

Smoke executado e aprovado via ngrok com Chromium do NixOS: login, Campos,
distritos e bairros da Sede. Dengue/2026 retornou total distrital 23, total da
Sede 23 e 21 com bairro. Nenhuma resposta 5xx nas requisições observadas.
Screenshot em `artifacts/territory-repair-20261006/browser.png` (não versionada).

```sh
nix-shell -p chromium --run 'CHROMIUM_PATH=$(command -v chromium) npm run smoke:territory'
```
