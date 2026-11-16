# Relatório de validação — bairros CNES e mapa

**Data:** 15/11/2026 (America/Sao_Paulo)  
**Objetivo:** validar a inclusão de bairros identificados somente pelo nome do CNES no ranking e corrigir a apresentação cartográfica para que o contorno municipal não distorça a leitura dos polígonos de bairros.

## Resultado executivo

As alterações foram reconstruídas e executadas no Compose isolado do deployment. O pipeline passou a criar uma identificação estável `CNES_BAIRRO:<município>:<nome>` quando o nome do bairro informado pela unidade não encontra geometria. O Java passou a aceitar esse status no filtro de bairro e a incluir esses itens no catálogo/ranking. No front, o município passou a ser um contorno de referência, enquanto os bairros são a camada preenchida principal.

O lote CNES reclassificado foi concluído com:

| Indicador | Quantidade |
|---|---:|
| Registros com bairro por polígono | 275.192 |
| Bairros distintos com geometria no lote | 14.133 |
| Registros com bairro somente por nome | 367.075 |
| Bairros distintos somente por nome | 59.226 |
| Bairros somente por nome em Belo Horizonte | 156 |

No catálogo territorial nacional usado pelo Java há 28.465 bairros/localidades, dos quais 23.744 têm geometria OSM, 235 têm geometria oficial e 4.486 são itens catalogados sem polígono próprio.

## Caso Tijuca em Belo Horizonte

O código do município é `3106200`. A consulta ao lote CNES reclassificado não encontrou `Tijuca` nesse município, nem no campo de bairro nem nos demais campos textuais examinados. Portanto, a ausência atual no ranking não é causada pelo filtro Java ou pelo front: o valor não está presente na origem CNES carregada.

Quando um estabelecimento vier com `bairro_cnes = Tijuca`, a nova regra criará o item `CNES_BAIRRO:3106200:Tijuca`, com status `NOTIFICATION_NEIGHBORHOOD_NAME_ONLY`, e ele poderá aparecer no ranking mesmo sem polígono.

## Alterações realizadas

- **Pipeline:** fallback de território para o nome do bairro CNES, com ID estável e URL encoding do nome.
- **Java:** filtros de bairro aceitam `NOTIFICATION_NEIGHBORHOOD_NAME_ONLY`; itens `CNES_BAIRRO:*` são incluídos no catálogo de ranking.
- **Front-end:** o limite municipal é desenhado como contorno sem preenchimento dominante; a camada de bairros permanece preenchida e translúcida, evitando que o município “achate” visualmente os bairros.
- **Deployment:** imagens locais de database, Java, frontend e pipeline foram reconstruídas usando `deployment.env`; Java e frontend foram recriados no Compose.
- **Dados:** foi executada a reclassificação do lote CNES `20261115T042236Z` e a publicação Gold de DENG/2026.

## Verificações executadas

- Pipeline: `38 passed` nos testes de mapeamento territorial e Gold.
- Java: suíte Maven concluída sem falhas; os relatórios Surefire indicam zero failures/errors, incluindo os testes de epidemiologia, repositório e serviço.
- Front-end: build Vite concluído e lint concluído.
- Playwright no Chromium fornecido pelo Nix: `1 passed` no cenário de navegação/cobertura/gaveta em 1024 px.
- Compose: PostgreSQL, Redis e Java ficaram saudáveis; Java respondeu com status `healthy`.
- Gold: DENG/2026 publicado com `462.544` casos.

## Ocorrências observadas

- HEPA/2026 falhou porque a fonte PySUS não disponibiliza Parquet SINAN para esse ano: `Nenhum Parquet SINAN disponível para HEPA/2026`.
- No levantamento anterior, fontes SINAN indisponíveis eram tratadas como falha não fatal pelo menu; isso não invalida a publicação bem-sucedida de DENG.
- O arquivo `deployment.env` está com permissão `777` e proprietário `root:root`. Isso permitiu a reconstrução, mas é uma exposição de credenciais e deve ser corrigido para modo restrito, idealmente `600`, conforme o runbook do deployment.

## Limitações e próximos passos

O fallback por nome resolve a presença no ranking, mas não inventa uma posição geográfica. Para desenhar o ponto de uma unidade sem latitude/longitude válida ainda é necessário enriquecimento por CEP/endereço ou outra fonte de geocodificação. Para o caso Tijuca, primeiro é necessário confirmar o nome no arquivo CNES de origem ou corrigir a carga correspondente.

