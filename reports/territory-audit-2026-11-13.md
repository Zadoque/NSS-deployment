# Auditoria territorial CNES × IBGE/OSM

Data da análise: 2026-11-13  
Lote CNES: `20261112T210938Z`  
Fonte: `/data/silver/cnes/batch_id=20261112T210938Z/data.parquet` no volume Docker `nss-v1_pipeline_data`.

## Escopo e método

Análise somente leitura. Cada ponto CNES foi testado com `longitude, latitude` contra os polígonos de bairros e distritos dos pacotes `territories/ibge/<município>` e `territories/osm/<município>`, usando `covers` para incluir pontos na borda. Os resultados foram calculados independentemente dos campos territoriais já gravados no parquet CNES.

Observação: nos pacotes OSM atuais, os arquivos de distrito são, em praticamente todos os municípios, cópias dos distritos IBGE; a diferença efetiva entre IBGE e OSM está principalmente nos polígonos de bairro/localidade. Foram encontrados 1.327 diretórios OSM; 1.326 arquivos de distrito são idênticos ao IBGE correspondente.

## Resultado nacional

A auditoria estrutural independente passou: 5 regiões, 27 UFs, 5.571 municípios, 10.699 distritos, 28.465 bairros/localidades, 39.164 geometrias e zero violações de geometria, duplicidade ou paridade entre pipeline e Java.

| Métrica | Quantidade | Percentual do CNES |
|---|---:|---:|
| Unidades CNES | 642.268 | 100,00% |
| Coordenadas válidas | 583.481 | 90,85% |
| Sem coordenada válida | 58.787 | 9,15% |
| Ponto em bairro IBGE | 56.454 | 8,79% |
| Ponto em bairro OSM | 240.394 | 37,43% |
| Ponto em bairro IBGE ou OSM | 275.277 | 42,86% |
| Sem bairro em IBGE e OSM | 366.991 | 57,14% |
| Ponto em distrito IBGE | 568.838 | 88,57% |
| Ponto em distrito do pacote OSM | 413.879 | 64,44% |

QA adicional usando os 5.571 polígonos municipais do frontend: 559.368 unidades estão dentro do município declarado; 24.113 têm coordenadas dentro da faixa numérica válida, mas fora do polígono do município declarado; 58.787 não possuem coordenada válida. Portanto, **82.900 unidades** não podem ser usadas diretamente para inferir bairro, sendo 24.113 casos de provável inconsistência espacial CNES/geocodificação.

Entre as 366.991 unidades sem bairro geométrico:

| Classificação do bairro textual CNES | Quantidade |
|---|---:|
| Bairro textual também encontrado pelo nome no IBGE/OSM, mas ponto sem correspondência geométrica | 37.543 |
| Bairro textual não encontrado nos catálogos IBGE/OSM | 329.447 |
| Sem bairro textual no CNES | 1 |

Portanto, a resposta preliminar à terceira tarefa é **329.447 unidades CNES** em bairros que não existem nominalmente nos catálogos atuais. Esse número ainda deve passar por normalização/aproximação de nomes e revisão de homônimos antes de ser tratado como número final.

Uma segunda triagem, removendo prefixos usuais (`JARDIM`, `VILA`, `PARQUE`, `RESIDENCIAL` etc.) e usando similaridade textual de 0,88 ou maior, encontrou 3.948 unidades potencialmente correspondentes a nomes abreviados ou com erro de digitação. Isso não foi subtraído do total: é uma fila de revisão, não uma prova de correspondência.

## Municípios com baixa cobertura

Considerando a união dos nomes de bairros IBGE e OSM:

| Bairros distintos | Municípios |
|---:|---:|
| 0 | 3.884 |
| 1 | 390 |
| 2 | 127 |
| 3 | 80 |
| **Total até 3** | **4.481** |

Os 4.481 municípios possuem 201.098 unidades CNES no lote; 197.021 dessas unidades não têm bairro geométrico encontrado na união IBGE/OSM.

O cruzamento nominal gerou 54.964 grupos distintos de `município + bairro CNES` ausente, cada um com um identificador provisório no formato `CNES_BAIRRO_<código do município>_<nome normalizado>`. Esses identificadores são auxiliares de auditoria, não códigos oficiais de bairro.

## Limitações atuais

- A contagem de “bairro existe no catálogo” usa correspondência nominal normalizada sem acentos; ainda não é uma validação semântica ou geocodificação aproximada.
- A análise municipal encontrou coordenadas numericamente válidas, porém fora do município declarado; esses casos precisam ser separados dos casos de ausência de polígono.
- O CNES não fornece uma lista nacional única e oficial de bairros com códigos padronizados. Onde não existir código oficial, o relatório deverá usar um identificador canônico interno, preservando a fonte original.
- A etapa de pesquisa externa dos 4.481 municípios ainda está pendente. Ela deve ser feita por município, registrando fonte, data e confiança; não se deve substituir essa etapa por uma estimativa única.
- O mapa diagnóstico ainda não foi renderizado em `/home/dock/dev/Campos_maps/frontend`.

## Artefatos temporários

Os arquivos detalhados da execução estão em `/tmp/nss-cnes-audit/`:

- `summary.json`: métricas nacionais, regionais, por UF e município;
- `municipalities.csv`: cobertura e quantidade de bairros por município;
- `cnes_units.csv`: classificação individual das 642.268 unidades;
- `unmapped_classification.json`: cruzamento dos bairros textuais CNES com os catálogos;
- `unmapped_bairros_absentes.csv`: unidades cujo bairro textual não foi encontrado nominalmente.
- `missing_neighborhood_groups.csv`: grupos de bairro ausente por município e quantidade de unidades CNES, com código provisório de auditoria.

Também foi gerado o mapa diagnóstico [`territory-audit-map.html`](./territory-audit-map.html), em recorte dos quatro municípios prioritários por volume de unidades sem bairro: Jundiaí, Araçatuba, Bauru e Franca. Ele diferencia pontos com bairro mapeado dos pontos sem bairro e permite filtrar o município.

Os artefatos detalhados não foram adicionados ao Git por conterem aproximadamente 100 MB e dados operacionais; a reprodução deve usar os comandos e o lote registrados acima.
