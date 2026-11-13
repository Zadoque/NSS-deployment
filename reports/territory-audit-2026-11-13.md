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

O cruzamento adicional com a malha de bairros do Censo 2022 do IBGE encontrou nome correspondente para 26.744 dessas unidades e atribuiu o código oficial do bairro quando disponível. As outras 302.703 unidades continuam com código provisório `CNES_BAIRRO_*`; não foram convertidas em códigos IBGE por aproximação textual.

Para os 4.481 municípios com até três nomes IBGE+OSM, foi consultada uma fonte postal derivada do e-DNE/CNEFE. A página estadual permitiu obter contagem para 4.427 municípios por slug; os demais foram consultados em páginas municipais do CEP Brasil. Assim, os 4.481 possuem agora uma contagem postal de referência, totalizando 45.595 entradas postais. A coleta nominal municipal retornou 41.220 nomes em 4.469 municípios. As 12 exceções iniciais foram reavaliadas: 11 páginas municipais retornaram contagens nominais após correção da rota, e uma possui somente fonte postal alternativa; o resultado está em [`territory-audit-postal-research-exceptions-2026-11-13.csv`](./territory-audit-postal-research-exceptions-2026-11-13.csv). O cruzamento exato entre bairro CNES e nomes postais encontrou 11.566 grupos, correspondentes a 138.631 unidades CNES. Essa fonte serve para comparar cobertura nominal/espacial esperada, não para fabricar limites legais. Por exemplo, a página municipal de Santana do Araguaia explicita quatro bairros postais e suas faixas de CEP ([fonte](https://cepbrasil.com/pa/santana-do-araguaia)).

## Caso Rio Branco (AC)

O município `1200401` reproduz o problema de forma clara:

| Evidência | Quantidade |
|---|---:|
| Unidades CNES no lote | 1.425 |
| Unidades com coordenadas válidas | 1.293 |
| Bairros IBGE no pacote | 0 |
| Bairros OSM no pacote | 1 |
| Unidades dentro do único bairro OSM (`Cidade do Povo`) | 4 |
| Nomes de bairro textual no CNES | 176 |

O arquivo oficial do frontend `public/maps/national/neighborhoods/1200401.geojson` contém somente o polígono OSM `Cidade do Povo`; o arquivo de bairros IBGE está vazio. A resolução de ativos da pipeline seleciona `territories/osm/1200401` porque ele é o primeiro pacote completo com bairros. Assim, Java e pipeline não recebem geometrias para `Centro`, `Bosque`, `Cerâmica`, `Ipase` e os demais nomes presentes no CNES.

Isso não é causado pelo body da requisição nem pelo parquet Gold: é ausência de catálogo intramunicipal. A Prefeitura de Rio Branco informa 231 bairros em publicação recente, enquanto uma fonte postal consultada lista 147 bairros com CEP; a diferença mostra que “bairro postal”, “bairro municipal” e “polígono oficial” não são conjuntos intercambiáveis. Esses números servem como evidência de cobertura esperada, não como fonte geométrica automática. Ver [Prefeitura de Rio Branco](https://www.riobranco.ac.gov.br/turismo/rio-branco-coracao-do-acre-terra-de-resistencia-e-de-encantos/) e [lista postal consultada](https://www.diariocidade.com/ac/rio-branco/cep/).

Critério de correção: obter uma fonte municipal/legal com limites, ou produzir uma camada explicitamente marcada como `POSTAL`/`MUNICIPAL`, validar topologia e parent district, exportar a mesma camada para pipeline e frontend e então reprocessar CNES/Gold. Não é seguro transformar os nomes textuais do CNES em polígonos sem fonte de fronteira.

## Limitações atuais

- A contagem de “bairro existe no catálogo” usa correspondência nominal normalizada sem acentos; ainda não é uma validação semântica ou geocodificação aproximada.
- A análise municipal encontrou coordenadas numericamente válidas, porém fora do município declarado; esses casos precisam ser separados dos casos de ausência de polígono.
- O CNES não fornece uma lista nacional única e oficial de bairros com códigos padronizados. Onde não existir código oficial, o relatório deverá usar um identificador canônico interno, preservando a fonte original.
- A pesquisa externa nominal foi executada para os 4.481 municípios: houve referência postal para todos por contagem estadual ou municipal; 4.469 páginas municipais retornaram nomes (41.220 nomes) e 12 páginas responderam 404. Essas referências foram registradas com fonte e não foram usadas para fabricar limites legais.
- Rio Branco demonstra que o catálogo nacional precisa separar cobertura legal IBGE, cobertura municipal e cobertura postal/OSM; as contagens externas são referências postais/CNEFE e não devem ser interpretadas automaticamente como quantidade legal de bairros nem convertidas em geometrias.
- O mapa diagnóstico foi gerado como artefato standalone em [`territory-audit-map.html`](./territory-audit-map.html), com filtro por município e classificação mapped/unmapped. Ele não altera o frontend de produção nem foi copiado para `/home/dock/dev/Campos_maps/frontend`.

## Artefatos temporários

Os arquivos detalhados da execução estão em `/tmp/nss-cnes-audit/`:

- `summary.json`: métricas nacionais, regionais, por UF e município;
- `municipalities.csv`: cobertura e quantidade de bairros por município;
- `cnes_units.csv`: classificação individual das 642.268 unidades;
- `unmapped_classification.json`: cruzamento dos bairros textuais CNES com os catálogos;
- `unmapped_bairros_absentes.csv`: unidades cujo bairro textual não foi encontrado nominalmente.
- `missing_neighborhood_groups.csv`: grupos de bairro ausente por município e quantidade de unidades CNES, com código provisório de auditoria.
- [`territory-audit-by-municipality-2026-11-13.csv`](../reports/territory-audit-by-municipality-2026-11-13.csv): métricas dos 5.571 municípios e contagem postal;
- [`territory-audit-by-uf-2026-11-13.csv`](../reports/territory-audit-by-uf-2026-11-13.csv): totais por UF;
- [`territory-audit-by-region-2026-11-13.csv`](../reports/territory-audit-by-region-2026-11-13.csv): totais por Região;
- [`territory-audit-unmapped-neighborhoods-2026-11-13.csv`](../reports/territory-audit-unmapped-neighborhoods-2026-11-13.csv): 54.964 grupos de bairros textuais não encontrados nos catálogos atuais, com quantidade CNES e código provisório;
- [`territory-audit-neighborhood-crosswalk-2026-11-13.csv`](../reports/territory-audit-neighborhood-crosswalk-2026-11-13.csv): cruzamento dos mesmos grupos com código IBGE quando encontrado, referência postal quando disponível e código provisório quando não encontrado;
- [`territory-audit-postal-exceptions-2026-11-13.csv`](../reports/territory-audit-postal-exceptions-2026-11-13.csv): municípios que precisaram da consulta municipal individual, com nomes e fonte;
- [`territory-audit-postal-research-exceptions-2026-11-13.csv`](../reports/territory-audit-postal-research-exceptions-2026-11-13.csv): revalidação das 12 exceções de rota, com contagem, fonte, URL e confiança;
- [`territory-audit-postal-neighborhoods-2026-11-13.csv`](../reports/territory-audit-postal-neighborhoods-2026-11-13.csv): 41.220 nomes postais coletados em 4.469 municípios de baixa cobertura;
- [`territory-audit-unmapped-units-2026-11-13.csv.gz`](../reports/territory-audit-unmapped-units-2026-11-13.csv.gz): lista detalhada das 366.991 unidades sem bairro geométrico, incluindo CNES, coordenadas, município e bairro textual.

Também foi gerado o mapa diagnóstico [`territory-audit-map.html`](./territory-audit-map.html), em recorte dos quatro municípios prioritários por volume de unidades sem bairro: Jundiaí, Araçatuba, Bauru e Franca. Ele diferencia pontos com bairro mapeado dos pontos sem bairro e permite filtrar o município.

Os artefatos detalhados não foram adicionados ao Git por conterem aproximadamente 100 MB e dados operacionais; a reprodução deve usar os comandos e o lote registrados acima.
