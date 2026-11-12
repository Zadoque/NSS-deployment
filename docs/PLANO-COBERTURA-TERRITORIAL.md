# Plano de validação territorial nacional

## Objetivo

Corrigir e validar primeiro o importador territorial, produzir um catálogo
canônico sem duplicidades ou relações inválidas e só então sincronizar
pipeline, Java e frontend para os 5.571 municípios. A publicação de uma nova
versão territorial deve ser bloqueada até que o catálogo, as geometrias, a
API e o Gold passem pelos mesmos critérios de QA.

## Ordem obrigatória e gates

O trabalho será executado nesta ordem:

```text
importador OSM/oficial
        ↓ gate A: qualidade do catálogo canônico
auditoria nacional e relatório
        ↓ gate B: paridade pipeline/Java/frontend
exportação atômica dos artefatos
        ↓ gate C: API e consulta mensal/anual
CNES → Gold → API
        ↓ gate D: totais e cobertura epidemiológica
publicação da release territorial
```

Nenhum artefato gerado deve ser corrigido manualmente para contornar um gate.
Se uma fonte não cobrir um município ou bairro, isso deve aparecer como
`UNAVAILABLE` no relatório, nunca como uma geometria inventada.

## Critérios de aceite

1. O catálogo nacional de municípios contém exatamente 5.571 códigos IBGE de
   sete dígitos, sem duplicidade e com nome/UF preenchidos.
2. O catálogo canônico não contém IDs duplicados, geometrias vazias ou
   inválidas, nem duas geometrias que representem o mesmo território.
3. Para cada município, os identificadores de distrito, nome, tipo, código
   municipal, pai e status são iguais na pipeline, na API Java e no frontend.
4. Todo distrito referenciado por um bairro existe no mesmo município, e toda
   geometria está contida no município/distrito declarado, respeitando uma
   tolerância espacial documentada.
5. A contagem de regiões, estados, municípios, distritos e bairros é emitida
   por snapshot, por UF, município e distrito. Os números esperados são 5
   regiões, 27 UFs e 5.571 municípios; distritos e bairros devem ser derivados
   da fonte validada, sem número fixado artificialmente.
6. A ausência de bairros é representada explicitamente como
   `UNAVAILABLE`; ela não remove os distritos nem o município do catálogo.
7. Para cada município processado pelo CNES, a validação mede unidades totais,
   unidades com coordenadas, unidades classificadas e unidades não mapeadas.
8. No fluxo Gold, o total municipal é preservado e a soma territorial é
   separada da parcela não mapeada.
9. O frontend só permite selecionar um território que exista no catálogo da
   API e possui geometria correspondente no mapa.

## Fase 1 — corrigir e testar o importador

Antes de regenerar qualquer catálogo:

1. identificar duplicidades por ID, nome normalizado, tipo OSM e sobreposição
   geométrica;
2. quando `way` e `relation` representarem o mesmo bairro, priorizar a
   `relation` e conservar uma única entrada;
3. preservar bairros legitimamente distintos com o mesmo nome quando os IDs e
   as geometrias forem diferentes;
4. validar geometrias, anéis, contenção municipal, distrito-pai e limites;
5. adicionar testes unitários para Lourdes, Santo Agostinho e casos de nome
   repetido legítimo;
6. tornar o importador determinístico e fazer o processo falhar quando uma
   regra estrutural for violada.

O importador deve produzir um relatório de descarte, com o motivo, o ID
retido e o ID descartado. Nenhum descarte pode ocorrer silenciosamente.

## Fase 2 — auditoria nacional do catálogo canônico

Criar um comando determinístico no pipeline que leia um snapshot e gere um
relatório versionável com:

- regiões, estados, municípios, distritos e bairros por nível;
- contagens por UF, município e distrito;
- IDs duplicados e nomes duplicados;
- geometrias inválidas, vazias, desconectadas ou sobrepostas acima da
  tolerância;
- pais inexistentes ou pertencentes a outro município;
- bairros fora do distrito/município declarado;
- municípios sem geometria e municípios sem bairros, separados entre
  ausência legítima e erro de importação.

O comando deve retornar código diferente de zero para qualquer violação de
integridade. O relatório deve conter o hash do snapshot, a fonte, o horário e
as versões dos importadores.

## Fase 3 — piloto Belo Horizonte após a correção

Código IBGE: `3106200`.

Fonte atual: malhas versionadas em `NSS-pipeline/territories`, exportadas para
o catálogo Java e para `public/maps/national`.

Os números abaixo eram a linha de base anterior à deduplicação. O snapshot
canônico aprovado substituiu essa linha de base:

- 3 distritos e 466 bairros canônicos em BH nos três consumidores;
- 2 geometrias OSM redundantes foram descartadas (Lourdes e Santo Agostinho,
  `way` sobreposto à `relation`), com relatório versionado;
- conjuntos de identificadores, nomes e pais iguais entre as três fontes;
- teste `TerritoryCatalogTest` cobrindo os 3 distritos e 466 bairros;
- suíte Maven do Java executada com sucesso.

O gate nacional foi executado no snapshot promovido e produziu: 5 regiões, 27
UFs, 5.571 municípios, 10.699 distritos, 28.465 bairros e 39.164 geometrias.
Houve 594 descartes determinísticos no total, zero IDs duplicados, zero
geometrias vazias ou inválidas, zero pais inexistentes, zero geometrias fora
do pai e zero sobreposições semânticas acima de 85%. A contenção usou
tolerância de `1e-6` grau. A paridade com o TSV Java foi completa e o auditor
retornou código 0.

Validação operacional executada no `nss-v1`:

1. construir a nova imagem Java e recriar o serviço;
2. verificar Java saudável, Compose, Redis e Caddy;
3. consultar a API de distritos e bairros de BH;
4. conferir DENG/2026: total municipal 4.015, parcela territorial mapeada
   254 e parcela não mapeada 3.761;
5. confirmar que a API retorna os três distritos, inclusive os que tenham
   zero casos;
6. confirmar 466 bairros canônicos e a distribuição por distrito no relatório
   gerado, sem duplicidade semântica;
7. confirmar que a soma territorial continua separada da parcela não mapeada.

Após o importador corrigido, o piloto só será aprovado novamente quando:

- Lourdes aparecer uma única vez no catálogo semântico e no GeoJSON;
- Santo Agostinho aparecer uma única vez, salvo justificativa documentada;
- houver exatamente 3 distritos e 466 bairros canônicos, registrados no
  relatório;
- a API retornar cada território uma única vez;
- DENG/2026 continuar preservando o total municipal de 4.015;
- as consultas de mês individual, ano inteiro e período inteiro retornarem
  a soma esperada;
- o mapa não desenhar uma geometria ocupando o espaço de outra.

## Fase 4 — sincronização atômica das três aplicações

Usar o exportador existente da pipeline como única rotina de publicação do
catálogo. A rotina deve:

1. ler o snapshot aprovado e `municipalities.index.json`;
2. gerar o TSV consumido pelo Java;
3. gerar o índice de bairros usado pelo frontend;
4. copiar as geometrias correspondentes para o frontend;
5. comparar conjuntos e metadados entre os três produtos;
6. produzir um resumo por município e por fonte geométrica;
7. publicar todos os artefatos no mesmo commit de release.

O commit deve ser atômico por release de catálogo, evitando atualizar Java e
frontend com snapshots diferentes. O hash do snapshot canônico deve ser
registrado nos artefatos gerados.

## Fase 5 — validação CNES dos 5.571 municípios

Executar o CNES em lote controlado e guardar, por município:

- lote e data da coleta;
- quantidade de estabelecimentos;
- quantidade com latitude/longitude válidas;
- quantidade com distrito;
- quantidade com bairro;
- quantidade `UNMAPPED_NOTIFICATION_UNIT`;
- motivo de indisponibilidade, quando houver.

As unidades SINAN que não aparecem no CNES devem formar um relatório separado.
Não se deve atribuir distrito por nome textual ou por aproximação sem regra
versionada e aprovada.

### Evidência inicial de BH e lote histórico

O lote CNES ativo `20261112T153932Z` contém 560 estabelecimentos de BH,
enquanto o lote histórico `20261103T125935Z` contém 11.179. Dos 225 códigos
SINAN ausentes no lote ativo, 219 aparecem no lote histórico, cobrindo 3.734
dos 3.755 casos associados a esses códigos. No entanto, os campos territoriais
do lote histórico estão marcados como `UNAVAILABLE`.

Uma reclassificação somente em memória, usando as geometrias versionadas
atuais, classificou esses registros históricos de BH em 3.704 casos por
bairro, 25 somente por distrito e 205 ainda não mapeados. Isso demonstra uma
possível recuperação, mas não autoriza substituir automaticamente o lote
ativo: a troca de snapshot altera a referência epidemiológica do Gold.

Critério para a próxima implementação: reclassificar o lote histórico em uma
área isolada, comparar contagens e metadados com o lote ativo e exigir um
`batch_id` explicitamente aprovado antes de publicar qualquer fallback.

## Fase 6 — validação Gold e API

Selecionar amostras representativas por estado, incluindo municípios com:

- distritos e bairros;
- distritos sem bairros;
- somente município;
- unidades CNES sem coordenadas;
- unidades SINAN ausentes do CNES.

Para cada amostra, comparar:

```text
total municipal = mapeado + não mapeado
```

e verificar que a API retorna todos os territórios catalogados, inclusive os
sem casos, sem inventar notificações para áreas não mapeadas.

## Fase 7 — proteção contra regressão

Adicionar ao CI:

- teste de completude dos 5.571 municípios;
- teste do importador contra `way`/`relation` duplicados;
- teste nacional de unicidade, contenção e sobreposição geométrica;
- teste de paridade pipeline/Java/frontend;
- teste de integridade dos pais;
- teste de contagem e soma Gold/API;
- teste de contrato para `AVAILABLE`, `PARTIAL` e `UNAVAILABLE`;
- relatório de cobertura CNES e SINAN por município.

Uma atualização futura do catálogo só poderá ser publicada se todos os
verificadores passarem ou se as exceções forem registradas explicitamente.

## Atualização SINAN multi-doença/ano

Na execução de CHIK, ZIKA, TUBE e HANS para 2023–2026, foram processados 15
dos 16 pares. O único par sem carga foi `TUBE/2026`, para o qual o catálogo
PySUS não disponibiliza Parquet. O manifesto registrou esse caso como
`UNAVAILABLE`, sem interromper as demais cargas.

O `nss-deploy.sh` passou a enviar `--allow-unavailable` ao job de atualização,
e a suíte de contrato do pipeline foi executada no container: `31 passed`.
Esse comportamento mantém a falha real visível no manifesto e evita tratar
uma ausência de fonte como erro das outras doenças/anos.

## Diagnóstico conhecido de BH

O Gold de DENG/2026 preserva 4.015 casos. O lote usado encontrou 254 casos em
unidades territoriais classificadas e 3.761 em 225 unidades SINAN sem
correspondência no CNES. A correção do catálogo Java resolve a ausência dos
distritos na aplicação, mas não cria correspondências CNES inexistentes; essa
parcela continuará aparecendo como cobertura territorial parcial até que os
vínculos das unidades sejam resolvidos.
