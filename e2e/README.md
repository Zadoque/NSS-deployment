# E2E NSS

Estado em 2026-10-06: divergência corrigida, CNES carregado e auditoria integral
Gold/PostgreSQL aprovada. Ver [relatório](TERRITORY_REPAIR.md). Há um smoke territorial;
a suíte de 100+ testes ainda está pendente.

## Credenciais

`e2e/.env` guarda a conta fornecida exclusivamente para testes. Essa identidade e
credenciais de teste não representam cadastros reais de produção. Os dados
epidemiológicos, porém, são reais, publicados pela pipeline. Nenhum banco foi
resetado. Não copiar senha ou tokens para documentação ou testes.

`.env`, sessões, traces e resultados são ignorados pelo Git. O alvo é HTTPS via
ngrok. `.env.example` contém só as chaves e a URL pública.

## Conferência reproduzível

Na raiz do deployment:

```bash
docker compose --profile jobs run --rm -T --entrypoint python pipeline - < e2e/audit_gold.py
```

O script usa transação read-only, compara todas as chaves/medidas do último
snapshot de cada doença/ano, batch e totais das publicações. Saída 1 bloqueia
a próxima etapa. Não converte texto NaN em nulo para esconder diferenças.

## Próxima etapa

Smoke real de regressão territorial (expectativas do snapshot de 2026):

```sh
cd e2e
npm ci
npm run smoke:territory
```

Requer Chromium do Playwright instalado; em NixOS pode ser necessário fornecer
`CHROMIUM_PATH` para um Chromium compatível com o sistema.

Com a pré-condição corrigida: Playwright Test em specs/*.spec.ts, helpers para
login/navegação e oráculo SQL/Gold; global setup sem reset nem seed. Um worker,
lotes de três testes, aplicação real sem mocks. Preferir getByRole, getByLabel,
texto estável e getByTestId. Aguardar resposta correspondente aos filtros e sua
renderização. Traces não devem capturar preenchimento da senha nem ser publicados.

A matriz AUDIT.md planeja 156 cenários distintos de filtros, além de território,
período e autenticação. Planejamento não equivale a teste implementado/aprovado.
Falhas devem gerar roteiro manual com ID, objetivo, pré-condições, seleções
exatas, esperado, observado e consulta de conferência.
