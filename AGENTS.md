# Regras de execução do NSS

- Trabalhe na etapa aprovada em ambiente isolado. Preserve alterações existentes e não troque o ambiente ativo sem aprovação explícita.
- Registre critérios de aceite antes de alterar comportamento. Mudanças em contratos de schema, autenticação ou interpretação epidemiológica exigem aprovação.
- Use revisão independente de QA em modo de leitura. Para metas de desempenho, solicite revisão independente da comparação e da evidência.
- Rode as verificações relevantes ao diff. Use PostgreSQL e Redis reais para os contratos críticos e testes de mutação dirigidos quando aplicáveis. Verificações não executadas ficam pendentes.
- Compare alternativas no mesmo snapshot e nas mesmas condições. Confirme paridade antes de medir desempenho.
- Registre no PR os comandos, resultados, achados e limitações. As verificações obrigatórias devem passar na revisão integrada. Não reduza critérios para contornar falhas.

## Deployment

Orquestre o job do NSS-database antes dos consumidores. Preserve a topologia configurada e receba credenciais do ambiente. Use um projeto Compose distinto do ambiente ativo e valide a configuração efetiva.

## Ferramentas no NixOS

Antes de instalar dependências no sistema, procure um `flake.nix` aplicável e use o ambiente declarado. Quando o pacote não estiver no flake, execute a verificação de forma efêmera com `nix-shell -p <pacote> --run '<comando>'` (ou `nix shell nixpkgs#<pacote> --command <comando>`). Registre o comando e a versão efetivamente usada; não altere a configuração ativa do host.

## Escopo aprovado desta fase

- Todos os testes de integração, E2E e deployment desta fase usam o projeto descartável `nss-v1`.
- É permitido apagar e recriar o banco/volumes do `nss-v1` e aplicar diretamente o schema atual. Compatibilidade com cada commit anterior e migrations de upgrade não são critérios desta fase: não há primeira versão publicada com backend.
- O critério é o snapshot atual funcionar de forma coerente e segura, preservando autenticação, autorização, integridade, contratos e limites de confiança. O ambiente ativo não deve ser alterado.
- DT-10, DT-11 e DT-13 ficam por último, após a convergência técnica e a definição de marca/conteúdo; não bloquearão os testes técnicos intermediários.
- Em colisões de Compose, use `NSS_HTTP_PORT`, `NSS_REDIS_PORT` e `NSS_PROXY_SUBNET`/`NSS_PROXY_IP_RANGE`/`NSS_PROXY_GATEWAY`/`NSS_PROXY_CADDY_IP` apenas no `nss-v1` descartável para isolar portas e rede; não altere a topologia do ambiente ativo.
