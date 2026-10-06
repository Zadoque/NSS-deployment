# Auditoria Gold → PostgreSQL → frontend

**Registro histórico anterior à correção.** A divergência abaixo foi resolvida;
o estado atualizado e os novos batches estão em [TERRITORY_REPAIR.md](TERRITORY_REPAIR.md).

2026-10-06, branch feat/caddy-ngrok-integration. Fonte: volume pipeline_data do
Compose nss-v1; banco db:5432/situacao_saude. Conferidos quatro snapshots.

| Agravo/ano | Batch | Linhas Gold/PG | Total Gold/PG | Chaves não territoriais | Território |
|---|---|---:|---:|---|---|
| DENG/2026 | 20261006T113556Z | 218/218 | 219/219 | iguais | divergente |
| FMAC/2026 | 20261006T113632Z | 65/65 | 65/65 | iguais | divergente |
| TOXC/2026 | 20261006T113659Z | 6/6 | 6/6 | iguais | divergente |
| TOXG/2026 | 20261006T113727Z | 13/13 | 13/13 | iguais | divergente |

16 publicações, 302 linhas, 303 notificações. Todas as 302 linhas têm distrito e
bairro como texto `NaN` no PostgreSQL, enquanto a Gold tem nulos. Todas possuem
status UNMAPPED_NOTIFICATION_UNIT. Não há snapshot CNES em /data/silver/cnes
neste volume: o CNES de outro ambiente não enriqueceu esta carga.

Java totals() usa IS NOT NULL, contando NaN como mapeado. aggregate() agrupa esse
código inexistente no catálogo. Pode indicar AVAILABLE com itens territoriais
zerados, apesar de notificações não mapeadas. A rotina insert_fato_casos usa
to_dict após groupby(dropna=False), sem conversão explícita de ausentes pandas
para None. Esse é o ponto de investigação da conversão. Nenhuma correção SQL
ou alteração na pipeline foi feita nesta auditoria.

## Matriz de filtros

| Controle | Requisição | Oráculo Gold/SQL | Situação |
|---|---|---|---|
| Doença | disease | disease_codigo | DENG, FMAC, TOXC, TOXG |
| Ano | year; omitido em Todos | ano | somente 2026; histórico não carregado |
| Mês | month; omitido em Todos | mes | metadata 1–9; ano Todos oferece 1–12 |
| Sexo | M/F; omitido em Todos | cd_sexo | F=155, M=148; I ausente, inclusão não comprovável |
| Idade | ageBand; omitido em Todas | age_band | 12 faixas LT1 a 80_PLUS; NI não oferecido |
| Região | /epidemiology/region | sem total agregado contratado | apenas Sudeste navegável |
| Estado | frontend usa REGION na visão estadual | UNAVAILABLE esperado | apenas RJ navegável |
| Município | municipalityCode | cd_mun | Campos, Itaperuna, Macaé, São João da Barra |
| Distrito | /districts + municipalityCode | notification_district_id | Campos; bloqueado por NaN |
| Bairro da notificação | /neighborhoods + districtCode | notification_neighborhood_id | somente CG_DIST_SEDE; sem mapeamentos |
| Seleção de bairro | consulta distrital, seleção local | item no envelope | não existe parâmetro neighborhoodCode |
| Sem publicação | ano/doença sem snapshot | pipeline_publications | Java não consulta publicações; pode confundir ausência com zero |
| Total oficial | totalNotifications | SUM(cases_total) filtrado | frontend usa total do backend |
| Cobertura | coverage | chaves territoriais válidas | NaN invalida classificação atual |

Inspecionados: FilterPanel, GeographySelector, DashboardPage, useMapNavigation,
apiDataSource, http, controller/filter/repository/service epidemiológicos.
Observações de UI são auditoria de código, ainda não execução no navegador.

## Cenários planejados

156 cenários UI: 4 doenças × 3 sexos (Todos/M/F) × 13 faixas (Todas e as 12
faixas). Cada um deverá validar seleção, parâmetros, total SQL/Gold, total
exibido e itens. Complementar com ano Todos/2026, meses 1–12, período/município,
zero publicado versus ausência, retorno a Todos, pesquisa municipal, navegação
Campos→distrito→sede→bairro e restrição fora da sede. Dados ausentes como sexo I
e distrito conhecido sem bairro devem ser reportados como não comprovados.
Login real, refresh, reload, logout, proteção anônima e permissões da conta
complementarão a suíte. Não enviar convites/reset como efeito da auditoria.

## Resultado

REPROVADA: totais iguais não provam correspondência integral com a Gold. Corrigir
publicação de nulos e republicar os recortes antes de avançar para Playwright,
conforme a sequência solicitada. Os 100+ E2E permanecem pendentes.
