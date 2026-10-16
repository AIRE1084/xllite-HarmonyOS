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
 }});return {api:module.exports,loads:()=>loads,setFailure:value=>{fail=value}};
}
function componentFixture(){
 let source=fs.readFileSync('entry/src/main/ets/components/NativeGlass.ets','utf8');
 source=source.slice(0,source.indexOf('  build()'))+'\n}';
 source=source.replace(/@Component\s*/g,'').replace(/@(?:Prop|State)\s*/g,'').replace(/@StorageLink\([^)]*\)\s*/g,'').replace(/@BuilderParam\s*/g,'').replace('export struct NativeGlass','export class NativeGlass');
 const module={exports:{}},pending=[];
 vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{module,exports:module.exports,require(){return {supportsImmersiveMaterial:()=>false,loadImmersiveMaterial:()=>new Promise(resolve=>pending.push(resolve))}}});
 return {page:new module.exports.NativeGlass(),pending};
}
(async()=>{
 const old=fixture(23);assert.equal(await old.api.loadImmersiveMaterial(),false);assert.equal(old.loads(),0);
 const modern=fixture(26);const a=modern.api.loadImmersiveMaterial(),b=modern.api.loadImmersiveMaterial();assert.equal(a,b);assert.equal(await a,true);assert.equal(modern.loads(),1);assert.equal(modern.api.supportsImmersiveMaterial(),true);
 const broken=fixture(26,true);assert.equal(await broken.api.loadImmersiveMaterial(),false);assert.equal(broken.api.supportsImmersiveMaterial(),false);
 console.log('PASS old API skips module; concurrent loads share promise; missing adapter falls back');
 broken.setFailure(false);assert.equal(await broken.api.loadImmersiveMaterial(),true);assert.equal(broken.loads(),2);
 assert.equal(await broken.api.loadImmersiveMaterial(),true);assert.equal(broken.loads(),2);
 assert.ok(broken.api.glassMaterial(false));
 console.log('PASS failed adapter load can retry and successful load is reused');
 const f=componentFixture();f.page.aboutToAppear();f.page.aboutToDisappear();f.pending[0](true);await Promise.resolve();assert.equal(f.page.nativeSupported,false);
 f.page.aboutToAppear();f.pending[1](true);await Promise.resolve();assert.equal(f.page.nativeSupported,true);
 console.log('PASS retired glass ignores late load and reappearing glass accepts current result');
})().catch(e=>{console.error(e);process.exitCode=1});
