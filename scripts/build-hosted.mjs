import {spawnSync} from 'node:child_process';
import {existsSync,mkdirSync,copyFileSync,readdirSync,unlinkSync} from 'node:fs';
import {join} from 'node:path';
const run=(command,args)=>{const r=spawnSync(command,args,{stdio:'inherit'});if(r.error)throw r.error;if(r.status!==0)process.exit(r.status||1);};
// Local browser-preview symlinks must never be copied into a hosted artifact.
if(existsSync('build/web'))for(const entry of readdirSync('build/web',{withFileTypes:true}))if(entry.isSymbolicLink())unlinkSync(join('build/web',entry.name));
if(!existsSync('server/node_modules/@cloudflare/vite-plugin'))run('npm',['--prefix','server','ci','--no-audit','--no-fund']);
run('flutter',['build','web','--no-web-resources-cdn']);
run('npm',['--prefix','server','run','build']);
mkdirSync('dist/.openai',{recursive:true});copyFileSync('.openai/hosting.json','dist/.openai/hosting.json');
for(const p of ['dist/server/index.js','dist/server/wrangler.json','dist/client/index.html','dist/client/main.dart.js'])if(!existsSync(p))throw new Error(`Missing hosted output: ${p}`);
console.log('Compass Flutter assets and authenticated calendar gateway are ready.');
