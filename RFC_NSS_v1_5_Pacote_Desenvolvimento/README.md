# Pacote de desenvolvimento NSS — RFC-NSS-001 revisão 1.5

**Data:** 20/11/2026. Este pacote fecha editorialmente as 32 lacunas registradas na auditoria do Gemini, sem pressupor que código foi modificado ou homologações institucionais aconteceram. É a especificação de implementação, não um release de software.

## Ordem de leitura e autoridade

1. `RFC_NSS_v1_5_consolidado.md` e sua versão PDF: **documento normativo principal**, requisitos P-01..P-20, T-01..T-09, DT-02..DT-13 e todos AUD-001..AUD-032;
2. `Manual_Marca_NSS_v1_1.md`: anexo normativo de marca, UI e e-mails, sujeito às aprovações indicadas;
3. `contracts/openapi-nss-v1.5.yaml`: **proposta contratual de endpoints novos**, a ser implementada e integrada sem quebra dos endpoints existentes;
4. `migrations/0003_0006_domains.sql`: **DDL de referência**, exige divisão em migrations definitivas, scripts de grants, triggers e validação transacional antes de aplicar, nunca rodar diretamente em produção;
5. `evidence/VERIFICACAO_REPOSITORIOS_2026-11-20.md`: SHAs, evidência de código e limites da auditoria;
6. `figures/arquitetura.mmd`: diagrama de arquitetura em fonte Mermaid, para preservar editabilidade;
7. `evidence/RESULTADOS_VALIDACAO_E_LIMITES.md`: procedimentos executados e trabalho que exige CI/QA/homologação;
8. `historico/`: RFC v1.4, Manual v1.0 e auditoria Gemini preservados como fontes **não normativas**;
9. `check_contracts.py`: inspeção **estática** de OpenAPI, SQL e rastreabilidade, sem executar serviços.

**Regra de precedência:** RFC v1.5 > exemplos da v1.5; contratos existentes da API humana são preservados onde não conflitarem com expansão aditiva; v1.4 e Manual v1.0 são históricos, não devem ser usados isoladamente para criar migrations.

## Como iniciar desenvolvimento

- Criar branch de implementação dedicada a partir da branch nacional verificada; congelar fixtures e contratos atuais, planejar migrations não destrutivas.
- Integrar ESPORO Gold/Load da main para a branch nacional via diff seletivo e testes de regressão.
- Primeiro construir segurança/identidade, locks e outbox. Depois CMS, clínicas/municípios, Gold clínica, boletins e QA. A ordem detalhada está no RFC.
- No repositório `NSS-database`, portar o SQL de referência em migrations numeradas com preflight, constraint tests, roles e triggers. Na API Java, transformar o OpenAPI em contrato versionado e realizar testes de implementação (`MockMvc`/Testcontainers), sem substituir controllers humanos existentes por skeletons.
- Para cada achado AUD, entregar PR com código, migration, teste positivo/negativo, métricas e rollback.

## Validação estática local

```sh
python check_contracts.py
```

Não certifica comportamento transacional, performance, legalidade, disponibilidade do SMTP, renderização de PDF do produto ou integridade de backup. Todos esses pontos exigem testes operacionais e/ou homologação formal antes da produção.
