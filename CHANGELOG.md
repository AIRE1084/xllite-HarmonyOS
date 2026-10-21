# 更新日志

记录每次同步到远端的实际变更。倒序排列。只收录已经提交、并通过回归或构建验证的改动；未验证的推测与待确认契约单独标注，不与已核实结论混排。

## 2026-10-21

### 兼容性修复

- **实况窗不再向低版本系统下发高版本字段。** `lifeCycleMode` 标注 @since 26、`aliveTime` 标注 @since 24，此前无条件写在 `LiveViewService.ets` 的对象字面量里。在最低支持的 API 23 上这两个成员并不存在，写入只会得到 `undefined`，等于静默失效，还会造成"已设置随进程结束"的错觉。现按 `sdkApiVersion` 归一化后条件注入，低版本交由平台使用自身默认值。归一化同时兼容 `23` 与 `60100023` 两种编码，与 `theme/Materials.ets` 既有判定保持一致。

### 测试

- **修正 API23 回归的三处失效断言。** 根因分别是：材质夹具的 `ImmersiveStyle` mock 缺少 `THICK` 成员，导致实现取到 `undefined`；兼容玻璃断言仍指向已弃用的 `backgroundBlurStyle`，而实现已迁移到 `backgroundEffect`（前者只能调半径，无法调饱和度与亮度，正是此前玻璃呈灰雾的根因）；登录页品牌图尺寸由 72/20 调整为 60/18。
- `api23-regression` 由 24 项 3 失败恢复为 24 项全通过，重新具备拦截真实回归的能力。

### 文档

- 新增 `docs/2026-10-21-payment-success-contract.md`：核实应用侧不存在支付结果的观测手段——SDK 没有系统支付接口，充值为 `tradeType: 'WAP'` 的 WebView 支付，`partnerJourno` 只证明订单对象返回、不证明支付成功，且无订单状态查询接口。据此判定支付成功浮层缺少合法触发条件，保留文档设计，不落实现。
- 新增 `docs/2026-10-21-xiaoyi-intent-contract.md`：核实小艺意图接入的平台能力边界。101 个标准意图 schema 中没有创建待办或提醒的意图；`ViewSchoolTimetable` 是唯一证据充分的高价值目标，`JumpFunctionPage` 只能打开页面、不能填充内容；自定义意图能否被小艺发现无 SDK 依据，不作承诺。

### 修复

- **待办与宿舍归属改为按账号隔离。** 新增 `owner` 键与 `items` 并列存放，避免改用 `items_<hash>` 破坏既有的按字面键名断言。归属标记不匹配时，归属、条目与清理标记三者一并重置，防止新账号继承上一个账号的待办，也防止新账号被上一个账号遗留的清理标记永久卡死。
- `cancelReminderGroup` 改为按 `groupId` 枚举 `getAllValidReminders()` 取消，不依赖落盘的提醒 ID。此前怀疑退出登录失败会导致旧账号课程提醒残留，实测该路径不成立。

## 2026-10-20

### 新增

- 全屏窗口模式锁定与登录页垂直占用压缩，消除半屏窗口下内容被裁切；键盘避让固定为 RESIZE，并补 `onWindowStageDestroy` 窗口解绑兜底。
- `check:warnings` 与 ArkTS 警告基线，节次无法解析时不再谎称课程已结束。

### 修复

- 以实测像素而不是主观判断校准玻璃染色，为玻璃表面补上真实饱和度与真实底色。
- 键盘遮挡与窗口高度全局核查：三个含输入控件的页面均判定为低风险，记录 `onWindowStageDestroy` 崩溃证据。

## 2026-10-19

### 文档

- 新增 `docs/2026-10-19-PAYMENT-CONTRACT.md`：核对 `payCode` 枚举（01 支付宝、02 微信、06 一卡通余额等）。确认充值走网关 `newcard.recharge.create_order`，端侧只需加载 `h5Url` 或提交 `htmlPost`，无需集成微信/支付宝 SDK。

### 修复

- `RechargePage` 增加官方转账地址分支，并让充值错误对外可见。
