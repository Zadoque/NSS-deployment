# Relatório de validação do pacote RFC v1.5 — 20/11/2026

## Verificações efetivamente realizadas

1. Leitura do RFC v1.4 e Manual v1.0 disponíveis na Library; análise da auditoria HTML recebida.
2. Inspeção remota de branches GitHub NSS, SHAs, árvores e arquivos selecionados, com correção explícita de falsos positivos parciais.
3. Geração e parsing de `contracts/openapi-nss-v1.5.yaml` por PyYAML: 58 caminhos, 61 operações, 45 schemas; todos os `$ref` internos declarados; operações com resposta/segurança especificadas.
4. Verificação de existência dos blocos `P-01..P-20`, `T-01..T-09`, `DT-02..DT-13`, rastreabilidade `AUD-001..032` e testes `TST-AUD-001..022` no RFC v1.5.
5. Criação de DDL de referência com nove novos schemas, histórico e índices parciais (análise estática; não aplicado a banco).
6. DOCX e PDF compilados; verificação de limites dos blocos de texto do PDF (nenhum retângulo de texto fora da página), inspeção visual de amostras da capa, diagramas e tabelas.

## Não executado — deve preceder merge/go-live

- Banco PostgreSQL real, parsing/execução das migrations, Testcontainers ou jobs da CI.
- Simulação de duas transações administrativas concorrentes, admissão de login paralela e revogação de grants durante requests.
- Integração empírica de Gold ESPORO à branch nacional e consolidação de privilégios SQL.
- End-to-end Playwright, HTML e-mails reais, SMTP de teste, Antivírus, carga e SLO de p95.
- Teste de restauração de dados e mídia em host independente com comparação integral de SHA-256.
- Aprovação de fonte veterinária, marca visual, nomes de unidades, sigla LRB, políticas de privacidade, retenção e operação TI.

## Advertências de implementação

- `migrations/0003_0006_domains.sql` é esquema de **referência não aplicado**: não possui triggers de proteção do último Chefe Geral, mecanismos de transição de publicação em uma única função, política final de `GRANT` nem migração destrutiva animal. A implementação das invariantes é especificada no RFC e deve integrar PR/migrations.
- O OpenAPI é **contrato alvo da V1.5**, não descrição exata de toda API atualmente em produção. Os endpoints humanos existentes são preservados por adaptação aditiva.
- Tokens/TTL, 4º Redis, Gold clínica e 9 papéis são **decisões/novas tarefas**, não funcionalidades verificadas no GitHub.
- O RFC está apto a orientar desenvolvimento e testes de aceitação, **mas não atesta prontidão operacional nem conformidade jurídica certificada**.
