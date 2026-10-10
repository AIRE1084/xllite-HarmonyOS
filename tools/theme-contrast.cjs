// Reusable token audit. Checks opaque text/surface pairs, not rendered translucent pixels.
'use strict';
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const tsFile = process.env.XJIT_TYPESCRIPT_PATH || 'D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js';
if (!fs.existsSync(tsFile)) throw new Error('Existing SDK TypeScript missing; no download attempted.');
const ts = require(tsFile), moduleObject = { exports: {} };
const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/theme/Colors.ets'), 'utf8');
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText,
  { exports: moduleObject.exports, module: moduleObject });
function luminance(hex) {
  const channels = hex.replace('#', '').match(/.{2}/g).map(s => parseInt(s, 16) / 255);
  const linear = channels.map(c => c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
  return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
}
function contrast(text, surface) { const a = luminance(text), b = luminance(surface); return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05); }
const pairs = [];
function check(theme, role, text, surface) {
  const ratio = contrast(text, surface); pairs.push({ theme, role, text, surface, ratio: +ratio.toFixed(3), pass: ratio >= 4.5 });
}
for (const [name, p] of [['light', moduleObject.exports.LightColors], ['dark', moduleObject.exports.DarkColors]]) {
  for (const surface of ['background', 'surface', 'surfaceVariant']) {
    check(name, 'body / ' + surface, p.onSurface, p[surface]);
    check(name, 'secondary / ' + surface, p.onSurfaceVariant, p[surface]);
  }
  check(name, 'primary button', p.onPrimary, p.primary);
  check(name, 'primary container', p.onPrimaryContainer, p.primaryContainer);
  check(name, 'accent button', p.onAccent, p.accent);
  check(name, 'accent container', p.onAccentContainer, p.accentContainer);
  p.courseColors.forEach((color, i) => check(name, 'course ' + (i + 1), name === 'light' ? '#FFFFFF' : '#0B0E14', color));
}
// Read the real overview palette so compact-course text is audited too.
const overview = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/WeekOverview.ets'), 'utf8');
function overviewColors(method) {
  const match = overview.match(new RegExp('private ' + method + '[\\s\\S]*?const colors: string\\[\\] = this.isDark [?] (\\[[^\\]]+\\])\\s*: (\\[[^\\]]+\\])'));
  if (!match) throw new Error('Overview palette format changed; update contrast reader.');
  return [match[2], match[1]].map(array => array.match(/#[0-9A-Fa-f]{6}/g));
}
const overviewSurface = overviewColors('courseSurface'), overviewText = overviewColors('courseText');
for (let theme = 0; theme < 2; theme++) overviewSurface[theme].forEach((color, i) =>
  check(theme === 0 ? 'light' : 'dark', 'week overview course ' + (i + 1), overviewText[theme][i], color));
const report = { checkedAt: new Date().toISOString(), scope: 'Opaque text tokens; translucent/native materials require screenshot review.', threshold: 4.5,
  minimum: Math.min(...pairs.map(p => p.ratio)), checks: pairs.length, failed: pairs.filter(p => !p.pass), pairs };
fs.mkdirSync(path.join(root, '.wolf'), { recursive: true });
fs.writeFileSync(path.join(root, '.wolf/quality-contrast.json'), JSON.stringify(report, null, 2));
console.log(report.checks + ' token contrast checks; minimum ' + report.minimum + ':1; ' + report.failed.length + ' failed.');
for (const pair of report.failed) console.error(pair);
process.exitCode = report.failed.length ? 1 : 0;
