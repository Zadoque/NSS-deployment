# Contrato Gold Serving - NSS 1.0

Status: **normativo para NSS 1.0**

## Objetivo

Definir o único artefato Gold aceito pelo loader que publica dados analíticos no PostgreSQL consumido pelo Java. A Gold Ad Hoc continua existindo, mas não é um contrato de banco.

## Identidade do artefato

Metadata mínimo:

```json
{"artifact_kind":"serving","contract_version":"1.0","disease":"DENG","source_year":2026,"batch_id":"20261001T120000Z"}
```

O loader deve rejeitar tipo/versão incompatível, coluna obrigatória ausente ou valor fora dos domínios definidos. Valor ausente dentro de uma coluna existente pode usar categoria técnica documentada; ausência da própria coluna obrigatória é erro.

## Grão lógico mínimo

```text
disease_codigo
ano
mes
cd_mun_notificacao
cd_distrito_notificacao
cd_bairro_notificacao
cd_sexo
cd_faixa_etaria
```

Medida lógica: `notifications_total`.

Implementações legadas com nome físico `cases_total` devem mapear explicitamente para a semântica de notificações durante a migração. O nome legado não autoriza apresentar "casos confirmados".

## Geografia

A V1.0 representa **notificação**.

Para municípios em que o detalhamento intramunicipal não faz parte da V1.0, usar categoria `NA` (não aplicável), não `NI`. Para notificações de Campos cuja unidade não pôde ser territorializada, usar `NI` (não identificado), preservando a reconciliação do total municipal.

`ID_UNIDADE` permanece em Silver/Ad Hoc e artefatos de referência; não é obrigatório no grão final da fato Serving V1.

## Faixa etária

Derivada de `NU_IDADE_N`:

| Código | Label |
|---|---|
| `LT1` | <1 ano |
| `01_04` | 1 a 4 |
| `05_09` | 5 a 9 |
| `10_14` | 10 a 14 |
| `15_19` | 15 a 19 |
| `20_39` | 20 a 39 |
| `40_59` | 40 a 59 |
| `60_64` | 60 a 64 |
| `65_69` | 65 a 69 |
| `70_74` | 70 a 74 |
| `75_79` | 75 a 79 |
| `80_PLUS` | 80+ |
| `NI` | não informado/incompatível |

## Sexo

Domínio técnico mínimo: `M`, `F` e valor ignorado/não informado conforme normalização documentada. `Todos` não é armazenado: é ausência de filtro SQL e inclui ignorados/não informados.

## Tempo

`ano` e `mes` derivam de `DT_NOTIFIC`; `SEM_NOT` não pertence ao grão Serving V1.

## CNES e referência territorial

A pipeline pode manter artefato separado `notifying_units_territories` com `cd_unidade`, `nm_unidade` opcional, município, distrito, bairro e `mapping_status`. Latitude/longitude de marker da UBS não faz parte deste contrato.

## Publicação

Unidade de substituição: `disease_codigo + ano`.

Uma única transação deve validar, atualizar dimensões, remover estado anterior da partição, inserir estado completo novo, executar checks e fazer commit. Falha implica rollback.

Uma execução válida com zero notificações deve conseguir remover o estado anterior; `gold_df.empty -> return` não é semântica suficiente.

## Invariantes mínimas

- `notifications_total >= 0`;
- nenhuma dimensão obrigatória fisicamente ausente;
- soma Serving reconcilia com Silver elegível;
- soma Serving reconcilia com PostgreSQL;
- ausência territorial vira `NI`, não descarte silencioso;
- Gold Ad Hoc nunca é aceita pelo loader Serving.
