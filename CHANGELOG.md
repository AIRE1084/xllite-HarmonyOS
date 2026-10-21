# 更新日志

本文件记录 `harmony` 分支的进展。该分支是面向 **HarmonyOS** 的 ArkTS / ArkUI 原生实现；仓库 `main` 分支是同一产品的 Flutter 实现「新理Lite」，面向 Android 与 iOS。两者平台不同、代码独立，因此这里的记录重点是**鸿蒙平台能力的接入与适配**，以及跨系统版本的兼容处理。

## 鸿蒙平台能力

以下是本分支相对移动端通用实现所做的平台特化，均为鸿蒙独有的系统能力，无法在 Flutter 层通用实现：

- **实况窗（LiveView）**：接入 HMS `@kit.LiveViewKit`（@since 4.1.0(11)，位于 SDK 闭源 `hms` 层，非 OpenHarmony 系统 API）。以 `TIMER` 场景承载课前倒计时与待办计时，提供胶囊、锁屏与通知中心三处呈现，并按错误码给出可执行的处置提示：`1003500005` 指向 TIMER 场景权限未获批，`1003500004` 指向系统开关未允许，`801` / `1003500003` 指向设备不支持或服务不可达。
- **小艺意图（InsightIntent）**：使用 `@ohos.app.ability.InsightIntentDecorator`（装饰器 @since 20）将课表等入口声明为意图，供小艺与系统搜索分发。标准意图清单共 101 项，其中没有创建待办或提醒的意图，`JumpFunctionPage` 只能打开页面而不能填充内容，故落地目标收敛为 `ViewSchoolTimetable`，不承诺无依据的能力。
- **原生沉浸材质**：接入 `@ohos.arkui.uiMaterial`（@since 26）的 `ImmersiveMaterial`，按 `ULTRA_THIN` 至 `ULTRA_THICK` 五级样式渲染玻璃；不可用时回落 `backgroundEffect`（@since 11），以 `saturation` 而非 `brightness` 塑造玻璃质感——`backgroundBlurStyle` 只暴露半径，是早期玻璃呈灰雾的根因。
- **系统提醒代理**：使用 `reminderAgentManager` 注册课程提醒，退出登录时按 `groupId` 枚举 `getAllValidReminders()` 取消，不依赖落盘的提醒 ID，避免残留提醒泄漏到下一个账号。
- **桌面服务卡片**：`CampusFormAbility` 提供课表卡片，快照写入失败时不注册提醒，保证卡片与提醒数据一致。
- **跨版本兼容**：最低支持 API 23，高版本能力一律经 `deviceInfo.sdkApiVersion` 归一化后动态导入，`60100023` 与 `23` 两种编码均可识别；API 26 专有接口在低版本设备上完全不进入调用路径。

## 2026-10-21

### 鸿蒙适配

- **玻璃实现收敛为两条路径。** 保留 `NativeGlass`（API 26 走 `ImmersiveMaterial` 原生材质，低版本走 `backgroundEffect`）与 `CampusCard` 两个真正在用的实现，其余历史组件一并移除。被移除的实现均采用 `backdropBlur` 配高不透明底色，属于"毛玻璃贴片"而非沉浸光感，且其中一处还引用了 ArkUI 并不存在的 `LinearGradient` 组件与 `UIContext.subscribe`，本身无法通过编译。
- **移除与 Flutter `xl_theme` 对应的旧 rgba 色板。** `ColorPalette` 中 8 个 `glass*` 字段从未被任何代码读取——鸿蒙侧玻璃统一走 8 位 ARGB 十六进制，与 Flutter 的 rgba 体系不再共用，留着只会诱导误用。`Colors.ets` 由 123 行收缩到 94 行。
- **移除 `LiquidGlass` 的四个无效参数。** `glassBlur`、`elevation`、`highlightOpacity`、`glassBorderWidth` 声明了却从未在 `build()` 中读取，调用方传入也不生效。该组件现仅为 `NativeGlass` 的薄包装。

### 兼容性修复

- **实况窗不再向低版本系统下发高版本字段。** `lifeCycleMode` 标注 @since 26、`aliveTime` 标注 @since 24，此前无条件写入，在最低支持的 API 23 上这两个成员并不存在，写入只会得到 `undefined`，等于静默失效，还会造成"已设置随进程结束"的错觉。现按 `sdkApiVersion` 归一化后条件注入，低版本交由平台使用自身默认值。

### 测试

- **修正 API23 回归的三处失效断言。** 根因分别是：材质夹具的 `ImmersiveStyle` mock 缺少 `THICK` 成员，导致实现取到 `undefined`；兼容玻璃断言仍指向已弃用的 `backgroundBlurStyle`；登录页品牌图尺寸已调整。修复后 `api23-regression` 由 24 项 3 失败恢复为 24 项全通过，重新具备拦截真实回归的能力。

### 文档

- 新增 `docs/2026-10-21-payment-success-contract.md`：核实应用侧不存在支付结果的观测手段——SDK 没有系统支付接口，充值为 `tradeType: 'WAP'` 的 WebView 支付，`partnerJourno` 只证明订单对象返回、不证明支付成功，且无订单状态查询接口。据此判定支付成功浮层缺少合法触发条件，保留文档设计，不落实现。
- 新增 `docs/2026-10-21-xiaoyi-intent-contract.md`：核实小艺意图接入的平台能力边界与可落地的意图目标。

### 账号与数据

- **待办与宿舍归属按账号隔离。** 新增 `owner` 键与 `items` 并列存放，归属标记不匹配时归属、条目与清理标记三者一并重置，防止新账号继承上一个账号的待办，也防止新账号被上一个账号遗留的清理标记永久卡死。
- `cancelReminderGroup` 改为按 `groupId` 枚举取消，不依赖落盘 ID。

## 2026-10-20

- 全屏窗口模式锁定与登录页垂直占用压缩，消除半屏窗口下内容被裁切；键盘避让固定为 RESIZE，并补 `onWindowStageDestroy` 窗口解绑兜底。
- `check:warnings` 与 ArkTS 警告基线，节次无法解析时不再谎称课程已结束。
- 以实测像素而不是主观判断校准玻璃染色，为玻璃表面补上真实饱和度与真实底色。
- 键盘遮挡与窗口高度全局核查：三个含输入控件的页面均判定为低风险。

## 2026-10-19

- 核对 `payCode` 枚举（01 支付宝、02 微信、06 一卡通余额等），确认充值走网关 `newcard.recharge.create_order`，端侧只需加载 `h5Url` 或提交 `htmlPost`，与 Flutter 版共用同一套网关契约，无需集成微信/支付宝 SDK。
- `RechargePage` 增加官方转账地址分支，并让充值错误对外可见。
