#!/usr/bin/env python3
"""Bounded, read-only verification of the independent public library API.

Verifies stored bytes, not just checksum metadata. Does not import or publish PDFs.
"""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def audit(base, budget):
    spent = 0

    def request(path, *, method='GET', headers=None, expected=200):
        nonlocal spent
        req = Request(base.rstrip('/') + path, method=method,
                      headers={'User-Agent':'MauriStudyAudit/0.1.0', **(headers or {})})
        try:
            response = urlopen(req, timeout=30)
        except HTTPError as error:
            response = error
        with response:
            assert response.status == expected, f'{method} {path}: HTTP {response.status}, expected {expected}'
            content = response.read(budget - spent + 1)
            spent += len(content)
            assert spent <= budget, 'Verification transfer budget exceeded'
            return dict(response.headers.items()), content

    def get_json(path):
        _, body = request(path)
        return json.loads(body)

    def header(headers, name):
        return next((value for key,value in headers.items() if key.lower() == name.lower()), None)

    assert get_json('/v1/health')['status'] == 'ok'
    taxonomy = get_json('/v1/catalog')
    assert all(isinstance(taxonomy.get(key),list) for key in ('levels','tracks','subjects'))
    resources = []
    cursor = 0
    for _ in range(1000):
        page = get_json(f'/v1/resources?limit=2&after={cursor}')
        chunk = page['resources']
        if not chunk:
            break
        assert len(chunk) <= 2
        for item in chunk:
            assert item['id'] > cursor, 'Duplicate or unordered page'
            cursor = item['id']
            resources.append(item)
        assert page['next_after'] == cursor
    else:
        raise AssertionError('Catalog exceeds verification page limit')
    assert resources, 'No published documents available for verification'
    assert sum(item['file_size'] for item in resources) * 3 < budget, 'Library exceeds verification budget'
    for endpoint in ('resources','files'):
        request(f'/v1/{endpoint}/9007199254740991', expected=404)
    request('/v1/health', method='POST', expected=405)
    verified = []
    for item in resources:
        resource_id = item['id']
        detail = get_json(f'/v1/resources/{resource_id}')
        assert detail == item
        assert not {'object_key','drive_file_id','source_url'} & detail.keys()
        size = item['file_size']
        expected_hash = item['sha256'].lower()
        path = f'/v1/files/{resource_id}'
        headers, body = request(path, method='HEAD')
        assert body == b''
        assert int(header(headers,'content-length')) == size
        assert header(headers,'accept-ranges') == 'bytes'
        assert 'max-age=' in header(headers,'cache-control')
        etag = header(headers,'etag')
        assert etag
        _, full = request(path)
        assert len(full) == size and full.startswith(b'%PDF-')
        actual = hashlib.sha256(full).hexdigest()
        assert actual == expected_hash, f'Checksum mismatch for resource {resource_id}'
        split = max(1,size // 2)
        first_headers, first = request(path, headers={'Range':f'bytes=0-{split-1}'}, expected=206)
        assert header(first_headers,'content-range') == f'bytes 0-{split-1}/{size}'
        _, remaining = request(path, headers={'Range':f'bytes={split}-','If-Range':etag}, expected=206)
        assert first + remaining == full, 'Resumed ranges differ from complete PDF'
        _, suffix = request(path, headers={'Range':'bytes=-5'}, expected=206)
        assert suffix == full[-5:]
        _, cached = request(path, headers={'If-None-Match':etag}, expected=304)
        assert cached == b''
        range_headers, _ = request(path, headers={'Range':f'bytes={size}-'}, expected=416)
        assert header(range_headers,'content-range') == f'bytes */{size}'
        verified.append({'id':resource_id,'bytes':size,'sha256':actual})
        print(f'Verified PDF {resource_id}: {size} bytes, SHA-256 and HTTP Range passed')
    return {'status':'passed','api':base,'verified_files':len(verified),
            'verified_bytes':sum(row['bytes'] for row in verified),
            'audit_http_bytes':spent,'new_files_imported':0,'files':verified}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api',default='https://mauri-study-app-api.mauri-study-app.workers.dev')
    parser.add_argument('--max-http-bytes',type=int,default=32 * 1024 * 1024)
    parser.add_argument('--report',type=Path,default=Path('api-audit-report.json'))
    args = parser.parse_args()
    try:
        report = audit(args.api,args.max_http_bytes)
    except Exception as error:
        args.report.write_text(json.dumps({'status':'failed','error':str(error)}))
        raise
    args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2) + '\n')
    print(json.dumps({key:value for key,value in report.items() if key != 'files'},ensure_ascii=False))


if __name__ == '__main__':
    main()
