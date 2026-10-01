# Runbook - bootstrap temporário com ngrok

Objetivo: publicar a NSS 1.0 e permitir administração SSH enquanto a conectividade institucional definitiva não está liberada.

## Pré-condições

- NixOS instalado e rede de saída funcionando;
- Docker/Compose ativos;
- SSH configurado com chave pública;
- `PasswordAuthentication=false`;
- `PermitRootLogin=no`;
- agente ngrok instalado/configurado fora deste repositório;
- authtoken ngrok armazenado como segredo, nunca no Git;
- stack NSS respondendo localmente em `127.0.0.1:${NSS_HTTP_PORT}`.

## Publicação web

Valide primeiro no servidor:

```bash
curl -I http://127.0.0.1:8080/
```

Depois abra um endpoint HTTPS ngrok apontando para o Caddy local. Em uma instalação CLI compatível:

```bash
ngrok http http://127.0.0.1:8080
```

O endereço HTTPS fornecido pelo ngrok deve ser o único endereço compartilhado para a aplicação bootstrap. Não crie túneis separados para Java, PostgreSQL ou Grafana.

## SSH temporário

Antes do túnel, confirme localmente que SSH exige chave. Depois, quando a conta ngrok permitir endpoint TCP:

```bash
ngrok tcp 22
```

Conecte usando host/porta apresentados pelo ngrok e sua chave SSH privada local.

## Validação externa

De uma rede diferente da rede do servidor:

1. abra a URL HTTPS da NSS;
2. confirme Home pública;
3. acesse `/mapa` e confirme redirecionamento para login;
4. faça login;
5. valide uma consulta real;
6. confirme refresh de sessão;
7. faça logout;
8. confirme que `/mapa` volta a exigir autenticação;
9. teste SSH pelo endpoint TCP.

## Encerramento do bootstrap

Quando domínio/portas institucionais e WireGuard estiverem operacionais: valide as rotas novas, interrompa ngrok, desabilite a configuração temporária, revogue/rotacione o authtoken e registre a mudança.
