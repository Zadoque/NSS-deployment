# Contrato HTTP - NSS API v1

Status: **normativo para NSS 1.0**  
Prefixo: `/api/v1`

Este contrato define a interface entre `nss-front-end` e o backend Java. Ele não define a implementação interna do Spring nem o schema físico do PostgreSQL.

## Princípios

- O frontend nunca consulta PostgreSQL ou Parquet diretamente.
- O Java executa as agregações analíticas; o frontend apenas apresenta os valores recebidos.
- A métrica exposta pela V1.0 é **notificações** até que exista regra epidemiológica formal de casos confirmados por agravo.
- A geografia da V1.0 é a da **notificação**.
- `0` é diferente de cobertura indisponível.
- Endpoints epidemiológicos exigem access token válido.

## Autenticação

Detalhes completos em `auth-v1.md`.

### `POST /api/v1/auth/login`

Request:

```json
{"email":"usuario@exemplo.br","password":"senha"}
```

Response `200`:

```json
{"accessToken":"<jwt>","tokenType":"Bearer","expiresIn":900}
```

O refresh token não aparece no JSON; ele é enviado em cookie HttpOnly/Secure.

### `POST /api/v1/auth/refresh`

Sem body. O navegador envia o refresh cookie. Response `200` possui o mesmo formato do login e rotaciona o refresh token.

### `POST /api/v1/auth/logout`

Revoga o refresh corrente, remove o cookie e retorna `204`.

## Doenças

### `GET /api/v1/diseases`

Retorna somente doenças efetivamente habilitadas no backend/banco. Toxoplasmose não deve aparecer até que a base/código correto tenha sido validado.

```json
{"items":[{"code":"DENG","name":"Dengue"},{"code":"FMAC","name":"Febre Maculosa"}]}
```

## Filtros analíticos comuns

- `disease`: obrigatório;
- `year`: obrigatório;
- `month`: obrigatório, `1..12`;
- `sex`: opcional; valores de UI `M` ou `F`; omitido significa Todos;
- `ageBand`: opcional; omitido significa Todos.

Códigos de faixa etária V1:

```text
LT1
01_04
05_09
10_14
15_19
20_39
40_59
60_64
65_69
70_74
75_79
80_PLUS
```

A categoria técnica `NI` existe nos dados mas não precisa ser opção explícita de filtro. Ao omitir `ageBand`, registros `NI` permanecem no total.

## Resposta geográfica comum

```json
{
  "metric":"notifications",
  "geography":"MUNICIPALITY",
  "filters":{"disease":"DENG","year":2026,"month":1,"sex":"F","ageBand":"20_39"},
  "coverage":{"status":"AVAILABLE"},
  "items":[{"code":"3301009","name":"Campos dos Goytacazes","notificationsTotal":127}]
}
```

`coverage.status` aceita na V1:

- `AVAILABLE`: consulta válida e coberta; `notificationsTotal=0` significa zero;
- `UNAVAILABLE`: a fonte/versão não cobre aquela geografia ou dimensão;
- `PARTIAL`: há cobertura parcial conhecida e o frontend deve sinalizá-la.

Quando `UNAVAILABLE`, a API não deve fabricar itens com zero.

## Municípios

### `GET /api/v1/epidemiology/municipalities`

Filtros comuns. O escopo da NSS 1.0 deve retornar no máximo os municípios habilitados: Campos dos Goytacazes, São João da Barra, Macaé e Itaperuna. A semântica é **município da notificação**.

## Distritos de Campos

### `GET /api/v1/epidemiology/districts`

Parâmetro adicional `municipality`, obrigatório. Na V1.0 somente Campos possui cobertura intramunicipal. `geography` deve ser `DISTRICT`.

Para municípios sem cobertura intramunicipal, retornar `200` com `coverage.status=UNAVAILABLE`, não uma lista de zeros.

## Bairros/localidades de Campos

### `GET /api/v1/epidemiology/neighborhoods`

Parâmetros adicionais: `municipality` e `district`, obrigatórios. `geography` deve ser `NEIGHBORHOOD`.

A métrica representa a localização territorial da **unidade notificadora**, não residência do paciente.

## Erros

Formato mínimo:

```json
{"code":"INVALID_FILTER","message":"Filtro inválido."}
```

Códigos HTTP mínimos: `400`, `401`, `403`, `404`, `409`, `500`. Erros internos não expõem stack trace ou segredo.

## Compatibilidade futura

Seleção simultânea de várias faixas etárias não entra na UI V1.0. O desenho do Java/PostgreSQL deve permitir futura lista/`IN (...)`, sem pré-calcular todas as combinações possíveis na pipeline.
