# 掌上新理工 键盘遮挡与窗口高度全局核查

**日期**：2026-10-20
**执行者**：simulator-verify（task-11）
**范围**：除 LoginPage 外的键盘遮挡风险全局核查（LoginPage 由 task-10 主修，本文仅做静态取证）
**硬约束**：只读源码，不改任何 `.ets`；模拟器实测部分待 lead 通知后补做

---

## 0. 结论速览

| 页面 | 输入控件 | 静态结论 | 实测 |
|------|---------|---------|------|
| LoginPage | 3×TextInput | **低风险**（几何 1306px < 键盘态 1596px，不裁） | 全屏态实测确认；键盘态因模拟器软键盘不可用未实测（§5） |
| ElectricityPage | 2×TextInput（宿舍号、支付密码） | **低风险** | 未实测 |
| TodoPage | 2×TextInput（新增待办、备注） | **低风险** | 未实测 |
| RechargePage | 无 | 无输入控件 | 未实测（无需实测） |
| ProfilePage | 无 | 无输入控件 | 未实测 |
| CampusSettingsPage | 无 | 无输入控件 | 未实测 |
| 其余 pages/ 页面 | 无 | 无输入控件 | 未实测 |

**含 TextInput/TextArea 的页面仅 3 个**：LoginPage、ElectricityPage、TodoPage。除登录页外，后两者在键盘弹出时主操作区均可通过 Scroll 滚动到达，静态判定为低风险。

---

## 1. 全局键盘避让机制（EntryAbility.ets）

`entry/src/main/ets/entryability/EntryAbility.ets`：

- L64 `setWindowLayoutFullScreen(true)`：应用窗口铺满全屏（含状态栏/导航栏区域）。
- L66 `setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)`：键盘弹出时**压缩窗口高度**（把键盘区域让给窗口收缩），而非整页 OFFSET 上移。这是登录页被裁的根因——窗口从 `[0,137][1280,2832]` 压缩到 `[0,137][1280,1733]`（高 1596）。
- L68-69 `avoidAreaChange` 监听 → `updateSafeArea()`（L50-60）：**每次** avoidArea 变化都重算并回写 `AppStorage` 的 `safeAreaTop`/`safeAreaBottom`。

**关键副作用**：`updateSafeArea()` 在键盘弹出时，`TYPE_SYSTEM` 的 bottom 会包含键盘高度，导致 `safeAreaBottom` 被改写成远大于正常导航栏的值。所有消费 `padding({ bottom: this.safeAreaBottom })` 的页面（含 DetailScaffold、ElectricityPage 根 Column、LoginPage）在键盘态下底部 padding 会被异常放大。

**各页应对策略差异**（决定被裁风险）：
- 主操作按钮在 **Scroll 容器内** → 键盘压缩后可向下滚动到达 → 低风险。
- 主操作按钮在 **固定非滚动区域**（如 LoginPage 的居中 Scroll 但按钮组紧贴底部约束）→ 键盘压缩后被裁 → 高风险。

---

## 2. 逐页静态核查

### 2.1 LoginPage（主修，task-10）

`entry/src/main/ets/pages/LoginPage.ets`

- 3 个 TextInput（L88 学号 / L93 密码 / L100 验证码），L106 「登录」Button、L110 「忘记密码」、L115 「登录与数据说明」。
- 结构：`Scroll > Column(padding top=safeAreaTop+28, bottom=safeAreaBottom+24) > [logo, 输入组, 登录按钮, 忘记密码, 说明]`，Scroll `.height('100%').align(Center)`。
- 静态判定：即使键盘 RESIZE 压到 y2=1733，内容 1306px < 1596px 不裁（§5.4 几何计算）。全屏态实测确认元素完整（§5.2）。**"只显示一半"实为 sceneboard 崩溃的窗口态异常，非键盘遮挡**（§5.6）。修复已落地：`supportWindowMode:["fullscreen"]` 锁定全屏 + 登录页压缩居中（当前包 0131A5EB...）。

### 2.2 ElectricityPage（低风险，未实测）

`entry/src/main/ets/pages/ElectricityPage.ets`

- 2 个 TextInput：L188 宿舍号（step 1）、L288 支付密码（step 3，`InputType.Password`）。
- 结构：根 `Column > DetailHeader + Scroll(Column)`（L183-325），**两个输入框及其后续主按钮（「查询电费」L199、「确认支付」L300）全部在 Scroll 容器内**。
- 键盘弹出 → 窗口压缩 → Scroll 可向下滚动把输入框与按钮滚到可视区。底部 padding 用的是根 Column 的 `safeAreaBottom`（L326），键盘态被放大只影响底部留白，不裁切滚动可达的主按钮。
- **静态结论：低风险**。`InputType.Password` 支付密码框在 step 3，聚焦时键盘为数字键盘，同样被 Scroll 兜底。
- 建议：可选加 `expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])` 或键盘收起后回滚到输入框，属体验优化非必须。

### 2.3 TodoPage（低风险，未实测）

`entry/src/main/ets/pages/TodoPage.ets`

- 2 个 TextInput：L421 新增待办、L439 备注。位于页面**顶部** `LiquidGlass` 卡片内（L419-465），非固定底部。
- 结构：`DetailScaffold > Scroll(Column)`，主操作「添加」按钮（L452）在输入卡片内、Scroll 可滚达；待办列表在下方。
- 键盘弹出 → 顶部输入卡片仍在可视区上部，「添加」按钮随之可见；即便被压缩也可滚动。
- **静态结论：低风险**。

### 2.4 无输入控件页面（无需实测）

`RechargePage`（仅金额/支付方式 Radio 与「支付」按钮，无 TextInput）、`ProfilePage`、`CampusSettingsPage` 及其他 `pages/` 页面经全目录 `TextInput(`/`TextArea(` grep 确认**不含任何文本输入控件**，键盘遮挡风险为零（键盘不会被这些页面触发）。

---

## 3. 既有缺陷：onWindowStageDestroy 触发 jscrash

`entry/src/main/ets/entryability/EntryAbility.ets` L80：

```
if (this.mainWindow !== null && this.avoidListener !== null) this.mainWindow.off('avoidAreaChange', this.avoidListener)
```

**现象**（lead 同步）：com.xjit.app.acceptance 于 2026-10-20 22:10:34 发生 jscrash，错误码 `1300002 "The window is not created or destroyed"`，栈位于 `onWindowStageDestroy` 内调用 `mainWindow.off('avoidAreaChange', ...)`。

**根因**：`onWindowStageDestroy` 被调用时 `mainWindow` 已处于销毁/未创建竞态态，对其 `off()` 解绑 avoidAreaChange 直接触发系统 1300002 异常。

**修复建议**（本次不改代码，仅记录）：
- 将 `off('avoidAreaChange')` 包裹 `try/catch` 兜底；
- 解绑前校验 `mainWindow` 窗口仍有效（如 `isWindowDestroyed()` 或捕获 1300002）；
- 或在 `onWindowStageCreate` 的 then 成功回调里才登记 `avoidListener`，销毁路径对未登记状态短路。

---

## 4. 建议修复优先级

1. **P0（已落地修复，非待办）**：登录页"只显示一半"根因为 sceneboard 崩溃窗口态异常（§5.3/§5.6），非键盘遮挡。当前包 0131A5EB... 已加 `supportWindowMode:["fullscreen"]` + 登录页压缩+居中锁定全屏，修复完成。
2. **P1（既有缺陷，独立修复项）**：`onWindowStageDestroy` 的 `off('avoidAreaChange')` 1300002 jscrash（§3）加 try/catch + 窗口有效性判断。
3. **P2（体验优化，非必须）**：`safeAreaBottom` 在键盘态被 `updateSafeArea` 放大（键盘高度计入 TYPE_SYSTEM bottom），可在 `updateSafeArea` 中过滤键盘态仅取导航栏高度；ElectricityPage / TodoPage 输入框键盘收起后回滚定位。

---

## 5. 实测结果（2026-10-20 22:21 补做）

### 5.1 实测环境

- 模拟器 127.0.0.1:5555，`hdc list targets` 正常。
- 当前 com.xjit.app.acceptance 已装 build：SHA256 `0131A5EB...`（lead 提供，含三处改动：登录页压缩+居中、键盘避让固定 RESIZE、module.json5 `supportWindowMode:["fullscreen"]`）。
- 应用重启后 `aa dump -l`：`AbilityRecord` state #FOREGROUND，`aa start` 成功。

### 5.2 全屏 root 几何确认

重启应用后 `uitest dumpLayout`（`kb_audit_root.json`，属模拟器验收产物，未随仓库分发），登录页元素坐标（与 lead 提供前置事实一致）：

| 元素 | 坐标 (y1~y2) |
|------|-------------|
| root 全屏 | [0,137][1280,2832] |
| 应用内容区 | [0,430][1280,2403] |
| 标题「掌上新理工」 | 915 ~ 1038 |
| 学号输入框 | 1115 ~ 1297 |
| 密码输入框 | 1360 ~ 1542 |
| 「登录」按钮 | 1605 ~ 1787 |
| 「忘记密码」 | 1850 ~ 2004 |
| 「登录与数据说明」 | 2081 ~ 2221 |

内容总高 = 2221 − 915 = **1306px**；全屏 root 可视高 = 2832 − 137 = **2695px**，全屏态下所有内容完整可见。

### 5.3 软键盘调起验证

按 lead 指示尝试 `uitest uiInput click` 聚焦输入框（`kb_audit_after_click.json` / `kb_audit_pw.json`）：

1. 点中学号框（640,1206）→ 再 `dumpLayout`：root 仍为 `[0,137][1280,2832]`，**无键盘窗口出现**。
2. 点中密码框（640,1451）→ 再 `dumpLayout`：root 仍为 `[0,137][1280,2832]`。
3. `dumpsys window` / `hidumper` 全文检索 `keyboard|ime|InputMethod`：**零命中**，模拟器窗口系统无软键盘窗口。

**结论：模拟器软键盘不可用，键盘态未能实测。** 原先把 1596px 高归因为"键盘压缩窗口"是**存疑**的——更可能是 sceneboard 崩溃（lead 提供：`/data/log/faultlog/faultlogger/cppcrash-com.ohos.sceneboard-20020016-20261020221021513.log`，22:10:21）导致窗口态异常，而非软键盘触发。

### 5.4 键盘态几何计算（静态推理，非实测）

即便假设键盘能弹出、RESIZE 模式压缩到 y2=1733（高 1596px）：

- 键盘态可视高 = 1733 − 137 = **1596px**
- 登录页内容总高 = **1306px**
- 登录页内容在 Scroll 内**垂直居中**（`.align(Center)`），键盘态下居中 Column 上下各留白 (1596 − 1306) / 2 = **145px**，「登录」按钮底边仍落在视口内，**不被裁**。

**几何结论**：内容高 1306px < 键盘态可视高 1596px，即便软键盘真的把窗口压到 1733，登录页主按钮组也仍在可视区内。当前实测的"被裁"现象实为 sceneboard 崩溃导致的窗口态异常，**并非键盘遮挡本身**。

### 5.5 各页实测状态

| 页面 | 实测结果 |
|------|---------|
| LoginPage | 全屏态几何已实测确认（§5.2）；键盘态因软键盘不可用**未实测**，按 §5.4 几何计算判定不被裁 |
| ElectricityPage | **未实测**（需校园账号登录，无法进入），保留静态低风险结论 |
| TodoPage | **未实测**（需校园账号登录，无法进入），保留静态低风险结论 |
| 其余无输入控件页面 | 无需实测 |

### 5.6 关键修正

lead 在 task-11 协调中提供的 sceneboard 崩溃证据改写了根因判断：
- **原假设**：软键盘 RESIZE 把窗口压到 1733，登录按钮被裁。
- **修正结论**：模拟器软键盘不会自动弹出（点击输入框窗口不变、WMS 无键盘窗口）；1596px 异常窗口态由 sceneboard cppcrash 触发，**非键盘遮挡**。登录页 `supportWindowMode:["fullscreen"]` 改动（module.json5）是正确修复方向——锁定全屏后系统无法把窗口变成半屏。
- 本报告 §1/§2.1 中涉及"键盘压缩窗口"的表述，按 §5.3/§5.4 的修正理解阅读：几何上键盘态不裁切，实际"只显示一半"归因 sceneboard 崩溃。

---

## 6. 最终结论

1. 模拟器软键盘不可用，键盘遮挡**未被实测复现**；"只显示一半"的根因是 sceneboard 崩溃导致的窗口态异常，已用 `supportWindowMode:["fullscreen"]` + 登录页压缩+居中修复（当前包 0131A5EB...）。
2. 几何计算证实即便键盘态 1596px 可视高，登录页内容 1306px 仍不裁。
3. 除登录页外，仅 ElectricityPage / TodoPage 有 TextInput，静态判定低风险（主按钮在 Scroll 内可达）。
4. 既有缺陷 `onWindowStageDestroy` 的 `off('avoidAreaChange')` 1300002 jscrash（§3）需 try/catch 兜底，属独立修复项。
5. 除登录页外各页因需校园账号登录**未实测**，仅保留静态风险结论。
