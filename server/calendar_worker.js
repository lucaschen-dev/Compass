const MAX_BYTES = 512 * 1024;
const MAX_REQUEST = 8192;
const HEADERS = {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff'};
const json = (data, status=200) => new Response(JSON.stringify(data), {status, headers: HEADERS});

export function calendarUrl(value) {
  if (typeof value !== 'string' || value.length > 4096) throw new Error('Choose a valid calendar link.');
  let url;
  try { url = new URL(value.trim().replace(/^webcal:/i, 'https:')); } catch { throw new Error('Choose a valid calendar link.'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.port || url.hash) throw new Error('Use a secure calendar link without a username or password.');
  const host = url.hostname.toLowerCase();
  // Restrict egress to known hosted calendar providers, not arbitrary user DNS.
  // This also avoids private-address and DNS-rebinding targets.
  const allowed = /^[a-z0-9-]+\.myschoolapp\.com$/.test(host) || ['calendar.google.com', 'outlook.office365.com', 'outlook.live.com'].includes(host) || /^p\d+-caldav\.icloud\.com$/.test(host);
  if (!allowed) throw new Error('This calendar provider is not supported yet. You can import an .ics file.');
  return url;
}

export async function calendarResponse(request, env={}, fetcher=fetch, timeoutMs=15000) {
  const own = new URL(request.url);
  const local = env.LOCAL_DEMO === 'true' && ['127.0.0.1', 'localhost'].includes(own.hostname);
  // Sites dispatch supplies identity only after its normal private-site sign-in.
  // https://developers.cloudflare.com/workers/static-assets/binding/
  if (!local && (!request.headers.get('oai-authenticated-user-id') || !request.headers.get('oai-authenticated-user-email'))) return json({error:'Sign in to Compass to connect your calendar.'},401);
  if (request.method !== 'POST') return json({error:'Use POST.'},405);
  const origin = request.headers.get('origin');
  if (origin && origin !== own.origin) return json({error:'This request is not allowed.'},403);
  if (!request.headers.get('content-type')?.startsWith('application/json')) return json({error:'Choose a valid calendar link.'},400);
  if (Number(request.headers.get('content-length') || 0) > MAX_REQUEST) return json({error:'The request is too large.'},413);
  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(),timeoutMs);
  try {
    // Bound actual request bytes as well as declared Content-Length.
    const reader = request.body?.getReader();
    if (!reader) return json({error:'Choose a valid calendar link.'},400);
    let bodySize=0; const chunks=[];
    while (true) { const part=await reader.read(); if(part.done)break;bodySize+=part.value.byteLength;if(bodySize>MAX_REQUEST){await reader.cancel();return json({error:'The request is too large.'},413);}chunks.push(part.value); }
    const bodyBytes=new Uint8Array(bodySize);let cursor=0;for(const chunk of chunks){bodyBytes.set(chunk,cursor);cursor+=chunk.length;}
    const input=JSON.parse(new TextDecoder().decode(bodyBytes));
    const url=calendarUrl(input.url);
    // Never forward identity, browser cookies or auth headers to the provider.
    // Cloudflare Request docs: use manual redirects; error mode is unsupported.
    // https://developers.cloudflare.com/workers/runtime-apis/request/
    const response=await fetcher(url.href,{method:'GET',headers:{Accept:'text/calendar, text/plain;q=0.9'},redirect:'manual',signal:abort.signal});
    if(response.status>=300 && response.status<400)return json({error:'This link redirects. Use the direct calendar subscription link.'},422);
    if(!response.ok)return json({error:'The school calendar could not be reached. Check the link and try again.'},422);
    if(Number(response.headers.get('content-length')||0)>MAX_BYTES)return json({error:'Choose a calendar smaller than 512 KB.'},413);
    const stream=response.body?.getReader();if(!stream)return json({error:'The calendar is empty.'},422);
    let size=0;const parts=[];
    while(true){const p=await stream.read();if(p.done)break;size+=p.value.byteLength;if(size>MAX_BYTES){await stream.cancel();return json({error:'Choose a calendar smaller than 512 KB.'},413);}parts.push(p.value);}
    const bytes=new Uint8Array(size);let offset=0;for(const p of parts){bytes.set(p,offset);offset+=p.length;}
    const ics=new TextDecoder('utf-8',{fatal:true}).decode(bytes).replace(/^\uFEFF/,'').trim();
    if(!ics.startsWith('BEGIN:VCALENDAR')||!ics.endsWith('END:VCALENDAR'))return json({error:'The link did not return a calendar. Check its sharing settings.'},422);
    return json({ics,fetchedAt:new Date().toISOString()});
  }catch(error){
    if(abort.signal.aborted)return json({error:'The calendar took too long to respond. Please try again.'},504);
    return json({error:error instanceof Error && /valid calendar|secure calendar|provider is not supported/.test(error.message)?error.message:'The calendar could not be read. Check the link and try again.'},422);
  }finally{clearTimeout(timeout);}
}

export default {
 async fetch(request,env){
  const path=new URL(request.url).pathname;
  if(path==='/api/calendar')return calendarResponse(request,env);
  if(path==='/api/auth/setup'||path==='/api/auth/reset')return json({error:'Email service is not configured. No email has been sent.'},503);
  if(path==='/api/health')return json({service:'compass',calendar:true,emailConfigured:false});
  return env.ASSETS.fetch(request);
 }
};
