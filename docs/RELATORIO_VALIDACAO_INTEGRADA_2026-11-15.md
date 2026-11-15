# Relatório de validação integrada — NSS

**Data:** 15/11/2026  
**Ambiente:** Compose isolado do `nss-deployment`, PostgreSQL e Redis homologados, API Java e frontend reais atrás do Caddy.  
**Critério de encerramento:** nenhuma aprovação foi baseada somente em build; os fluxos críticos foram exercitados contra a API, o banco/Redis e o navegador Chromium fornecido pelo Nix.

## Resultado executivo

Os critérios críticos foram atendidos:

- SIFA/Cachoeiro de Itapemirim mostra as 353 notificações, a extração e a causa verificável da ausência de unidade localizável.
- O clique em `TIJUCA`, bairro nominal sem polígono, preserva município/distrito/filtros, mostra `TIJUCA (sem polígono)` no seletor e não desloca pontos para uma geometria inventada.
- A camada de bairros usa o recorte do distrito para enquadramento, torna os polígonos legíveis, reduz pontos CNES e limita o ranking com busca/rolagem.
- A renovação de sessão foi corrigida de 604.800 ms para 604.800.000 ms (sete dias), sem alterar o access token de 15 minutos.
- A validação nacional real passou nos 5.571 municípios.

## Causa de SIFA/Cachoeiro

Consulta da publicação ativa e conferência no PostgreSQL:

| Campo | Resultado |
|---|---|
| Agravo/ano | SIFA / 2025 |
| Município | Cachoeiro de Itapemirim / `3201209` |
| Total | 353 |
| `cd_unidade` | `0000000` em todas as 353 notificações |
| Status Gold | `UNMAPPED_NOTIFICATION_UNIT` |
| Distrito/bairro | ausentes |
| Extração | `2026-11-15T03:54:04.209449Z` |

O front passou a explicar: o SINAN entregou o recorte sem identificador de unidade suficiente para localizar o estabelecimento; as notificações permanecem no total municipal. Isso é diferente de “há bairro, mas falta polígono”. Nenhum bairro foi inferido por proximidade.

## Correções implementadas

### Frontend

- Preservação de `parentDistrictId`, inclusive quando a API envia `null`.
- Seleção de bairro nominal com `geometryAvailable=false`.
- Badge `sem polígono`, mensagem contextual e opção nominal preservada no seletor.
- Enquadramento inicial de bairros pelo GeoJSON do distrito selecionado, não pelo limite municipal inteiro.
- Polígonos locais com preenchimento/contorno legíveis e pontos CNES com raio controlado.
- Ranking de bairros com pesquisa e altura limitada, evitando uma página de milhares de pixels.
- Mensagem de cobertura parcial distinguindo ausência de localização da ausência de geometria.

### API/Java

- Bairros `CNES_BAIRRO:*` e `NOTIFICATION_NEIGHBORHOOD_NAME_ONLY` participam do ranking sem serem tratados como polígonos oficiais.
- Cobertura e totais de distrito/bairro foram testados mantendo a reconciliação com o total municipal.

### Autenticação

- Configuração efetiva verificada no contêiner: `JWT_EXPIRATION=900000` e `REFRESH_EXPIRATION=604800000`.
- Login real: HTTP 200; refresh real: HTTP 200; ambos retornaram access token de 900 s.
- Cookie renovável observado com expiração de sete dias.
- Redis real: nove chaves de refresh observadas, TTL entre 602.752 e 604.782 s.
- Playwright forçou uma resposta 401 em consulta e comprovou a chamada de refresh e a recuperação da tela.

## Evidência Playwright/Nix

Comandos principais:

```bash
PLAYWRIGHT_BASE_URL=http://127.0.0.1:8080 \
PLAYWRIGHT_ACCESS_TOKEN="$TOKEN" \
nix shell nixpkgs#chromium -c sh -c \
  'CHROMIUM_PATH=$(command -v chromium) npx playwright test tests/national-municipalities-live.spec.ts --workers=8 --reporter=dot'
```

Resultado final: **5.571 passed (2,7 min)**. Além de HTTP 2xx, a suíte conferiu `totalNotifications = mappedNotificationsTotal + unmappedNotificationsTotal` quando o endpoint fornece esses campos e garantiu que o ranking não excede o total mapeado. A suíte consulta a API real por município; não é uma afirmação de que cada município foi manualmente aberto em uma aba.

Uma rodada anterior terminou com 4.747 passagens e falhas após a expiração do access token de 15 minutos durante o teste longo; as respostas eram 401. O teste foi repetido com novo login real, sem alteração de código entre as rodadas, e concluiu com 5.571/5.571.

Aceitação visual real:

- `tests/live-acceptance.spec.ts`: SIFA/Cachoeiro, bairro nominal, quatro larguras e renovação real.
- Resultado final: **4 passed** com credenciais reais; a rodada sem credenciais marcou apenas o cenário autenticado como skip.
- Smoke/cache/dashboard local: **28 passed**.

Prints revisados manualmente:

- [/tmp/nss-sifa-cachoeiro-real.png](/tmp/nss-sifa-cachoeiro-real.png)
- [/tmp/nss-cachoeiro-neighborhoods-real-after.png](/tmp/nss-cachoeiro-neighborhoods-real-after.png)
- [/tmp/nss-cachoeiro-390.png](/tmp/nss-cachoeiro-390.png)
- [/tmp/nss-cachoeiro-768.png](/tmp/nss-cachoeiro-768.png)
- [/tmp/nss-cachoeiro-1024.png](/tmp/nss-cachoeiro-1024.png)
- [/tmp/nss-cachoeiro-1440.png](/tmp/nss-cachoeiro-1440.png)

O print de bairro revisado mostra o polígono ampliado, pontos discretos, ranking limitado e `TIJUCA (sem polígono)` sem deslocamento artificial.

## Testes de código e infraestrutura

- Java Maven (rodada final): **113 testes, 0 falhas**.
- Pipeline CNES/mapeamento/geocodificação (rodada final): **87 testes, 0 falhas** e **36 testes, 0 falhas** na rodada complementar.
- Frontend de produção: `npm run build` concluído; o bundler emitiu apenas o aviso já conhecido de chunk principal acima de 500 kB.
- Imagem do pipeline: conferidos **13 candidatos CNES web únicos** dentro da imagem `nss-pipeline:local`.
- PostgreSQL real: consultas de reconciliação para SIFA e DENG executadas.
- Redis real: saúde dos três serviços e TTL de refresh verificados.
- Containers `java`, `db`, `redis`, `redis-rate-limit`, `redis-analytics`, `frontend` e Caddy saudáveis após a recriação.

## Parquets SINAN 2025

O catálogo PySUS 2.11.7 foi consultado para os 49 grupos. Foram baixados e verificados **45 Parquets**, totalizando **167.697.284 bytes**, sem falhas. Não foi criado arquivo vazio para grupo sem fonte.

Indisponíveis no catálogo 2025: `HEPA`, `INFL`, `PFAN`, `SDTA`. O resumo reprodutível está em `/home/dock/dev/nss-pipeline/data/source/sinan/download-summary-2025.json`, e o comando foi versionado em `/home/dock/dev/nss-pipeline/scripts/download_viable_sinan.py`.

## CNES ausente na Bronze e busca web

No recorte DENG/2026 havia 150 códigos não vinculados: `0000000` é sentinela; 149 foram pesquisados individualmente; 13 tiveram página pública inequívoca e 136 não tiveram página direta suficiente.

Os 13 candidatos foram incorporados em `/home/dock/dev/nss-pipeline/territories/reference/cnes_google_candidates.csv`. O pipeline só acrescenta esses registros quando o código não existe na fotografia oficial CNES; não sobrescreve CNES oficial, não inventa latitude/longitude e deixa a geocodificação posterior como `UNRESOLVED`. O resultado web é evidência de recuperação de metadado, não confirmação de cadastro atual. A lista original dos 150 está em [RELATORIO_BUSCA_GOOGLE_150_UNIDADES_CNES_2026-11-15.md](RELATORIO_BUSCA_GOOGLE_150_UNIDADES_CNES_2026-11-15.md).

## Commits desta validação

- Front: `79aabfd0`, `bb40cd6e`, `e75479ed`, `11ed19fc`, `c09f55ff`, `4ee1eeba`, `638637f7`, `b68ddceb`.
- Java: `473dd78`.
- Pipeline: `bb0a0d21`, `5363d418`.
- Deployment/auth: `d73646d`, `ef2f859`, `9ed95b1`.

## Limitações explicitamente mantidas

- A API de cobertura ainda retorna totais e status, não uma taxonomia de motivos por linha; a causa específica da SIFA foi confirmada pela Bronze/Gold e não inferida somente do status.
- Uma página pública de busca não é prova suficiente para substituir a ficha oficial CNES; por isso os candidatos web não recebem coordenada automática.
- A suíte nacional é uma validação de contrato API por município. A validação visual é representativa e cobre SIFA/Cachoeiro, bairros com e sem polígono e as quatro larguras críticas.

## Hibernação

Ainda não executar `systemctl hibernate` antes da revisão final do operador. A execução deve ocorrer somente depois de confirmar que não há outra carga ou investigação ativa no Compose e que os artefatos deste relatório foram preservados.
