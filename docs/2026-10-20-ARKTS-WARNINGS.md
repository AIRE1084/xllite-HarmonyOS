# ArkTS 构建警告归因与基线（2026-10-20）

本轮把 API26 clean 构建的 ArkTS 警告从 **132 条降到 123 条**，其余 123 条逐条归类并写入可执行基线，防止后续无声增长。

## 结论

| 类别 | 条数 | 文件分布 | 判定 |
| --- | --- | --- | --- |
| `syscap` 系统能力 | 87 | LiveViewService 80、CryptoUtil 7 | SDK 元数据：接口带 `@syscap` 标签，非所有设备具备；运行期已由 try/catch 与能力查询兜底。改代码无法消除 |
| `sdk-version` 版本 | 17 | NativeMaterials 16、NativeGlass 1 | 接口标记 `@supported since 26.0.0`，而 `compatibleSdkVersion` 为 `6.1.0(23)`。仅提升最低 API 才能消除 |
| `may-throw` 抛错 | 19 | WidgetService 12、CampusCompanionService 3、CampusFormAbility 2、ReminderGroups 1、TodoReminderService 1 | 平台接口声明 `@throws`。这些函数按设计向上抛出，调用方已 catch（含 `assert.throws` 固定的契约） |
| 合计 | 123 | 9 个文件 | 另有一条“未配置 signingConfig”提示，非 ArkTS 警告 |

## 本轮实际修复的 9 条（真实缺陷，不是消音）

1. **CryptoUtil：解密失败没有阶段信息（−5）**
   `decryptSchoolCardEnvelope` 原先直接暴露加密框架的裸异常，上层 `SchoolNativeApi` 统一吞成“学校连接或响应校验未完成”。
   现在整段包在 try/catch 内，抛出 `一卡通响应解密失败：<原始信息>`，成功路径不变；同时去掉 5 条 `may-throw`。
   余下 7 条 `syscap` 属于 CryptoFramework 能力标签，无法用代码消除。

2. **CampusCompanionService.persist：快照与开关耦合（−4）**
   原先先写 `filesDir` 快照再写 `preferences` 开关：快照写失败（磁盘满、权限、损坏）会连带阻止“课程提醒/实况窗/卡片”三个开关落盘，用户看到开关被重置。
   现在两段各自 try/catch，两段都会执行，仍以第一个错误 reject，保持登录/登出聚合错误的既有语义。

3. **WidgetService.buildFormBinding：卡片创建没有兜底路径**
   卡片绑定构造异常会让 `onAddForm` 直接失败（桌面卡片创建不出来）。现在失败时回退到 `widgetData(null)` 的“待同步”状态，卡片仍能创建并提示用户打开应用同步。
   这一条**没有减少警告数**，属于顺带补的健壮性缺口，单独说明以免虚报。

## 未修复，且不在代码层修复的 104 条

`syscap`(87) 与 `sdk-version`(17) 由 `build-profile.json5` 的版本组合决定：

```json5
compatibleSdkVersion: "6.1.0(23)"   // 最低支持 API 23
targetSdkVersion: "26.0.0"
compileSdkVersion: "26.0.0"
```

- 用 `canIUse('SystemCapability.LiveView.LiveViewService')` 逐函数包裹可以把 `syscap` 压下去，但 LiveView、卡片、加密都是本应用的核心能力，真机上必然存在，加守卫只改变提示文本、不改变行为，属于为取悦 linter 改结构，没有做。
- 把 `compatibleSdkVersion` 提到 26 能让 104 条同时消失，但会放弃 API 23 设备（见 [API23-RELEASE-DESIGN.md](API23-RELEASE-DESIGN.md)）。这是产品决策，不由本轮代做。
- 现有 19 条 `may-throw` 中，WidgetService 的快照写入是**有意**抛出的：`tools/campus-companion-regression.cjs` 用 `assert.throws` 固定了“写入/改名失败保留上一份完整快照并关闭句柄”的契约，改成自己吞掉会削弱该保证。

## 可执行基线

```bash
node tools/arkts-warnings.cjs                       # 归因 + 与基线比对，出现新增警告时退出码 1
node tools/arkts-warnings.cjs --write-baseline      # 确认可接受后重写基线
npm run check:warnings                              # 同上，走 npm 入口
```

- 工具解析 `tools/build-api26.ps1` 产出的 UTF-16LE + ANSI 日志，自动重组被 PowerShell 拆断的路径行、跨过 `NativeCommandError` 噪声块。
- 基线文件 [`.wolf/arkts-warnings-baseline.json`](../.wolf/arkts-warnings-baseline.json) 按 `文件|类别|消息` 记录条数，附生成时间、git revision 与每类接受理由。
- 默认日志取 `.wolf/build-api26.log` 与 `.wolf/review/**/build-api26.log` 中最新的一份（旧日志不再被误读）。
- 验证过失败路径：注入一条不存在的警告会得到 `NEW 1x ...` 且退出码 1；当前日志比对结果为“新增 0 类 / 增加 0 类”。
- 构建本身失败时不再看警告数：日志含 `BUILD FAILED` / `COMPILE RESULT:FAIL` 会先打印前几条 `ERROR` 并返回退出码 3，避免“基线全绿”掩盖编译错误。

## 复现

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-api26.ps1 -BuildRoot 'D:\XJITApp-review-build' -EvidenceName review
node tools/arkts-warnings.cjs
```

2026-10-20 构建：`BUILD SUCCESSFUL`，0 错误，123 条 ArkTS 警告，未签名 HAP SHA-256 `F7AF1E55D4E346A97BE267EF82BE30FC7233625FB415B1A7A670C017C655E52A`（日志 [`.wolf/review/build-api26.log`](../.wolf/review/build-api26.log) 保留在本地，不入库）。

工作区被其他进程的未完成改动弄成编译失败时，可只验证自己的改动：`git archive HEAD` 导出到独立 ASCII 目录，覆上本次涉及的 `.ets`，再在该目录运行同一个构建脚本（需要补一份 `local.properties`）。2026-10-20 这样验证过一次：`BUILD SUCCESSFUL in 22 s 927 ms`、123 条警告、基线新增 0、HAP SHA-256 `770A101A4961ED4FF588E89A25EBCD9E82739DBF937C07BA42A49393195D0B78`，日志 [`.wolf/review/build-api26.isolated.log`](../.wolf/review/build-api26.isolated.log)（本地保留）。`check:warnings` 默认只读 `build-api26.log`，不会把隔离日志当工作区证据。

## 边界

- 以上是编译期静态归因。`syscap` 与 `sdk-version` 的真实影响只在没有对应能力的设备上出现，本轮未在 API 23 设备上验证实况窗、原生材质与加密落回。
- 未安装 HAP、未做真机视觉/性能验证。
- 同一轮已把过期断言改正（与警告无关的另一个问题）：`a907929` 按 2026 秋季作息把 [ClassTime.ets](../entry/src/main/ets/utils/ClassTime.ets) 改为 8 大节后，`tools/campus-companion-regression.cjs` 仍在断言 `parseSections('9-10节') === [1230,1330]`。现在断言改为逐条钉住 8 大节时段（`1-2`/`3-4`/`5-6`/`7-8`、末节 `19:25 - 20:10`）并要求 9-10 节解析失败，比原断言覆盖更多。同时补了支付入口优先级回归 `recharge prefers official transfer link over h5 and keeps a fallback`。`npm test` 现为 82+84+89+17+38+24+18+7 项全过、0 退出码。
