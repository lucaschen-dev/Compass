import test from 'node:test';
import assert from 'node:assert/strict';
import worker,{calendarUrl,calendarResponse} from './calendar_worker.js';
const ICS='BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR';
const link='webcal://demo.myschoolapp.com/podium/feed/iCal.aspx?z=synthetic-test';
const req=(body={url:link},headers={})=>new Request('https://compass.example/api/calendar',{method:'POST',headers:{'Content-Type':'application/json','oai-authenticated-user-id':'test-owner','oai-authenticated-user-email':'owner@example.test',...headers},body:JSON.stringify(body)});

test('only known secure calendar providers are accepted',()=>{
 assert.equal(calendarUrl(link).protocol,'https:');
 for(const bad of ['https://127.0.0.1/calendar','http://demo.myschoolapp.com/feed','https://demo.myschoolapp.com.evil.test/feed','https://evil.test/feed','https://name:secret@demo.myschoolapp.com/feed','https://demo.myschoolapp.com:444/feed','https://demo.myschoolapp.com/feed#fragment'])assert.throws(()=>calendarUrl(bad));
});
test('private site identity is mandatory; service tokens alone do not grant identity',async()=>{
 let called=false;
 const r=await calendarResponse(req({}, {'oai-authenticated-user-id':'','oai-authenticated-user-email':'','OAI-Sites-Authorization':'Bearer not-an-identity'}),{},async()=>{called=true;});
 assert.equal(r.status,401);assert.equal(called,false);
});
test('valid feed is returned without caching or forwarding private headers',async()=>{
 let options;
 const response=await calendarResponse(req(),{},async(url,opts)=>{assert.equal(url.startsWith('https://demo.myschoolapp.com/'),true);options=opts;return new Response(ICS,{headers:{'Content-Type':'text/calendar'}});});
 assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'private, no-store');
 assert.deepEqual(options.headers,{Accept:'text/calendar, text/plain;q=0.9'});assert.equal(options.redirect,'manual');assert.equal((await response.json()).ics,ICS);
});
test('cross-origin requests, redirects and login HTML are rejected',async()=>{
 assert.equal((await calendarResponse(req(undefined,{origin:'https://attacker.example'}))).status,403);
 assert.equal((await calendarResponse(req(),{},async()=>new Response('',{status:302,headers:{Location:'https://127.0.0.1/'}}))).status,422);
 assert.equal((await calendarResponse(req(),{},async()=>new Response('<html>Log in</html>'))).status,422);
});
test('actual streaming size is bounded even without Content-Length',async()=>{
 let cancelled=false;
 const stream=new ReadableStream({start(c){c.enqueue(new Uint8Array(512*1024+1));},cancel(){cancelled=true;}});
 const response=await calendarResponse(req(),{},async()=>new Response(stream));
 assert.equal(response.status,413);assert.equal(cancelled,true);
});
test('timeout aborts provider fetch and returns a friendly failure',async()=>{
 const response=await calendarResponse(req(),{},(_,opts)=>new Promise((resolve,reject)=>opts.signal.addEventListener('abort',()=>reject(new Error('aborted')))),10);
 assert.equal(response.status,504);assert.equal((await response.text()).includes('synthetic-test'),false);
});
test('oversized requests and methods are rejected before fetching',async()=>{
 const huge=req({url:'x'.repeat(9000)});assert.equal((await calendarResponse(huge)).status,413);
 const get=new Request('https://compass.example/api/calendar',{headers:{'oai-authenticated-user-id':'x','oai-authenticated-user-email':'x@y'}});assert.equal((await calendarResponse(get)).status,405);
});
test('unconfigured email never claims delivery; static routes use ASSETS',async()=>{
 const email=await worker.fetch(new Request('https://compass.example/api/auth/setup'),{});assert.equal(email.status,503);assert.match((await email.json()).error,/No email has been sent/);
 const staticResponse=await worker.fetch(new Request('https://compass.example/'),{ASSETS:{fetch:async()=>new Response('Flutter index')}});assert.equal(await staticResponse.text(),'Flutter index');
});
