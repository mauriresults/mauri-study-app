#!/usr/bin/env python3
"""Resumable, safe local PDF -> R2 + D1 importer for Mauri Study.

Does not talk to the MauriResults website, nor reveal private storage keys to the app.
Install: python -m pip install -r scripts/requirements-import.txt
Required environment: CF_ACCOUNT_ID, CF_API_TOKEN, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY.

Usage: python scripts/import_library.py manifest.csv --files-root ./pdfs --publish
Run without --publish to upload and index files without making them public.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import os
import re
import sys
from pathlib import Path

_ALLOWED_KINDS = {'lesson','exam','exercise','summary','book'}
_SUBJECT = re.compile(r'^[a-z0-9][a-z0-9-]{0,80}$')
_KEY = re.compile(r'^[a-zA-Z0-9_./-]{1,900}$')


def validate_rights(row: dict) -> None:
    """Accessibility in Drive is not evidence of redistribution rights."""
    if not (row.get('rights_evidence') or '').strip():
        raise ValueError('rights_evidence is required before publication')


def verify_stored_pdf(client, bucket: str, key: str, size: int, digest: str) -> None:
    """Verify stored bytes; self-supplied SHA metadata alone proves nothing."""
    obj = client.get_object(Bucket=bucket, Key=key)
    body = obj['Body']
    checksum = hashlib.sha256()
    count = 0
    try:
        for block in iter(lambda: body.read(8 * 1024 * 1024), b''):
            checksum.update(block)
            count += len(block)
            if count > size:
                raise RuntimeError('Stored file exceeds expected size')
    finally:
        body.close()
    if count != size or checksum.hexdigest() != digest:
        raise RuntimeError('Stored file integrity check failed; not publishing')


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as fp:
        for block in iter(lambda: fp.read(8 * 1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def validate(row: dict, root: Path):
    relpath = Path((row.get('local_file') or '').strip())
    if not str(relpath) or relpath.is_absolute() or '..' in relpath.parts:
        raise ValueError('local_file must be a safe relative path')
    path = (root / relpath).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError(f'PDF not found: {relpath}')
    with path.open('rb') as fp:
        if fp.read(5) != b'%PDF-':
            raise ValueError(f'Not a PDF: {relpath}')
    key = (row.get('object_key') or '').strip()
    if not _KEY.fullmatch(key) or key.startswith('/') or '..' in key.split('/') or not key.lower().endswith('.pdf'):
        raise ValueError(f'Unsafe R2 object key: {key}')
    sid = (row.get('subject_id') or '').strip()
    if not _SUBJECT.fullmatch(sid):
        raise ValueError(f'Invalid subject_id: {sid}')
    kind = (row.get('kind') or '').strip()
    if kind not in _ALLOWED_KINDS:
        raise ValueError(f'Invalid kind: {kind}')
    year = (row.get('exam_year') or '').strip()
    if year and not 1990 <= int(year) <= 2100:
        raise ValueError('exam_year must be between 1990 and 2100')
    title = (row.get('title_ar') or '').strip()
    if not title:
        raise ValueError('title_ar is required')
    return path, key, sid, kind, int(year) if year else None, title


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest',type=Path,help='UTF-8 CSV with local_file,subject_id,title_ar,title_fr,kind,exam_year,object_key')
    parser.add_argument('--files-root',type=Path,default=Path('.'))
    parser.add_argument('--publish',action='store_true',help='Publish only after R2 upload, HEAD verification and D1 save')
    parser.add_argument('--dry-run',action='store_true')
    args = parser.parse_args()

    required=['CF_ACCOUNT_ID','CF_API_TOKEN','R2_ACCESS_KEY_ID','R2_SECRET_ACCESS_KEY']
    missing=[k for k in required if not os.environ.get(k)]
    if missing and not args.dry_run:
        print('Missing environment variables: '+', '.join(missing),file=sys.stderr)
        return 2

    with args.manifest.open(encoding='utf-8-sig', newline='') as f:
        rows=list(csv.DictReader(f))
    if not rows:
        print('No entries in CSV manifest')
        return 0

    planned=[]
    keys=set()
    for idx,row in enumerate(rows,2):
        try:
            parsed=validate(row,args.files_root)
            if args.publish:
                validate_rights(row)
            if parsed[1] in keys:raise ValueError('Duplicate object_key')
            keys.add(parsed[1]);planned.append((row,parsed))
        except Exception as exc:
            raise ValueError(f'CSV line {idx}: {exc}') from exc

    if args.dry_run:
        for row,(path,key,*_) in planned:
            print(f'OK {path} -> {key} ({path.stat().st_size} bytes)')
        print(f'Validated {len(planned)} records; no upload performed')
        return 0

    # Imports are lazy so --dry-run needs no third-party packages.
    import boto3
    import requests
    from boto3.s3.transfer import TransferConfig
    from botocore.exceptions import ClientError
    account=os.environ['CF_ACCOUNT_ID']
    bucket=os.environ.get('R2_BUCKET','mauri-study-files')
    dbid=os.environ.get('CF_D1_DATABASE_ID','124dee36-99ce-4365-8cf9-af0b01b2d1d7')
    api='https://api.cloudflare.com/client/v4/accounts/'+account+'/d1/database/'+dbid+'/query'
    session=requests.Session()
    session.headers.update({'Authorization':'Bearer '+os.environ['CF_API_TOKEN']})
    client=boto3.client('s3',endpoint_url=f'https://{account}.r2.cloudflarestorage.com',
                        aws_access_key_id=os.environ['R2_ACCESS_KEY_ID'],aws_secret_access_key=os.environ['R2_SECRET_ACCESS_KEY'],region_name='auto')
    config=TransferConfig(multipart_threshold=16 * 1024 * 1024,multipart_chunksize=16 * 1024 * 1024,max_concurrency=3)
    sql=('INSERT INTO resources(subject_id,title_ar,title_fr,kind,exam_year,object_key,file_size,sha256,published) '
         'VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(object_key) DO UPDATE SET '
         'subject_id=excluded.subject_id,title_ar=excluded.title_ar,title_fr=excluded.title_fr,'
         'kind=excluded.kind,exam_year=excluded.exam_year,file_size=excluded.file_size,'
         'sha256=excluded.sha256,published=MAX(resources.published,excluded.published),updated_at=strftime(\'%Y-%m-%dT%H:%M:%fZ\',\'now\')')
    completed=0
    for row,(path,key,subject,kind,year,title) in planned:
        size=path.stat().st_size
        digest=sha256_file(path)
        try:
            obj=client.head_object(Bucket=bucket,Key=key)
            # Skip an identical object, not merely a same-sized one.
            present=int(obj['ContentLength'])==size and obj.get('Metadata',{}).get('sha256')==digest
        except ClientError as err:
            status=err.response.get('ResponseMetadata',{}).get('HTTPStatusCode')
            if status not in (404,403): raise
            if status==403:raise RuntimeError('Access denied; check R2 bucket permissions') from err
            present=False
        if not present:
            # Never replace a key that may already be published. New content
            # must use a new object key so failed updates cannot corrupt it.
            try:
                client.head_object(Bucket=bucket,Key=key)
            except ClientError as err:
                if err.response.get('ResponseMetadata',{}).get('HTTPStatusCode') != 404:
                    raise
            else:
                raise RuntimeError(f'Object key already exists with different content: {key}')
            client.upload_file(str(path),bucket,key,ExtraArgs={'ContentType':'application/pdf','Metadata':{'sha256':digest}},Config=config)
        verify=client.head_object(Bucket=bucket,Key=key)
        if int(verify['ContentLength'])!=size or verify.get('Metadata',{}).get('sha256')!=digest:
            raise RuntimeError(f'Upload verification failed for {key}; not publishing')
        verify_stored_pdf(client,bucket,key,size,digest)
        params=[subject,title,(row.get('title_fr') or '').strip(),kind,year,key,size,digest,1 if args.publish else 0]
        reply=session.post(api,json={'sql':sql,'params':params},timeout=60)
        reply.raise_for_status()
        data=reply.json()
        if not data.get('success') or not data.get('result',[{}])[0].get('success',False):
            raise RuntimeError(f'D1 insert failed for {key}: {data.get("errors",data)}')
        completed+=1
        print(f'Indexed {completed}/{len(planned)}: {key} ({size:,} bytes) {"PUBLISHED" if args.publish else "draft"}')
    print(f'Finished: {completed} PDF files. Website resources were not accessed.')
    return 0


if __name__=='__main__':
    try:sys.exit(main())
    except Exception as exc:
        print('ERROR:',exc,file=sys.stderr)
        sys.exit(1)
