'use strict';
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const ts = require(process.env.XJIT_TYPESCRIPT_PATH || 'D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
let count = 0, failed = 0;
function test(name, run) { count++; try { run(); console.log('PASS ' + name); } catch (e) { failed++; console.error('FAIL ' + name + ': ' + e.message); } }
function materials(api, supported = true) {
  let calls = 0;
  const module = { exports: {} };
  const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/theme/Materials.ets'), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, {
    module, exports: module.exports, require(spec) {
      if (spec === '@ohos.deviceInfo') return { default: { sdkApiVersion: api } };
      if (spec === '@ohos.arkui.uiMaterial') return { default: {
        isImmersiveMaterialSupported() { calls++; if (api < 26) throw new Error('API26 invoked on old OS'); return supported; },
        getMaterialInfo() { return { state: 0 }; }, MaterialState: { DISABLE: 1 },
      } };
      throw new Error(spec);
    },
  });
  return { api: module.exports, calls: () => calls };
}
test('API23 does not call API26 native material methods', () => { const f = materials(23); assert.equal(f.api.supportsImmersiveMaterial(), false); assert.equal(f.calls(), 0); });
test('encoded API23 version does not call API26 material methods', () => { const f = materials(230000023); assert.equal(f.api.supportsImmersiveMaterial(), false); assert.equal(f.calls(), 0); });
test('API26 material checks hardware support', () => { const f = materials(26); assert.equal(f.api.supportsImmersiveMaterial(), true); assert.equal(f.calls(), 1); });
test('encoded API26 version enables native checks', () => { const f = materials(260000026); assert.equal(f.api.supportsImmersiveMaterial(), true); assert.equal(f.calls(), 1); });
test('unsupported hardware uses compatibility material', () => { assert.equal(materials(26, false).api.supportsImmersiveMaterial(), false); });
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
console.log(`${count} API23 checks, ${failed} failed`); process.exitCode = failed ? 1 : 0;
