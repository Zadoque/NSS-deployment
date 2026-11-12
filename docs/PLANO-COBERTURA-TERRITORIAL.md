# Plano de validação territorial nacional

## Objetivo

Garantir que os 5.571 municípios do catálogo nacional tenham informações
territoriais consistentes entre pipeline, API Java e frontend, sem transformar
ausência legítima de bairros em município inexistente ou em zero silencioso.

## Critérios de aceite

1. O catálogo nacional de municípios contém exatamente 5.571 códigos IBGE de
   sete dígitos, sem duplicidade e com nome/UF preenchidos.
2. Para cada município, os identificadores de distrito, nome, tipo, código
   municipal, pai e status são iguais na pipeline, na API Java e no frontend.
3. Todo distrito referenciado por um bairro existe no mesmo município.
4. Nenhum identificador territorial aparece associado a dois municípios ou a
   dois nomes diferentes.
5. A ausência de bairros é representada explicitamente como
   `UNAVAILABLE`; ela não remove os distritos nem o município do catálogo.
6. Para cada município processado pelo CNES, a validação mede unidades totais,
   unidades com coordenadas, unidades classificadas e unidades não mapeadas.
7. No fluxo Gold, o total municipal é preservado e a soma territorial é
   separada da parcela não mapeada.
8. O frontend só permite selecionar um território que exista no catálogo da
   API e possui geometria correspondente no mapa.

## Fase 1 — piloto Belo Horizonte

Código IBGE: `3106200`.

Fonte atual: malhas versionadas em `NSS-pipeline/territories`, exportadas para
o catálogo Java e para `public/maps/national`.

Validações realizadas:

- 3 distritos e 468 bairros presentes na pipeline;
- 3 distritos e 468 bairros presentes no frontend;
- 3 distritos e 468 bairros presentes no Java após a correção;
- conjuntos de identificadores, nomes e pais iguais entre as três fontes;
- teste `TerritoryCatalogTest` cobrindo os 3 distritos e 468 bairros;
- suíte Maven do Java executada com sucesso.

Validação operacional pendente do piloto:

1. construir a nova imagem Java;
2. subir um Compose de validação com projeto distinto do ativo;
3. consultar a API de distritos e bairros de BH;
4. conferir DENG/2026: total municipal 4.015, parcela territorial mapeada
   254 e parcela não mapeada 3.761;
5. confirmar que a API retorna os três distritos, inclusive os que tenham
   zero casos;
6. destruir somente o Compose de validação.

## Fase 2 — verificador nacional de catálogo

Criar um comando determinístico no pipeline que leia a fonte canônica e gere
um relatório com:

- municípios esperados e encontrados;
- distritos por município;
- bairros por município e por distrito;
- códigos duplicados;
- pais inexistentes ou de outro município;
- geometrias vazias ou inválidas;
- divergências entre pipeline, Java e frontend.

O comando deve retornar código diferente de zero para divergência estrutural.
O relatório deve ser versionado como artefato de CI, não como dado manual.

## Fase 3 — sincronização das três aplicações

Usar o exportador existente da pipeline como única rotina de publicação do
catálogo. A rotina deve:

1. ler `municipalities.index.json` e as malhas nacionais;
2. gerar o TSV consumido pelo Java;
3. gerar o índice de bairros usado pelo frontend;
4. copiar as geometrias correspondentes para o frontend;
5. validar os três produtos antes do commit;
6. produzir um resumo por município e por fonte geométrica.

O commit deve ser atômico por release de catálogo, evitando atualizar Java e
frontend com snapshots diferentes.

## Fase 4 — validação CNES dos 5.571 municípios

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

## Fase 5 — validação Gold e API

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

## Fase 6 — proteção contra regressão

Adicionar ao CI:

- teste de completude dos 5.571 municípios;
- teste de paridade pipeline/Java/frontend;
- teste de integridade dos pais;
- teste de contagem e soma Gold/API;
- teste de contrato para `AVAILABLE`, `PARTIAL` e `UNAVAILABLE`;
- relatório de cobertura CNES e SINAN por município.

Uma atualização futura do catálogo só poderá ser publicada se todos os
verificadores passarem ou se as exceções forem registradas explicitamente.

## Diagnóstico conhecido de BH

O Gold de DENG/2026 preserva 4.015 casos. O lote usado encontrou 254 casos em
unidades territoriais classificadas e 3.761 em 225 unidades SINAN sem
correspondência no CNES. A correção do catálogo Java resolve a ausência dos
distritos na aplicação, mas não cria correspondências CNES inexistentes; essa
parcela continuará aparecendo como cobertura territorial parcial até que os
vínculos das unidades sejam resolvidos.
