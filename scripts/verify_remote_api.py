#!/usr/bin/env python3
"""External smoke check: public Cloudflare Workers endpoint and PDF range delivery."""
import argparse
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def get_json(url):
    with urlopen(Request(url,headers={'Accept':'application/json'}),timeout=20) as r:
        if r.status!=200:raise RuntimeError(f'{url}: HTTP {r.status}')
        return json.load(r)


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--api',default='https://mauri-study-app-api.mauri-study-app.workers.dev')
    p.add_argument('--check-download',action='store_true')
    args=p.parse_args()
    base=args.api.rstrip('/')
    try:
        health=get_json(base+'/v1/health')
        assert health.get('status')=='ok', 'Health response is not OK'
        catalog=get_json(base+'/v1/catalog')
        assert isinstance(catalog.get('levels'),list), 'Missing levels'
        data=get_json(base+'/v1/resources?limit=10')
        assert isinstance(data.get('resources'),list), 'Missing resource list'
        items=data['resources']
        print('API healthy:',base,'levels:',len(catalog['levels']),'sample documents:',len(items))
        if args.check_download:
            if not items:raise RuntimeError('Cannot check PDF: no published resources')
            url=base+'/v1/files/'+str(items[0]['id'])
            with urlopen(Request(url,headers={'Range':'bytes=0-4'}),timeout=30) as r:
                sig=r.read(5)
                if r.status!=206 or sig!=b'%PDF-':raise RuntimeError(f'PDF range is invalid: status={r.status}, signature={sig!r}')
            print('PDF 206 range download is valid')
        return 0
    except (URLError,HTTPError,AssertionError,ValueError,RuntimeError) as exc:
        print('REMOTE CHECK FAILED:',exc,file=sys.stderr)
        if isinstance(exc,HTTPError):
            print('Failed URL:',exc.url,file=sys.stderr)
            for name in ('server','content-type','cf-ray','location'):
                if exc.headers.get(name):
                    print(name+':',exc.headers[name],file=sys.stderr)
            print('Response preview:',repr(exc.read(2048).decode('utf-8',errors='replace')),file=sys.stderr)
            exc.close()
        return 1

if __name__=='__main__':sys.exit(main())
