#!/usr/bin/env node
/**
 * ArkTS 构建警告归因与基线比对。
 *
 * 用法:
 *   node tools/arkts-warnings.cjs [日志路径]       # 归因并和基线比对，出现新增警告时退出码 1
 *   node tools/arkts-warnings.cjs --write-baseline # 用当前日志重写 .wolf/arkts-warnings-baseline.json
 *
 * 日志由 tools/build-api26.ps1 通过 Tee-Object 写出，是 UTF-16LE 且带 ANSI 颜色序列；
 * 部分警告行会被 PowerShell 拆成两行，这里先做重组再解析。
 */
const fs = require('fs')
const path = require('path')

const root = path.join(__dirname, '..')
const baselineFile = path.join(root, '.wolf', 'arkts-warnings-baseline.json')

const REASONS = {
  syscap: '依赖的 SystemCapability 并非所有设备具备；运行期由能力查询或 try/catch 兜底，属 SDK 元数据提示',
  'sdk-version': 'API 26 专属接口；compatibleSdkVersion=23，仅在 api>=26 时由 Materials 动态加载适配层',
  'may-throw': '平台接口声明 @throws；调用方以 try/catch 或 Promise 链捕获，函数按设计向上抛出',
  other: '未归类，需要人工判断',
}
const ACCEPTED_CATEGORIES = ['syscap', 'sdk-version', 'may-throw', 'other']

function findDefaultLog() {
  // .wolf/build-api26.log 可能来自旧构建，必须和 review 目录的日志一起按修改时间取最新。
  const candidates = [path.join(root, '.wolf', 'build-api26.log')]
  const reviewRoot = path.join(root, '.wolf', 'review')
  if (fs.existsSync(reviewRoot)) {
    candidates.push(path.join(reviewRoot, 'build-api26.log'))
    for (const entry of fs.readdirSync(reviewRoot, { withFileTypes: true })) {
      if (entry.isDirectory()) candidates.push(path.join(reviewRoot, entry.name, 'build-api26.log'))
    }
  }
  const existing = candidates
    .filter((file) => fs.existsSync(file))
    .map((file) => ({ file, at: fs.statSync(file).mtimeMs }))
    .sort((a, b) => b.at - a.at)
  return existing.length > 0 ? existing[0].file : candidates[0]
}

function decodeLog(file) {
  const raw = fs.readFileSync(file)
  const text = raw[0] === 0xff && raw[1] === 0xfe ? raw.toString('utf16le') : raw.toString('utf8')
  return text.replace(/\u001b\[[0-9;]*[A-Za-z]/g, '')
}

function normalizeLines(text) {
  const lines = text.split(/\r?\n/)
  const merged = []
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i]
    // PowerShell 会把超长 stderr 行拆成两段，路径因此断在 "/service\ns/ReminderGroups.ets:5:48"。
    let guard = 0
    while (/ArkTS:WARN/.test(line) && !/\.ets:\d+:\d+/.test(line) && guard < 3 && i + 1 < lines.length) {
      line = line + lines[++i]
      guard++
    }
    merged.push(line)
  }
  return merged
}

function categoryOf(message) {
  if (/^The system capacity of this api '.*' is not supported on all devices/.test(message)) return 'syscap'
  if (/^The '.*' API is supported since SDK version/.test(message)) return 'sdk-version'
  if (/^Function may throw exceptions/.test(message)) return 'may-throw'
  return 'other'
}

function messageAt(lines, index) {
  // 警告消息可能排在 PowerShell 的 NativeCommandError 块之后，需跨过这些行。
  for (let i = index + 1; i < Math.min(index + 8, lines.length); i++) {
    const line = lines[i].trim()
    if (line.length === 0) continue
    if (/ArkTS:WARN/.test(line)) break
    if (/^(所在位置|\+|CategoryInfo|FullyQualifiedErrorId|node\.exe :|> hvigor)/.test(line)) continue
    if (/^\d+$/.test(line)) continue
    if (/^-{3,}$/.test(line)) break
    return line
  }
  return '(无法解析消息)'
}

function parse(file) {
  const lines = normalizeLines(decodeLog(file))
  const warnings = []
  for (let i = 0; i < lines.length; i++) {
    if (!/ArkTS:WARN/.test(lines[i])) continue
    const match = lines[i].match(/File:\s*(.+?\.ets):(\d+):(\d+)/)
    const message = messageAt(lines, i)
    const absolute = match === null ? '' : match[1]
    const marker = absolute.indexOf('entry/src/main/ets/')
    const relative = marker >= 0 ? absolute.slice(marker) : absolute
    const category = categoryOf(message)
    warnings.push({
      file: relative,
      line: match === null ? 0 : Number(match[2]),
      column: match === null ? 0 : Number(match[3]),
      message,
      category,
      reason: REASONS[category],
      key: relative + '|' + category + '|' + message,
    })
  }
  return { lines, warnings }
}

function summarize(warnings) {
  const byCategory = new Map()
  const byFile = new Map()
  const byKey = new Map()
  for (const warning of warnings) {
    byCategory.set(warning.category, (byCategory.get(warning.category) || 0) + 1)
    byFile.set(warning.file, (byFile.get(warning.file) || 0) + 1)
    const existing = byKey.get(warning.key)
    if (existing) existing.count++
    else byKey.set(warning.key, { key: warning.key, file: warning.file, category: warning.category,
      message: warning.message, reason: warning.reason, count: 1 })
  }
  return { byCategory, byFile, entries: Array.from(byKey.values()) }
}

function gitRevision() {
  try {
    return require('child_process').execSync('git rev-parse --short HEAD', { cwd: root, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim()
  } catch (_error) { return 'unknown' }
}

function writeBaseline(file, summary, warnings) {
  const payload = {
    generatedAt: new Date().toISOString(),
    revision: gitRevision(),
    log: path.relative(root, file).replace(/\\/g, '/'),
    total: warnings.length,
    categories: Object.fromEntries(Array.from(summary.byCategory.entries()).sort()),
    acceptedCategories: ACCEPTED_CATEGORIES,
    entries: summary.entries.sort((a, b) => a.key.localeCompare(b.key)),
  }
  fs.mkdirSync(path.dirname(baselineFile), { recursive: true })
  fs.writeFileSync(baselineFile, JSON.stringify(payload, null, 2) + '\n')
  return payload
}

function compare(baseline, summary) {
  const previous = new Map(baseline.entries.map((entry) => [entry.key, entry.count]))
  const added = []
  const increased = []
  let resolved = 0
  for (const entry of summary.entries) {
    const before = previous.get(entry.key)
    if (before === undefined) added.push(entry)
    else if (entry.count > before) increased.push({ entry, before })
    else if (entry.count < before) resolved += before - entry.count
  }
  for (const [key, count] of previous) {
    if (!summary.entries.some((entry) => entry.key === key)) resolved += count
  }
  return { added, increased, resolved }
}

function printReport(file, warnings, summary) {
  console.log('ArkTS 警告归因 · ' + path.relative(root, file).replace(/\\/g, '/'))
  console.log('总计 ' + warnings.length + ' 条')
  console.log('')
  console.log('按类别:')
  for (const category of ACCEPTED_CATEGORIES) {
    const count = summary.byCategory.get(category) || 0
    if (count === 0) continue
    console.log('  ' + category.padEnd(12) + String(count).padStart(4) + '  ' + REASONS[category])
  }
  console.log('')
  console.log('按文件:')
  for (const [file, count] of Array.from(summary.byFile.entries()).sort((a, b) => b[1] - a[1])) {
    console.log('  ' + String(count).padStart(4) + '  ' + file)
  }
}

function main(argv) {
  const writeMode = argv.includes('--write-baseline')
  const positional = argv.filter((arg) => !arg.startsWith('--'))
  const logFile = positional.length > 0 ? path.resolve(root, positional[0]) : findDefaultLog()
  if (!fs.existsSync(logFile)) {
    console.error('找不到构建日志: ' + logFile)
    console.error('先运行 tools/build-api26.ps1 生成日志，或显式传入日志路径。')
    return 2
  }
  const { lines, warnings } = parse(logFile)
  const summary = summarize(warnings)
  printReport(logFile, warnings, summary)
  // 构建失败时警告数没有意义：先报失败，避免“基线全绿”掩盖编译错误。
  const buildFailed = lines.some((line) => /BUILD FAILED|COMPILE RESULT:\s*FAIL/.test(line))
  if (buildFailed) {
    const errors = lines.filter((line) => /ERROR: \d+/.test(line)).slice(0, 5)
    console.log('')
    console.log('构建本身失败，警告基线不可信：')
    for (const line of errors) console.log('  ' + line.trim().slice(0, 160))
    return 3
  }

  if (writeMode) {
    const payload = writeBaseline(logFile, summary, warnings)
    console.log('')
    console.log('已写入基线 ' + path.relative(root, baselineFile).replace(/\\/g, '/') + '（' + payload.total + ' 条，revision ' + payload.revision + '）')
    return 0
  }

  if (!fs.existsSync(baselineFile)) {
    console.log('')
    console.log('基线不存在，用 --write-baseline 建立后才开始拦截新增警告。')
    return 0
  }
  const baseline = JSON.parse(fs.readFileSync(baselineFile, 'utf8'))
  const diff = compare(baseline, summary)
  console.log('')
  console.log('基线比对（' + path.relative(root, baselineFile).replace(/\\/g, '/') + '，' + baseline.total + ' 条，revision ' + baseline.revision + '）:')
  console.log('  新增 ' + diff.added.length + ' 类 / 增加 ' + diff.increased.length + ' 类 / 减少 ' + diff.resolved + ' 条')
  for (const entry of diff.added) console.log('  NEW       ' + entry.count + 'x ' + entry.file + '  ' + entry.message.slice(0, 80))
  for (const item of diff.increased) console.log('  MORE      ' + item.before + ' -> ' + item.entry.count + '  ' + item.entry.file + '  ' + item.entry.message.slice(0, 80))
  if (diff.added.length === 0 && diff.increased.length === 0) {
    console.log('  未发现新增或增多的警告。')
    return 0
  }
  console.log('')
  console.log('失败：出现基线之外的 ArkTS 警告。修复它们，或确认可接受后运行 --write-baseline 更新基线。')
  return 1
}

if (require.main === module) {
  process.exitCode = main(process.argv.slice(2))
}

module.exports = { parse, summarize, categoryOf, compare }
