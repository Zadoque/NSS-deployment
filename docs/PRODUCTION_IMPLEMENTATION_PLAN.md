# Plano de implementação da NSS no servidor

## Objetivo de conclusão

Deixar a aplicação implementável e atualizável no servidor por meio de uma
release reproduzível, validada por QA, sem depender de publicação em registry
externo: o deployment fixa os quatro repositórios por commit, constrói as
imagens no ambiente controlado, executa o banco antes dos consumidores,
promove somente após healthchecks e permite rollback para a release anterior.

O escopo de dados inclui IBGE, CNES e SINAN. O `update_sinan.py` continuará
sendo executado pelo NixOS às 02:30, mas o refresh do catálogo IBGE deverá ter
um serviço/timer próprio e uma ordem explícita antes dos consumidores.

## Estado atual verificado

- `feat/static-frontend-ginfo-hardware` foi integrada localmente por
  fast-forward na `main` do `nss-NixOS-Configuration`.
- A verificação `nix flake check --no-build --show-trace` passou localmente.
- A `main` local do NixOS ainda está à frente de `origin/main`; o push remoto
  depende da sessão SSH do operador e não foi presumido.
- `https://nss.uenf.br/` responde HTTP 200 com TLS válido, Caddy e nginx.
- `/healthz` responde 200; `/actuator/health` responde 404. O servidor atual
  está no modo frontend estático, não no modo integrado Java/pipeline.
- O NixOS agenda SINAN e CNES, mas ainda não agenda o refresh do catálogo IBGE.
- Os repositórios de aplicação atualmente estão em branches de validação; o
  manifesto só deverá apontar para `main` depois que cada mudança for
  integrada e os SHAs forem atualizados.

## Critérios de aceite e métricas de QA

1. **Reprodutibilidade:** 4/4 componentes possuem `repository`, `branch` e
   SHA Git válido; `nss-release.sh validate` passa e `sync` reproduz exatamente
   os SHAs do manifesto.
2. **Build:** 4/4 imagens são construídas sem erro; o modo local não depende
   de GHCR ou de registry externo.
3. **Banco:** PostgreSQL inicia do zero, roles e migrations passam, e uma
   segunda execução é idempotente; zero erros de autenticação ou banco legado.
4. **Contratos críticos:** PostgreSQL e Redis reais passam healthcheck; Java,
   pipeline e frontend respondem aos endpoints definidos; Compose efetivo é
   validado antes da execução.
5. **Integridade de release:** no modo digest, 4/4 imagens têm `RepoDigest`
   SHA-256 obtido do registry local; a release anterior permanece disponível.
6. **Dados:** IBGE, CNES e SINAN executam com lock comum, são idempotentes,
   registram catálogo/SHAs e expõem sucesso ou falha no systemd.
7. **Runner:** somente `main` do deployment dispara produção, há concorrência
   serializada, logs não expõem secrets e uma falha interrompe a promoção.
8. **Rollback:** o teste controlado retorna à release anterior e à geração
   NixOS anterior sem apagar o banco ou os volumes persistentes.

## Plano por fases

### 0. Baseline e integração da configuração

- Revisar o merge local da branch estática e publicar a `main` do NixOS.
- Manter `deployment.mode = "static"` até o perfil integrado passar pelos
  critérios; não alterar o host ativo durante o desenvolvimento.
- Fazer backup da configuração, banco, manifesto e dados persistentes antes da
  primeira promoção.
- Registrar a geração NixOS, os containers, portas, timers e o resultado HTTP
  do baseline.

### 1. Manifesto de release

- Manter `releases.yaml` no deployment com os quatro repositórios.
- Tratar `commit` como referência efetiva e `branch` como origem/auditoria.
- Fazer PR no deployment para atualizar apenas os SHAs que foram testados.
- O runner deve fazer checkout dos commits fixados; caminhos locais ficam
  somente em variáveis do servidor.

### 2. Build local e digest opcional

- Manter `local-build` como caminho padrão, sem serviço externo.
- Corrigir o contrato do preflight para aceitar imagem com tag somente quando
  `NSS_PIPELINE_IMAGE_MODE=local-build` estiver declarado explicitamente.
- Adicionar `digest` como modo opcional: taggear, publicar no registry local,
  obter `RepoDigest` e atualizar a release somente após QA.
- O registry deve ficar restrito ao host/rede de administração, persistir em
  volume próprio e não receber credenciais no Git ou nas imagens.

### 3. Dados e IBGE

- Criar no NixOS um serviço/timer de refresh IBGE com URL, ano, catálogo e
  checksum configuráveis.
- Promover o novo catálogo de forma atômica; manter o anterior para rollback.
- Executar SINAN às 02:30 usando `--catalog-root /data/reference/ibge`.
- Executar CNES sob o mesmo lock operacional e registrar o catálogo IBGE usado.
- Testar refresh, repetição, checksum inválido, catálogo ausente e rollback.

### 4. Runner orientado a eventos

- Usar runner self-hosted no servidor, conectado de saída ao GitHub; não é
  necessário polling nem porta de entrada.
- Disparar produção apenas após `push`/merge na `main` do deployment.
- O workflow sincroniza os quatro commits, constrói os componentes alterados,
  executa QA, aplica database → pipeline → Java → frontend e faz smoke test.
- Usar `concurrency` para impedir duas releases simultâneas e preservar logs
  e artefatos de diagnóstico.

### 5. Promoção no servidor

```text
git fetch origin main
git switch --detach origin/main
sudo nixos-rebuild test --flake /etc/nixos#nss
systemctl list-timers 'nss-*'
systemctl status nss-stack.service
curl --fail https://nss.uenf.br/healthz
sudo nixos-rebuild switch --flake /etc/nixos#nss
```

Na primeira implantação integrada, executar o bootstrap em janela controlada,
validar logs/healthchecks e só então trocar o host de estático para integrado.
Em falha, voltar à geração NixOS anterior e ao SHA da release anterior.

## Evidências obrigatórias no PR

Registrar comandos, duração, commits dos quatro componentes, tags/digests,
resultado de `flake check`, Compose config, testes de PostgreSQL/Redis reais,
healthchecks HTTP, timers IBGE/CNES/SINAN, catálogo ativo, batch CNES,
manifestos SINAN e resultado do rollback de ensaio.

## Pendências ordenadas

1. Publicar a `main` local do NixOS após autenticar o SSH.
2. Atualizar `releases.yaml` para SHAs de `main` após os merges dos quatro
   repositórios.
3. Criar os segredos no servidor e habilitar o registry/runner no host.
4. Ensaiar a publicação de `RepoDigest` e a execução do workflow no runner.
5. Ensaiar a implantação integrada e só depois promover o servidor.

## Implementação já validada localmente

- `nss-NixOS-Configuration`: dependências do host, registry loopback,
  runner self-hosted e timer IBGE estão implementados; o `nix flake check`
  passa inclusive com esses recursos habilitados no cenário de avaliação.
- `NSS-deployment`: manifesto, verificador de dependências, workflow de
  `main`, modo não interativo e publicador local de quatro imagens estão
  implementados; validação sintática Bash, Compose preflight e manifesto
  passaram.
- `NSS-pipeline`: `local-build` é aceito somente quando explícito; o modo
  padrão continua exigindo digest; 30 testes de preflight passaram.
