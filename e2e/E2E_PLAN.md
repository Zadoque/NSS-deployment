# Planejamento da suíte E2E real do NSS

## Objetivo

Validar o fluxo real `ngrok → Caddy → frontend → Java → PostgreSQL`, usando a
identidade de teste do `e2e/.env` e os dados epidemiológicos publicados em
`situacao_saude`. A identidade é somente de teste; os dados epidemiológicos são
reais e não devem aparecer em artefatos públicos além dos resultados necessários.

## Pré-condições

1. `docker compose ps` deve mostrar `db`, `java`, `frontend` e `caddy` saudáveis.
2. A URL pública do ngrok deve estar no `E2E_BASE_URL`.
3. A auditoria Gold/PostgreSQL deve retornar `passed: true`.
4. O usuário de teste deve conseguir fazer login; nenhuma senha deve ser escrita
   em traces, screenshots, logs ou relatórios.
5. O snapshot Gold deve ser registrado antes da execução, pois os oráculos
   dependem do batch atual.

## Estrutura proposta

```text
e2e/
  playwright.config.ts
  global-setup.ts
  helpers/
    auth.ts
    api.ts
    ui.ts
    oracle.ts
  specs/
    01-auth.spec.ts
    02-metadata.spec.ts
    03-municipalities.spec.ts
    04-districts.spec.ts
    05-neighborhoods.spec.ts
    06-filters.spec.ts
    07-errors-and-loading.spec.ts
  reports/
```

O Playwright deverá usar um worker, `trace: retain-on-failure`, screenshots
somente em falhas e lotes de três cenários durante a primeira execução.

## Matriz mínima de cenários

O núcleo terá 156 combinações: 4 agravos × 3 opções de sexo × 13 opções de
faixa etária (Todas + 12 faixas). Cada cenário confere seleção, URL/parâmetros,
resposta, total, cobertura e itens visíveis.

| Grupo | Cobertura | Quantidade mínima |
|---|---|---:|
| Autenticação | login válido, inválido, refresh, logout, sessão expirada | 8 |
| Metadados | doenças, anos, meses disponíveis e carregamento inicial | 8 |
| Município | 4 agravos, períodos, sexo, idade e quatro municípios publicados | 24 |
| Distrito | Campos, total, cobertura parcial, distrito sem bairro | 16 |
| Bairro | Sede, bairros com zero, bairros com casos e retorno ao distrito | 16 |
| Combinações | agravo × sexo × idade × período | 156 |
| Resiliência | loading, 401, 403, 404, 500, retry e resposta vazia | 12 |
| Responsividade | 375, 768, 1024 e 1440 px | 8 |

Os cenários combinatórios podem ser gerados a partir de uma tabela de casos,
mas cada caso deve ter ID estável e aparecer no relatório. A suíte deve conter
pelo menos 100 testes independentes; o alvo recomendado é 248 cenários.

## Oráculos e verificações

Para cada caso, o helper `oracle.ts` calculará a expectativa diretamente no
PostgreSQL em transação somente leitura, filtrando:

- `disease_codigo`, `ano`, `mes`, `cd_sexo` e `age_band`;
- `cd_mun` para município;
- `notification_district_id` para distrito;
- `notification_neighborhood_id` para bairro;
- `notification_territory_status` válido para cobertura.

Também serão comparados o snapshot Gold correspondente e a resposta Java. A
soma dos itens exibidos não substitui o total oficial: ela deve ser comparada ao
total mapeado, enquanto `totalNotifications` deve corresponder ao universo do
recorte.

## Ordem de execução

1. Rodar a auditoria read-only e salvar somente o resumo do batch.
2. Executar autenticação e metadados.
3. Executar municípios em lotes de três.
4. Executar distritos e bairros de Campos.
5. Executar a matriz combinatória em lotes de três.
6. Executar erros, retry e responsividade.
7. Repetir somente os lotes que falharem, usando trace.
8. Produzir roteiro manual para cada falha persistente.

## Critérios de aprovação

- Pelo menos 100 cenários reais aprovados.
- Nenhuma resposta inesperada 4xx/5xx.
- Totais da API iguais ao PostgreSQL para todos os casos aplicáveis.
- Cobertura territorial coerente com status e catálogo.
- Sem uso de mocks, fallback de demonstração ou acesso direto do frontend ao DB.
- Sem credenciais, cookies ou tokens nos artefatos versionados.

## Limitações esperadas

Região e estado permanecem `UNAVAILABLE` na V1. O detalhamento intramunicipal
está publicado para Campos; os demais municípios têm totais municipais, mas não
possuem distritos/bairros no catálogo territorial atual. Esses resultados devem
ser classificados como indisponibilidade contratada, não como zero.
