"""Valida apenas consistência documental; não é teste de integração."""
import re
from pathlib import Path
import yaml

root=Path(__file__).resolve().parent
rfc=(root/'RFC_NSS_v1_5_consolidado.md').read_text(encoding='utf-8')
manual=(root/'Manual_Marca_NSS_v1_1.md').read_text(encoding='utf-8')
sql=(root/'migrations/0003_0006_domains.sql').read_text(encoding='utf-8')
spec=yaml.safe_load((root/'contracts/openapi-nss-v1.5.yaml').read_text(encoding='utf-8'))
assert spec['openapi']=='3.1.0'
assert len(spec['paths'])>=50
assert sum(len(p) for p in spec['paths'].values())>=60
assert len(set(spec['paths']))==len(spec['paths'])
for i in range(1,33): assert f'AUD-{i:03d}' in rfc, i
for i in range(1,21): assert f'P-{i:02d}' in rfc, i
for i in range(1,10): assert f'T-{i:02d}' in rfc, i
for i in range(2,14): assert f'DT-{i:02d}' in rfc, i
for i in range(1,23): assert f'TST-AUD-{i:03d}' in rfc, i
for schema in ['identity','cms','bulletins','municipal','veterinary','messaging','institutional','operational','audit']:
    assert f'CREATE SCHEMA IF NOT EXISTS {schema}' in sql, schema
assert 'VET_NOTIFICATION_RECEIPT' in manual and 'VET_NOTIFICATION_RECEIPT' in rfc
refs=re.findall(r'\$ref: (#/components/(?:schemas|responses|securitySchemes)/[A-Za-z0-9_]+)', (root/'contracts/openapi-nss-v1.5.yaml').read_text(encoding='utf-8'))
for p in refs:
    _,_,cat,name=p.split('/')
    assert name in spec['components'][cat], p
for p,methods in spec['paths'].items():
    assert p.startswith('/api/'),p
    for method,op in methods.items():
        assert 'responses' in op and 'security' in op,(p,method)
        if 'requestBody' in op:
            for c in op['requestBody']['content'].values(): assert 'schema' in c
            if 'multipart/form-data' in op['requestBody']['content']: assert method=='post'
print(f"Validação documental OK: {len(spec['paths'])} caminhos, {sum(map(len,spec['paths'].values()))} operações, {len(spec['components']['schemas'])} schemas; 32 achados e 22 testes rastreados.")
