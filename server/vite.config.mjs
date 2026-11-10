import {defineConfig} from 'vite';
import {cloudflare} from '@cloudflare/vite-plugin';
export default defineConfig(({command})=>({
 publicDir:'../build/web',
 build:{outDir:'../dist',emptyOutDir:true},
 plugins:[cloudflare({viteEnvironment:{name:'server'},inspectorPort:false,config:command==='serve'?{vars:{LOCAL_DEMO:'true'}}:undefined})]
}));
