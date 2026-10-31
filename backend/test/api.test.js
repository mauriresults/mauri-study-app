import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

const db = {
  prepare(sql) {
    return {
      bind(...args) { this.args = args; return this; },
      async all() {
        if (sql.includes('FROM levels')) return { results: [{ id: 'bac', name_ar: 'البكالوريا' }] };
        return { results: [] };
      },
      async first() { return null; },
    };
  },
};
const env = { DB: db };
const request = (path, opts) => new Request('https://app.example' + path, opts);

test('health responds independently of site services', async () => {
  const res = await worker.fetch(request('/v1/health'), env);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).service, 'mauri-study-app-api');
  assert.equal(res.headers.get('Access-Control-Allow-Origin'), '*');
});

test('catalog includes taxonomy and no fictional files', async () => {
  const res = await worker.fetch(request('/v1/catalog'), env);
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.equal(body.levels[0].id, 'bac');
  assert.deepEqual(body.resources, []);
});

test('API rejects public writes', async () => {
  const res = await worker.fetch(request('/v1/resources', { method: 'POST' }), env);
  assert.equal(res.status, 405);
});

test('unpublished or missing files cannot be downloaded', async () => {
  const res = await worker.fetch(request('/v1/files/123'), env);
  assert.equal(res.status, 404);
});

test('incorrect requests do not expose internals', async () => {
  const res = await worker.fetch(request('/admin'), env);
  assert.equal(res.status, 404);
});

test('published PDF supports full download and checksum metadata', async () => {
  const pdf = new TextEncoder().encode('%PDF-1.7\nhello study');
  const row = { id: 7, object_key: 'bac/d/test.pdf', file_size: pdf.length, subject_id:'bac-d-math',
    title_ar:'مذكرة اختبار', title_fr:'Test', kind:'lesson', exam_year:null,
    sha256:'abc', updated_at:'2026-10-31' };
  const mockDB = { prepare: () => ({ bind() { return this; }, async first() { return row; } }) };
  const mockFiles = { async head() { return {size:pdf.length,httpEtag:'"etagtest"'}; }, async get(key, opts) {
    assert.equal(key, 'bac/d/test.pdf');
    const bytes = opts?.range ? pdf.slice(opts.range.offset,opts.range.offset+opts.range.length) : pdf;
    return {size:pdf.length,httpEtag:'"etagtest"',body:new Response(bytes).body};
  }};
  const response = await worker.fetch(request('/v1/files/7'), {DB:mockDB,FILES:mockFiles});
  assert.equal(response.status,200);
  assert.equal(response.headers.get('Content-Type'),'application/pdf');
  assert.equal(response.headers.get('Access-Control-Allow-Origin'),'*');
  assert.equal((await response.arrayBuffer()).byteLength,pdf.length);
});

test('range requests return exactly the requested bytes', async () => {
  const pdf = new TextEncoder().encode('%PDF-1.7-0123456');
  const mockDB = { prepare: () => ({ bind() {return this;}, async first() {return {object_key:'safe-file.pdf'};} }) };
  const mockFiles = { async head() { return {size:pdf.length}; }, async get(key,opts) {
    assert.equal(key,'safe-file.pdf');
    const data=opts?.range?pdf.slice(opts.range.offset,opts.range.offset+opts.range.length):pdf;
    return {size:pdf.length,body:new Response(data).body};
  }};
  const res=await worker.fetch(request('/v1/files/2',{headers:{Range:'bytes=0-3'}}),{DB:mockDB,FILES:mockFiles});
  assert.equal(res.status,206);
  assert.equal(res.headers.get('Content-Range'),`bytes 0-3/${pdf.length}`);
  assert.equal(await res.text(),'%PDF');
  const bad=await worker.fetch(request('/v1/files/2',{headers:{Range:'bytes=999-1000'}}),{DB:mockDB,FILES:mockFiles});
  assert.equal(bad.status,416);
});

test('no private storage object keys are exposed through resource JSON', async () => {
  const row={id:1,object_key:'private/location.pdf',subject_id:'bac-d-math',title_ar:'درس',title_fr:'',kind:'lesson',exam_year:null,file_size:900,sha256:'x',updated_at:'now',published:1};
  const mockDB={prepare:()=>({bind(){return this;},async first(){return row;}})};
  const res=await worker.fetch(request('/v1/resources/1'),{DB:mockDB});
  const json=await res.json();
  assert.equal(res.status,200);
  assert.equal(json.object_key,undefined);
});

const fileFixture = () => {
  const bytes = new TextEncoder().encode('%PDF-1.7-0123456');
  const calls = [];
  return {
    bytes, calls,
    env: {
      DB: {prepare: () => ({bind() {return this;},async first() {return {id:1,object_key:'fixture.pdf'};}})},
      FILES: {
        async head() {return {size:bytes.length,etag:'version1',httpEtag:'"version1"'};},
        async get(key, opts) {
          calls.push({key,opts});
          const part = opts.range ? bytes.slice(opts.range.offset,opts.range.offset + opts.range.length) : bytes;
          return {body:new Response(part).body};
        }
      }
    }
  };
};

test('HEAD never opens an R2 body and ignores Range', async () => {
  const {env,calls,bytes} = fileFixture();
  const res = await worker.fetch(request('/v1/files/1',{method:'HEAD',headers:{Range:'bytes=0-4'}}),env);
  assert.equal(res.status,200);
  assert.equal(res.headers.get('content-length'),String(bytes.length));
  assert.equal(await res.text(),'');
  assert.equal(calls.length,0);
  const json = await worker.fetch(request('/v1/health',{method:'HEAD'}),env);
  assert.equal(await json.text(),'');
});

test('suffix range is served with a single body read and version guard', async () => {
  const {env,calls,bytes} = fileFixture();
  const res = await worker.fetch(request('/v1/files/1',{headers:{Range:'bytes=-4'}}),env);
  assert.equal(res.status,206);
  assert.deepEqual(new Uint8Array(await res.arrayBuffer()),bytes.slice(-4));
  assert.equal(calls.length,1);
  assert.deepEqual(calls[0].opts.onlyIf,{etagMatches:'version1'});
});

test('conditional requests avoid a download; stale If-Range sends a full file', async () => {
  const {env,calls,bytes} = fileFixture();
  const cached = await worker.fetch(request('/v1/files/1',{headers:{'If-None-Match':'W/"version1"'}}),env);
  assert.equal(cached.status,304);
  assert.equal(calls.length,0);
  const fresh = await worker.fetch(request('/v1/files/1',{headers:{Range:'bytes=0-4','If-Range':'"old"'}}),env);
  assert.equal(fresh.status,200);
  assert.equal((await fresh.arrayBuffer()).byteLength,bytes.length);
});

test('invalid and multipart ranges are rejected without reading the object body', async () => {
  const {env,calls} = fileFixture();
  for (const range of ['bytes=-0','bytes=0-1,3-4','bytes=9007199254740993-','bytes=99-100']) {
    const res = await worker.fetch(request('/v1/files/1',{headers:{Range:range}}),env);
    assert.equal(res.status,416);
  }
  assert.equal(calls.length,0);
});

test('invalid pagination cursors are rejected', async () => {
  for (const cursor of ['-1','abc','1.5','9007199254740993']) {
    const res = await worker.fetch(request(`/v1/resources?after=${cursor}`),env);
    assert.equal(res.status,400);
  }
});


test('taxonomy-only catalog does not issue a redundant resources query', async () => {
  const queries = [];
  const customDb = { prepare(sql) {
    queries.push(sql);
    return { async all() { return {results: []}; } };
  }};
  const res = await worker.fetch(request('/v1/catalog?taxonomy_only=1'), {DB:customDb});
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.deepEqual(body.resources, []);
  assert.equal(queries.length, 3);
  assert.ok(queries.every(q => !q.includes('FROM resources')));
});

test('resource pagination supports 500 items per call', async () => {
  let limit;
  const customDb={prepare() {return {bind(...args) {limit=args.at(-1);return this;},async all(){return {results:[]};}};}};
  const res=await worker.fetch(request('/v1/resources?limit=500'),{DB:customDb});
  assert.equal(res.status,200);
  assert.equal(limit,500);
});
