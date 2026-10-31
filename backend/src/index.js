/**
 * Mauri Study API: PUBLIC READ-ONLY catalog, with an optional private R2 bucket.
 * Intentionally no routes, data, dependencies or names shared with the website.
 */
const send = (data, status = 200, headers = {}) => new Response(JSON.stringify(data), {
  status, headers: {'content-type':'application/json; charset=utf-8', 'cache-control':'public, max-age=60, stale-while-revalidate=120', 'x-content-type-options':'nosniff', ...headers}
});
const error = (message, status) => send({error:message},status, {'cache-control':'no-store'});
const itemJson = (row) => ({
  id: row.id, subject_id: row.subject_id, title_ar: row.title_ar, title_fr: row.title_fr,
  kind: row.kind, exam_year: row.exam_year, file_size: row.file_size,
  sha256: row.sha256, updated_at: row.updated_at
});
const itemQuery = `SELECT id,subject_id,title_ar,title_fr,kind,exam_year,file_size,sha256,updated_at
                   FROM resources WHERE published = 1`;
function parseRange(value, total) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(value || '');
  if (!match) return null;
  if (!match[1]) {
    const suffix = Number(match[2]);
    if (!Number.isSafeInteger(suffix) || suffix <= 0 || total <= 0) return null;
    return {start: Math.max(0, total - suffix), end: total - 1};
  }
  const start = Number(match[1]);
  const end = match[2] ? Number(match[2]) : total - 1;
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || start >= total) return null;
  return {start, end: Math.min(end, total - 1)};
}
function cors(res) {
  const h = new Headers(res.headers);
  // Public read-only resources. No credentials or private user data involved.
  h.set('Access-Control-Allow-Origin','*');
  h.set('Access-Control-Allow-Methods','GET,HEAD,OPTIONS');
  h.set('Access-Control-Allow-Headers','Range,If-None-Match,If-Range');
  h.set('Access-Control-Expose-Headers','Content-Length,Content-Range,Accept-Ranges,ETag');
  return new Response(res.body,{status:res.status,headers:h});
}
export default {
  async fetch(request,env) {
    const response = await handle(request,env);
    // HEAD must never include a body, including JSON and error responses.
    return request.method === 'HEAD'
      ? new Response(null,{status:response.status,headers:response.headers})
      : response;
  }
};

async function handle(request,env) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') return cors(new Response(null,{status:204}));
    if (!['GET','HEAD'].includes(request.method)) return cors(error('Method not allowed',405));
    if (!url.pathname.startsWith('/v1/')) return cors(error('Not found',404));
    if (!env.DB) return cors(error('Database not configured',503));
    try {
      if (url.pathname === '/v1/health') return cors(send({status:'ok',service:'mauri-study-app-api',version:1}));
      if (url.pathname === '/v1/catalog') {
        const taxonomyOnly = url.searchParams.get('taxonomy_only') === '1';
        const [a,b,c,d] = await Promise.all([
          env.DB.prepare('SELECT * FROM levels ORDER BY sort_order,id').all(),
          env.DB.prepare('SELECT * FROM tracks ORDER BY sort_order,id').all(),
          env.DB.prepare('SELECT * FROM subjects ORDER BY sort_order,id').all(),
          taxonomyOnly ? Promise.resolve({results:[]}) : env.DB.prepare(`${itemQuery} ORDER BY id LIMIT 5000`).all()
        ]);
        const items = d.results.map(itemJson);
        return cors(send({version:1,levels:a.results,tracks:b.results,subjects:c.results,resources:items,
          truncated:items.length===5000},200,{'cache-control':'public, max-age=300, stale-while-revalidate=600'}));
      }
      if (url.pathname === '/v1/resources') {
        const limit = Math.min(500,Math.max(1,Number.parseInt(url.searchParams.get('limit') || '30',10) || 30));
        const afterText = url.searchParams.get('after') || '0';
        const after = Number(afterText);
        if (!/^\d+$/.test(afterText) || !Number.isSafeInteger(after)) return cors(error('Invalid cursor',400));
        const subject = url.searchParams.get('subject_id');
        const rows = await (subject
          ? env.DB.prepare(`${itemQuery} AND subject_id = ? AND id > ? ORDER BY id LIMIT ?`).bind(subject,after,limit)
          : env.DB.prepare(`${itemQuery} AND id > ? ORDER BY id LIMIT ?`).bind(after,limit)
        ).all();
        return cors(send({resources:rows.results.map(itemJson),next_after:rows.results.at(-1)?.id || null}));
      }
      const match = /^\/v1\/(?:resources|files)\/(\d+)$/.exec(url.pathname);
      if (match) {
        const id = Number(match[1]);
        if (!Number.isSafeInteger(id)) return cors(error('Invalid id',400));
        const row = await env.DB.prepare('SELECT * FROM resources WHERE id=? AND published=1').bind(id).first();
        if (!row) return cors(error('Resource not found',404));
        if (url.pathname.startsWith('/v1/resources/')) return cors(send(itemJson(row)));
        if (!env.FILES) return cors(error('File storage not configured yet',503));
        // R2 object keys never come from user input; they come from trusted catalog rows.
        // HEAD avoids opening an unused full-object stream for ranges and HEAD.
        const object = await env.FILES.head(row.object_key);
        if (!object) return cors(error('File missing from storage',404));
        const total = object.size;
        const etag = object.httpEtag;
        const ifNoneMatch = request.headers.get('If-None-Match');
        if (ifNoneMatch && (ifNoneMatch === '*' || ifNoneMatch.split(',').some(v => v.trim().replace(/^W\//,'') === etag))) {
          return cors(new Response(null,{status:304,headers:{'ETag':etag,'Cache-Control':'public, max-age=3600'}}));
        }
        // If-Range accepts our strong ETag. A stale validator requests a fresh file.
        const ifRange = request.headers.get('If-Range');
        const rangeInput = request.method === 'GET' && (!ifRange || ifRange === etag) ? request.headers.get('Range') : null;
        const range = rangeInput ? parseRange(rangeInput,total) : null;
        if (rangeInput && !range) return cors(new Response(null,{status:416,headers:{'Content-Range':`bytes */${total}`}}));
        const h = new Headers({
          'Content-Type':'application/pdf',
          'Content-Disposition':`attachment; filename="resource-${id}.pdf"`,
          'Content-Length':String(range ? range.end-range.start+1 : total),
          'Accept-Ranges':'bytes',
          'Cache-Control':'public, max-age=3600',
          'X-Content-Type-Options':'nosniff'
        });
        if (range) h.set('Content-Range',`bytes ${range.start}-${range.end}/${total}`);
        if (object.httpEtag) h.set('ETag',object.httpEtag);
        if (request.method === 'HEAD') return cors(new Response(null,{headers:h}));
        const bodyObject = await env.FILES.get(row.object_key,{
          ...(range ? {range:{offset:range.start,length:range.end-range.start+1}} : {}),
          onlyIf: {etagMatches:object.etag}
        });
        if (!bodyObject?.body) return cors(error('File changed; retry download',503));
        return cors(new Response(bodyObject.body,{status:range?206:200,headers:h}));
      }
      return cors(error('Not found',404));
    } catch (e) {
      console.error('API error',e?.message||e);
      return cors(error('Internal server error',500));
    }
}
