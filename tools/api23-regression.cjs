'use strict';
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const ts = require(process.env.XJIT_TYPESCRIPT_PATH || 'D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
let count = 0, failed = 0;
const tests = [];
function test(name, run) { tests.push({name,run}); }
function materials(api, supported = true, materialState = 0, queryThrows = false) {
  let calls = 0; const logs=[];
  const module = { exports: {} };
  const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/theme/Materials.ets'), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, {
    module, exports: module.exports, require: function requireMock(spec) {
      if (spec === './NativeMaterials') {
        const native = {exports:{}};
        vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,'entry/src/main/ets/theme/NativeMaterials.ets'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{module:native,exports:native.exports,require:requireMock});
        return native.exports;
      }
      if (spec === '@ohos.hilog') return {default:{info:(...args)=>logs.push(args)}};
      if (spec === '@ohos.deviceInfo') return { default: { sdkApiVersion: api } };
      if (spec === '@ohos.arkui.uiMaterial') return { default: {
        ImmersiveMaterial: class { constructor(options) { this.options=options; } },
        ImmersiveStyle: { REGULAR: 'regular', THIN: 'thin' },
        isImmersiveMaterialSupported() { calls++; if (api < 26) throw new Error('API26 invoked on old OS'); return supported; },
        getMaterialInfo() { if (queryThrows) throw new Error('system material query failed'); return { state: materialState }; }, MaterialState: { DISABLE: 1 },
      } };
      throw new Error(spec);
    },
  });
  return { api: module.exports, calls: () => calls, logs };
}
test('API23 does not call API26 native material methods', () => { const f = materials(23); assert.equal(f.api.supportsImmersiveMaterial(), false); assert.equal(f.calls(), 0); });
test('encoded API23 version does not call API26 material methods', () => { const f = materials(230000023); assert.equal(f.api.supportsImmersiveMaterial(), false); assert.equal(f.calls(), 0); });
test('API26 material checks hardware support', async () => { const f = materials(26); assert.equal(await f.api.loadImmersiveMaterial(), true); assert.equal(f.calls(), 1); });
test('encoded API26 version enables native checks', async () => { const f = materials(260000026); assert.equal(await f.api.loadImmersiveMaterial(), true); assert.equal(f.calls(), 1); });
test('unsupported hardware uses compatibility material', async () => { assert.equal(await materials(26, false).api.loadImmersiveMaterial(), false); });
test('system-disabled API26 material falls back',async()=>{assert.equal(await materials(26,true,1).api.loadImmersiveMaterial(),false)});
test('throwing API26 material query falls back',async()=>{assert.equal(await materials(26,true,0,true).api.loadImmersiveMaterial(),false)});
test('native material caches all eight appearance combinations independently',async()=>{
 const f=materials(26);await f.api.loadImmersiveMaterial();const instances=new Set();
 for(const dark of [false,true])for(const interactive of [false,true])for(const prominent of [false,true]){
  const material=f.api.glassMaterial(dark,interactive,prominent);assert.equal(f.api.glassMaterial(dark,interactive,prominent),material);instances.add(material);
  const o=material.options;assert.equal(o.style,prominent?'regular':'thin');assert.equal(o.interactive,interactive);assert.equal(o.applyShadow,false);
  assert.equal(o.materialColor,dark?'#18203450':'#18FFFFFF');assert.equal(o.lightEffect?.color,interactive?(dark?'#A9C4FF':'#FFFFFF'):undefined);
 }
 assert.equal(instances.size,8);assert.equal(f.logs.length,8);
 assert.ok(f.logs.every(log=>log[1]==='XJITMaterial' && log[2]==='Native material created'));
});
test('minimum SDK is API23 while target and compile remain API26', () => { const p = JSON.parse(fs.readFileSync(path.join(root, 'build-profile.json5'), 'utf8')).app.products[0]; assert.equal(p.compatibleSdkVersion, '6.1.0(23)'); assert.equal(p.targetSdkVersion, '26.0.0'); });
test('compatibility glass uses native blur rather than an opaque placeholder', () => { const s = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/NativeGlass.ets'), 'utf8'); assert.match(s, /backgroundBlurStyle\(BlurStyle\./); });
function mainTabs(reduceMotion) {
  const timers = new Map(); let next = 1;
  let s = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/MainTabs.ets'), 'utf8');
  s = s.slice(0, s.indexOf('  build()')) + '\n}';
  s = s.replace(/@(?:Entry|Component)\s*/g, '').replace(/@(?:StorageLink|Watch)\([^)]*\)\s*/g, '').replace(/@State\s*/g, '').replace('struct MainTabs', 'export class MainTabs');
  const module = { exports: {} };
  vm.runInNewContext(ts.transpileModule(s, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, {
    module, exports: module.exports, require(spec) { if (spec.endsWith('/Motion')) return { Motion: { duration: { fast: 180 } }, motionDuration: n => reduceMotion ? 0 : n }; return {}; },
    setTimeout(fn) { const id = next++; timers.set(id, fn); return id; }, clearTimeout(id) { timers.delete(id); },
  });
  return { page: new module.exports.MainTabs(), timers };
}
test('reduced motion switches tabs without retaining an invisible outgoing page', () => { const f = mainTabs(true); f.page.selectTab(1); assert.equal(f.page.currentIndex, 1); assert.equal(f.page.leavingTab, -1); assert.equal(f.timers.size, 0); });
test('invalid tab index cannot hide every page', () => { const f = mainTabs(false); f.page.selectTab(99); assert.equal(f.page.currentIndex, 0); });
test('noninteger tab indices preserve the current page and create no timers',()=>{
 for(const index of [NaN,Infinity,-Infinity,0.5,1.5]) {
  const f=mainTabs(false); f.page.selectTab(index);
  assert.equal(f.page.currentIndex,0); assert.equal(f.page.leavingTab,-1); assert.equal(f.timers.size,0);
 }
});
test('rapid tab changes retire stale animation timers', () => { const f = mainTabs(false); f.page.selectTab(1); f.page.selectTab(2); assert.equal(f.timers.size, 1); [...f.timers.values()][0](); assert.equal(f.page.leavingTab, -1); });
test('outgoing tab cannot intercept incoming tab gestures', () => { const s = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/MainTabs.ets'), 'utf8'); assert.equal((s.match(/\.hitTestBehavior\(this.currentIndex === [012] \? HitTestMode.Default : HitTestMode.None\)/g) || []).length, 3); });
test('enabling reduced motion retires a pending theme reveal and clears overlay', () => {
 const timers=new Map(), values=new Map(); const module={exports:{}};
 let source=fs.readFileSync(path.join(root,'entry/src/main/ets/components/common/ThemeWash.ets'),'utf8');
 source=source.slice(0,source.indexOf('  build()'))+'\n}'; source=source.replace(/@Component\s*/g,'').replace(/@(?:StorageLink|Watch)\([^)]*\)\s*/g,'').replace(/@State\s*/g,'').replace('export struct ThemeWash','export class ThemeWash');
 vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{module,exports:module.exports,require(s){return s.endsWith('/Colors')?{getColors:()=>({background:'#fff'})}:{Motion:{duration:{base:320},curve:{decelerate:0}}};},AppStorage:{get:k=>values.get(k)},setTimeout:fn=>{timers.set(1,fn);return 1;},clearTimeout:id=>timers.delete(id)});
 const page=new module.exports.ThemeWash(); page.getUIContext=()=>({animateTo:(_o,fn)=>fn()}); page.onFlip(); assert.equal(timers.size,1);
 values.set('reduceMotion',true); page.onFlip(); assert.equal(timers.size,0); assert.equal(page.washOpacity,0);
});
test('dock scrim fully isolates scrolling glyphs below the fade edge', () => {
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/MainTabs.ets'),'utf8');
 assert.ok(source.includes("['#FF152039', 0.25]")); assert.ok(source.includes("['#FFEAF0FB', 0.25]"));
 assert.ok(source.includes('BlurTabBar({')); assert.ok(source.includes('.hitTestBehavior(HitTestMode.None)'));
});
test('flowing dock has one shared noninteractive indicator and vertical labels',()=>{
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/components/BlurTabBar.ets'),'utf8');
 assert.match(source,/Column\(\{ space: 3 \}\)/); assert.match(source,/\.translate\(\{ x: this.currentIndex \* this.itemWidth \}\)/);
 assert.match(source,/\.onAreaChange/); assert.match(source,/\.hitTestBehavior\(HitTestMode.None\)/);
 assert.match(source,/this.reduceMotion \? 0 :/); assert.ok(!source.includes('setTimeout')); assert.ok(!source.includes("'#D9E5EDFF'"));
});
test('dock selection uses a flat tint without decorative gradient border or shadow',()=>{
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/components/BlurTabBar.ets'),'utf8');
 assert.doesNotMatch(source,/\.linearGradient\(|\.shadow\(|\.border\(/);
 assert.match(source,/\.backgroundColor\(this\.isDark \? '#263B59' : '#E5EDFF'\)/);
});
test('dock spring is bypassed rather than merely zero-duration under reduced motion',()=>{
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/components/BlurTabBar.ets'),'utf8');
 assert.match(source,/this.reduceMotion \? Curve.Linear : curves.springMotion\(0.32, 0.86, 0.12\)/);
});
test('native login uses packaged mountain brand without monochrome tint',()=>{
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/LoginPage.ets'),'utf8');
 assert.match(source,/Image\(\$r\('app.media.icon'\)\)\.width\(72\)\.height\(72\)\.borderRadius\(20\)/);
 assert.ok(!source.includes("Image($r('app.media.campus_schedule'))"));
});
test('login discloses gateway credential processing separately from local storage',()=>{
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/LoginPage.ets'),'utf8');
 assert.ok(source.includes('https://xllite.sayqz.com')); assert.ok(source.includes('服务器可能为续登保留凭据'));
 assert.ok(source.includes('保存期限与删除方式尚待服务运营方确认')); assert.ok(source.includes('密码不保存在本机'));
});
test('tab content switches without crossfading two readable text surfaces',()=>{
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/MainTabs.ets'),'utf8');
 const body=source.slice(source.indexOf('  build()'),source.indexOf('  pageTransition()'));
 assert.equal((body.match(/\.animation\(/g)||[]).length,0);
});
test('dock sits lower while bottom inset never becomes negative',()=>{
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/MainTabs.ets'),'utf8');
 assert.ok(source.includes('bottom: Math.max(0, this.safeAreaBottom - 8)'));
});
(async()=>{for(const {name,run} of tests){count++;try{await run();console.log('PASS '+name)}catch(e){failed++;console.error('FAIL '+name+': '+e.message)}}console.log(`${count} API23 checks, ${failed} failed`);process.exitCode=failed?1:0;})();
