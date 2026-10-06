# E2E NSS

Estado em 2026-10-06: divergência corrigida, CNES carregado e auditoria integral
Gold/PostgreSQL aprovada. Ver [relatório](TERRITORY_REPAIR.md). A descoberta do
Playwright confirma 248 cenários versionados em `specs/`. A execução completa
depende da instância HTTPS configurada no arquivo local `.env`.

## Credenciais

`e2e/.env` guarda a conta fornecida exclusivamente para testes. Essa identidade e
credenciais de teste não representam cadastros reais de produção. Os dados
epidemiológicos, porém, são reais, publicados pela pipeline. Nenhum banco foi
resetado. Não copiar senha ou tokens para documentação ou testes.

`.env`, sessões, traces e resultados são ignorados pelo Git. O arquivo local pode
conter a URL HTTPS pública do ngrok para smoke externo. Para a matriz completa,
prefira o Caddy local: assim os testes não dependem da disponibilidade do túnel.
`.env.example` contém só as chaves e a URL pública.

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

Com a pré-condição corrigida: Playwright Test em `specs/*.spec.mjs`, helpers para
login/navegação e oráculo SQL/Gold; sem reset nem seed. Um worker, aplicação real
sem mocks. A sessão autenticada é compartilhada pelos cenários somente-leitura para
respeitar o limite de tentativas do backend; o cenário de logout usa sessão própria.
Preferir `getByRole`, `getByLabel`, texto estável e `getByTestId`. Aguardar resposta
correspondente aos filtros e sua renderização. Traces não devem capturar preenchimento
da senha nem ser publicados.

A matriz AUDIT.md cobre a base dos 156 cenários distintos de filtros, além de
território, período e autenticação. Confira a descoberta antes de executar:

```sh
cd e2e
npm run test -- --list
```

Para rodar a suíte contra a instância configurada:

```sh
npm run test
```

No NixOS, execute a matriz pelo Chromium temporário do Nix e force o alvo local:

```sh
XDG_CACHE_HOME=/tmp/nss-playwright-nix-cache nix-shell -p chromium --run \
  'E2E_BASE_URL=http://127.0.0.1:8080 CHROMIUM_PATH="$(command -v chromium)" npm run test'
```

Antes desse comando, inicie o deployment com seu `.env` completo e confira
`docker compose --env-file .env ps`. O ngrok continua útil para validar uma
rota pública curta, mas não é requisito para a regressão completa.

Falhas devem gerar roteiro manual com ID, objetivo, pré-condições, seleções
exatas, esperado, observado e consulta de conferência.
