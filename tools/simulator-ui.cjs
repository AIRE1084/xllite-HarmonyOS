// Reusable local emulator inspection helpers. Uses only the installed HDC and Node.
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const hdc = process.env.XJIT_HDC || 'D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const target = process.env.XJIT_EMULATOR || '127.0.0.1:5555';
const bundle = process.env.XJIT_UI_BUNDLE || 'com.xjit.app.acceptance';
const evidence = process.env.XJIT_UI_EVIDENCE || 'emulator';
if (!/^[a-z0-9-]+$/.test(evidence)) throw new Error('Invalid evidence directory');
const root = path.resolve(__dirname, '../.wolf', evidence);
const devicePrefix = '/data/local/tmp/xjit-' + evidence;
fs.mkdirSync(root, { recursive: true });
function run(...args) { return execFileSync(hdc, ['-t', target, ...args], { encoding: 'utf8', timeout: 15000, windowsHide: true }).trim(); }
function pause(ms = 450) { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms); }
function flatten(node, nodes = []) { if (node.attributes) nodes.push(node.attributes); for (const child of node.children || []) flatten(child, nodes); return nodes; }
function assertForeground() {
  const missions = run('shell', 'aa', 'dump', '-l').split('Mission ID');
  const expected = missions.some(mission => mission.includes('bundle name [' + bundle + ']') && mission.includes('app state #FOREGROUND'));
  if (!expected) throw new Error('Expected app is not foreground; no UI input sent: ' + bundle);
}
function dump(name = 'current') {
  assertForeground();
  run('shell', 'uitest', 'dumpLayout', '-p', devicePrefix + '-layout.json', '-b', bundle);
  const dest = path.join(root, 'layout-' + name + '.json');
  run('file', 'recv', devicePrefix + '-layout.json', dest);
  return flatten(JSON.parse(fs.readFileSync(dest, 'utf8').replace(/^\uFEFF/, '')));
}
function center(node) { const b = node.bounds.match(/-?\d+/g).map(Number); return [Math.round((b[0] + b[2]) / 2), Math.round((b[1] + b[3]) / 2)]; }
function find(text, name = 'current') {
  const nodes = dump(name);
  const node = nodes.find(a => a.visible !== 'false' && (a.text === text || a.hint === text || a.description === text));
  if (!node) throw new Error('Visible UI control not found: ' + text);
  return node;
}
function click(text) { guard(); const node = find(text); run('shell', 'uitest', 'uiInput', 'click', ...center(node).map(String)); pause(); }
function input(text, value) { guard(); const node = find(text); run('shell', 'uitest', 'uiInput', 'inputText', ...center(node).map(String), value); pause(); }
function guard() { if (!dump().some(a => a.bundleName === bundle)) throw new Error('Requested app is not foreground; no input sent.'); }
function key(key) { guard(); run('shell', 'uitest', 'uiInput', 'keyEvent', key); pause(); }
function swipe(fromX, fromY, toX, toY) { guard(); run('shell', 'uitest', 'uiInput', 'swipe', ...[fromX,fromY,toX,toY].map(String), '1000'); pause(700); }
function capture(name) {
  if (!/^[a-zA-Z0-9_-]+$/.test(name)) throw new Error('Invalid capture name');
  guard();
  // Fresh files avoid stale frames or trailing bytes when the device overwrites a PNG.
  const deviceCapture = devicePrefix + '-' + name + '.png';
  const dest = path.join(root, name + '.png');
  run('shell', 'rm', '-f', deviceCapture);
  run('shell', 'uitest', 'screenCap', '-p', deviceCapture);
  if (fs.existsSync(dest)) fs.unlinkSync(dest);
  run('file', 'recv', deviceCapture, dest);
  run('shell', 'rm', '-f', deviceCapture);
  const nodes = dump(name);
  console.log(name, JSON.stringify(nodes.filter(a => a.text && a.visible !== 'false').slice(0, 8).map(a => ({ text: a.text, type: a.type, bounds: a.bounds }))));
  return nodes;
}
module.exports = { run, pause, dump, find, click, input, key, swipe, capture, center, root };
