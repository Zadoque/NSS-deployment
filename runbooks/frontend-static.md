# Publicação estática dos quatro municípios

## Preparação

1. Checkout desta branch de deployment e da branch `feat/prod-mock-real-snapshot`
   no NSS-front-end, em diretórios irmãos. Não use o front antigo de mocks sintéticos.
2. Copie `.env.example` para `.env.static` e ajuste caminho, imagens e porta.
3. Não copie senhas do PostgreSQL, JWT, SMTP ou credenciais administrativas: não
   existe backend nesta stack. Os dados analíticos são públicos e baixáveis.

```sh
docker compose --env-file .env.static -p nss-static config --quiet
docker compose --env-file .env.static -p nss-static up -d --build
docker compose --env-file .env.static -p nss-static ps
curl -f http://127.0.0.1:8080/healthz
ngrok http 127.0.0.1:8080
```

Se uma stack antiga ocupa 8080, use outra porta (por exemplo 8081) para validar.
Para substituí-la, pare seus serviços explicitamente após verificar os dados e o
procedimento de retorno. Não use `down -v`: não é necessário apagar banco ou volumes.
O serviço NixOS antigo `nss-stack` pode reiniciar a stack completa no boot; precisa
ser desativado/adaptado antes da troca definitiva. Esta branch não modifica NixOS.

No servidor com imagem pronta, use `up -d --no-build`; disponibilize previamente a
imagem no registry ou por `docker save`/`docker load`. Fixe a referência por digest
ou tag única por release. Atualizações de dados exigem nova imagem do front.

## Rotas publicadas

GET/HEAD em `/`, `/login`, `/mapa`, `/healthz`, assets tipados, cinco mapas GeoJSON
e manifest/arquivos de snapshot reconhecidos. Caddy responde 404 para qualquer
outra rota ou método sem encaminhar ao front: `/api`, `/actuator`, `/admin`,
cadastro, recuperação de senha, arquivos ocultos e POST estão bloqueados.
A configuração Nginx da imagem aplica CSP e os demais cabeçalhos. A publicação
externa deve usar HTTPS no ngrok/proxy GINFO. Loopback é o padrão do bind.
Para GINFO, mude o bind somente para a interface/IP autorizado e configure firewall
de acordo com o proxy; não abra a porta de administração do Caddy.

## Dados e validação

Snapshot agregado, sem usuários nem linhas individuais SINAN. Inclui seis agravos
de 2023–2026 nos quatro municípios; territórios são os da unidade notificadora,
não residência. Bairros somente na sede de Campos. Ausências de mapeamento
continuam explícitas. A data da publicação consta no dashboard e no manifest.

Valide login público, filtros, Campos → sede → bairros e retorno ao ranking.
Verifique `/api/v1/auth/login`, `/admin/usuarios` e um POST em `/login`: todos 404.
Confira `Content-Encoding` gzip/zstd ao baixar snapshot com Accept-Encoding.
Execute `python3 scripts/check-static-routes.py http://127.0.0.1:8080` para
verificar páginas, assets, dados e bloqueio das demais rotas e métodos.
Para rollback, volte à imagem anterior e execute novamente `up -d --no-build`.

Para parar somente esta stack: `docker compose --env-file .env.static -p nss-static stop`.
