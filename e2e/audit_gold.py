"""Read-only snapshot gate, executed inside the deployment pipeline container."""
import json
from pathlib import Path
import pandas as pd
from sqlalchemy import text
from app.pipeline.load import FACT_KEY_COLUMNS, _prepare_fact_frame, get_engine


def canonical(frame, keys):
    result = frame[keys + ['cases_total']].copy()
    for key in keys:
        result[key] = result[key].map(lambda x: '<NULL>' if pd.isna(x) else str(x))
    return result.groupby(keys, dropna=False).cases_total.sum().sort_index()


def main():
    engine = get_engine()
    with engine.connect() as connection:
        connection.execute(text('SET TRANSACTION READ ONLY'))
        database = connection.execute(text('SELECT current_database()')).scalar_one()
        assert database == 'situacao_saude', 'Unexpected database'
        facts = pd.read_sql(text('SELECT * FROM analytics.fato_casos'), connection)
        pubs = pd.read_sql(text('SELECT * FROM analytics.pipeline_publications'), connection)
    engine.dispose()
    facts = facts.rename(columns={'ano': 'year', 'mes': 'month'})
    latest = {}
    for path in Path('/data/gold/serving').rglob('data.parquet'):
        parts = dict(p.split('=', 1) for p in path.parts if '=' in p)
        key = (parts['disease'].upper(), int(parts['source_year']))
        batch = parts['batch_id']
        if key not in latest or batch > latest[key][0]:
            latest[key] = (batch, path)
    assert latest, 'No Gold Serving snapshots'
    report = {'database': database, 'passed': True, 'snapshots': []}
    for (disease, year), (batch, path) in sorted(latest.items()):
        metadata = json.loads(path.with_name('metadata.json').read_text())
        cnes_snapshot = metadata.get('cnes_snapshot')
        cnes_present = bool(cnes_snapshot and Path(cnes_snapshot).is_file())
        gold = _prepare_fact_frame(pd.read_parquet(path), disease, batch)
        actual = facts[(facts.disease_codigo == disease) & (facts.year == year)]
        pub = pubs[(pubs.disease_codigo == disease) & (pubs.ano == year) & (pubs.batch_id == batch)]
        full_match = canonical(gold, FACT_KEY_COLUMNS).equals(canonical(actual, FACT_KEY_COLUMNS))
        keys = [k for k in FACT_KEY_COLUMNS if k not in
                ('notification_district_id', 'notification_neighborhood_id')]
        pub_match = not pub.empty and int(pub.cases_total.sum()) == int(gold.cases_total.sum())
        batch_match = set(actual.batch_id) <= {batch}
        report['snapshots'].append({
            'disease': disease, 'year': year, 'batch': batch,
            'gold_rows': len(gold), 'postgres_rows': len(actual),
            'gold_total': int(gold.cases_total.sum()), 'postgres_total': int(actual.cases_total.sum()),
            'cnes_snapshot_present': cnes_present,
            'all_keys_match': full_match, 'publication_totals_match': pub_match,
            'batch_match': batch_match,
            'nonterritorial_keys_match': canonical(gold, keys).equals(canonical(actual, keys))})
        report['passed'] &= full_match and pub_match and batch_match and cnes_present
    report['postgres_scopes_without_gold'] = sorted(set(zip(facts.disease_codigo, facts.year)) - set(latest))
    report['passed'] &= not report['postgres_scopes_without_gold']
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
