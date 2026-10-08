"""Smoke test somente HTTP. Uso: python3 scripts/check-static-routes.py http://127.0.0.1:8080"""
import json
import re
import sys
import urllib.error
import urllib.request
base = sys.argv[1].rstrip('/')
count = 0
def check(path, status=200, method='GET'):
    global count
    req = urllib.request.Request(base + path, method=method)
    try: response = urllib.request.urlopen(req, timeout=15)
    except urllib.error.HTTPError as error: response = error
    with response:
        assert response.status == status, (method, path, response.status, status)
        count += 1
        return response.read()
html = check('/').decode()
for path in ['/mapa','/login','/healthz']:
    check(path)
    check(path, method='HEAD')
for asset in re.findall(r'(?:src|href)="(/assets/[^\"]+)"', html): check(asset)
manifest = json.loads(check('/snapshot/manifest.json'))
for file in manifest['files'].values(): check('/snapshot/' + file['path'])
for name in ['brazil-regions','southeast-states','rj-municipalities','campos-districts','campos-neighborhoods']: check('/maps/' + name + '.geojson')
for path in ['/api','/api/v1/auth/login','/actuator/health','/admin/usuarios','/primeiro-acesso','/esqueci-senha','/redefinir-senha','/.env','/.git/config','/qualquer-rota','/maps/segredo.json','/snapshot/segredo.json','/assets/segredo.txt','/assets/../api/v1/metadata']:
    check(path,404)
for method in ['POST','PUT','DELETE','PATCH','OPTIONS']:
    check('/login',404,method)
    check('/snapshot/manifest.json',404,method)
print(f'{count} verificações HTTP aprovadas; somente páginas públicas e assets autorizados.')
