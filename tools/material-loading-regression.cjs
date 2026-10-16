'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require('D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
function fixture(api,fail=false){
 let loads=0;const module={exports:{}};
 const source=fs.readFileSync('entry/src/main/ets/theme/Materials.ets','utf8');
 vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{module,exports:module.exports,require(s){
 if(s==='@ohos.deviceInfo')return {default:{sdkApiVersion:api}};
 if(s.endsWith('/NativeMaterials')){loads++;if(fail)throw Error('missing');return {supportsNativeMaterial:()=>true,createNativeMaterial:()=>({})};}
 throw Error('Unexpected static dependency: '+s);
 }});return {api:module.exports,loads:()=>loads};
}
(async()=>{
 const old=fixture(23);assert.equal(await old.api.loadImmersiveMaterial(),false);assert.equal(old.loads(),0);
 const modern=fixture(26);const a=modern.api.loadImmersiveMaterial(),b=modern.api.loadImmersiveMaterial();assert.equal(a,b);assert.equal(await a,true);assert.equal(modern.loads(),1);assert.equal(modern.api.supportsImmersiveMaterial(),true);
 const broken=fixture(26,true);assert.equal(await broken.api.loadImmersiveMaterial(),false);assert.equal(broken.api.supportsImmersiveMaterial(),false);
 console.log('PASS old API skips module; concurrent loads share promise; missing adapter falls back');
})().catch(e=>{console.error(e);process.exitCode=1});
