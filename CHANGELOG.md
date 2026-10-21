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

### 仓库范围收敛

原先仓库里混有与本工程无关的内容，会让审阅者先读到刷题站、AI 中转站和开发过程日志。现在仓库只保留鸿蒙主工程本体（188 个文件），以下内容已移出版本库（本机仍保留，不计入主应用进度）：

- 计算机网络刷题站（独立静态 PWA）与火山引擎 AI 中转站（独立 Node / Express / MySQL 服务，含占位凭据文件）。两者均为独立项目，不是校园 API 后端。
- `.claude/` 编辑器启动配置；`.wolf/` 中 275 份过程日志、记忆笔记与计划稿，仅保留 9 份回归脚本依赖的基线数据。
- 模拟器验收产出的解包 HAP、`.abc` 字节码、sourceMap 与 hilog 转储（49 个文件 3.37 MB），可由构建与验收流程复现。
- 根目录历史实施报告与单文件刷题页面；`docs/` 下 7 份历史计划稿、待办批次与交接记录。

同步修订 README、`PROJECT-MAP` 与 4 份文档中的失效路径引用，`.gitignore` 增补对应规则防止回流。

### 代码审查整改

对 `entry/src/main/ets` 做了一轮逐层审查。审查起点是 95 个文件、9466 行，整改结束时是 79 个文件、8180 行（删掉 17 个零引用文件，新增 1 个共享工具），整改的是逻辑缺陷而非观感：

- **课程提醒不会再"清空后停摆"。** `syncReminders` 先按 `groupId` 取消整组系统提醒，再逐条重建；中途只要 `revision` 变化就直接返回，而记录"已下发过什么"的 `lastPlan` 只在成功收尾时赋值。于是"提醒已被全部取消、`lastPlan` 仍是旧值"可以共存，下一轮 plan 字符串相同时被去重逻辑提前返回，提醒再也建不回来，状态栏还停留在上一轮的"已登记 N 条"。现在一旦开始取消就先把 `lastPlan` 置空，任何提前返回都必然触发下轮重建。
- **校园数据初始化失败不再拖垮整个进程会话。** 原先 `getPreferences` 未做保护且结果被缓存，失败一次后该 Promise 永久 reject，而每次入队都要 `await` 它，课表卡片、课程提醒、实况窗、功能开关在本次进程内持续拒绝，调用方还用空 catch 吞掉了原因。现抽出 `bootstrap()` 并在入队时按需重建，失败原因写入 `campusInitError` 供界面呈现。
- **实况窗启动失败不再遗留无人认领的窗口。** `startLiveView` 返回非 0 时会保留视图再回收，回收若抛出非"窗口已结束"类错误，字段归位语句被跳过，`currentView` 指向系统侧已存在的窗口而 `currentHandle` 仍为 null，上层据此判断"没有实况窗"，清理链也认不出它。现回收失败时显式归位身份字段并保留视图供登出统一清理，提示文案区分"显示不完整"与"回收未完成"。
- **待办 ID 不再有同毫秒碰撞窗口。** 原先生成规则是"毫秒时间戳 + 五位随机数"，同一毫秒内两次添加有十万分之一概率撞 ID，一旦撞上，勾选与删除会同时命中两条记录。现改为时间戳、进程内单调计数与随机后缀组合，并在写入前对该账号现存 ID 做一次冲突复查。
- **退出登录的网页存储清理纳入清理链。** `WebStorage.deleteAllData` 返回 Promise，此前与同步调用同置于 `try/catch` 中裸调用，同步 catch 捕不到异步拒绝，登出可能在上一个账号的网页数据尚未清除时就被判定完成。现作为独立任务参与统一等待。
- **待办页的会话校验统一入口。** 同一文件内并存"对 `alive`、请求版本、缓存世代、账号四元组手写判断"与 `isCurrentOperation()` 两种写法，共 8 处手写条件收拢到单一入口，避免日后改动只改一处。同页删除按钮底色原先在浅色主题下用 `#EF4444`，与色板 `error: #BA2A3B` 不是同一色系，改用新增的 `withAlpha()` 从色板派生，杜绝页面内另起一套色值。
- **任务时间文本补零。** 手动选择时间时"月、日"未补齐两位（生成 `2026-10-5`），与同时生成的"时、分"格式不一致，现统一为 `2026-10-05 14:30`。

### 支付口径与输入校验

- **电费充值不再宣称"充值成功"。** 原先网关返回 `ok` 就直接显示「充值成功！金额 ¥xx」，但 `res.ok` 只证明网关受理了订单，款项在校方侧划转，端侧既没有订单状态接口也无任何回调可确认到账。现改为「支付请求已提交，金额 ¥xx。请到一卡通账户核对到账结果」，页头同步由「充值完成」改为「支付已提交」。这是本次审查中唯一会把未到账说成已到账的地方。
- **网关静默成功补上结构校验。** 响应缺 `data` 时原先补空对象并置 `ok = true`，充值与电费两条支付链会拿着空对象取属性，异常再被通用 catch 吞成"网络失败"；而订单其实可能已在服务端创建，用户看不出区别就容易重复下单。现在两个支付入口都要求带着 `payResult` 对象，缺失时给出「订单可能已创建，请先查询」的独立说明。
- **外部 scheme 改为白名单。** 收银台 H5 由服务端返回，原先只要形如 `xxx://` 就交给系统 `startAbility`，响应若被污染即可拉起任意应用。现只放行微信、支付宝、云闪付的已知 scheme，其余一律留在 Web 内。
- **充值金额补客户端前置校验。** 档位来自服务端配置，此前原样透传；现按契约要求校验"大于 0 且最多两位小数"，非法档位直接拦截、不发请求。

### 一致性收敛

- **首页入口改为按功能名查找。** 原先 7 处用 `FEATURES[4]`、`FEATURES[10]` 这类下标取功能定义，调整数组顺序或插入新项就会静默打开错误页面（"课表"打开成绩）。现在统一走 `featureByName(name)`，找不到时落到学校服务页而不是抛错。
- **周视图配色并入主题色板。** `WeekOverview` 原先自己硬编码 16 个色值（浅深各 8 个，取模基数是 4），而日视图用 `courseColors`（5 色），同一门课在两个视图里颜色和序号都对不上。现在两边共用一个 `stableHash` 和一份 `courseColors`，周视图背景由同色降透明度派生，主题调色只需改一处。
- **第三个课色加深。** 浅色 `#A55F05` 在半透明底上只有 4.12:1，低于 4.5 门槛；改为 `#8B4E04` 后 5.34:1，白底 6.59:1，色相仍是橙棕。周视图背景透明度同时由 0.14 降到 0.10，最小对比度回到 4.82:1。
- **"今日课程"过滤改用容错解析。** `HomeTab` 与 `ScheduleTab` 原先各自用"星期X"字符串精确比较，课表里出现「周一」「Mon」「1」这类写法时，那门课会在今日列表里消失；现在统一用 `weekdayIndex`，与网格、提醒、实况窗共用同一套解析。

- **电费页恢复返回按钮。** 这个页面是首页入口 push 进来的，却把头部写死成 `showBack: false`，导致进去之后只剩系统手势能退出；第二步"更换宿舍"、第三步"改金额"都只能靠手势回退。现在接上了页面自己的 `back()`：第一步直接退出，第二三步逐级回退，支付进行中仍然拦下返回。

- **拆掉密码形参链。** `getPassword()` 恒返回空串，却被挂在 `callFeature`、`callViaHttp`、`refreshInBackground`、`prewarmCampusData` 四个签名上，贯穿十六个页面二十多个调用点。鉴权实际只靠 Cookie 和 Bearer Token，密码既不保存也不提交，所以连同该函数一并删除；四个签名各少一个参数，调用点同步收敛。读代码的人不会再误以为密码参与了鉴权。

### 死代码清理

- **删除 17 个零引用文件、891 行。** 这批文件是早期重构残留，全都不在 `main_pages.json` 的 15 条路由内，且互不引用之外无人使用：`HomePage`、`HomePageV2`、`MainTabsV2`、`PlaceholderTab`、`CountUp`、`PageHeader`、`ThemeProvider`、`AppButton`、`AppCard`、`BottomNavigation`、`AppTheme`、`Spacing`、`PushService`、`ReminderScheduler`、`NotificationHelper`、`NetworkHelper`、`PerformanceMonitor`。
- **清掉三套并存的课程提醒实现。** 生效的只有 `CampusCompanionService` 走 `reminderAgentManager` 的这一条；`ReminderScheduler` 与 `NotificationHelper` 是另外两套独立实现，用"星期X"字符串精确比较判定，与生效链路采用的容错解析不同，留着只会让人改错文件。`SemesterService` 同时精简为只保留 `getTerm`——`getCurrentWeek`/`getTotalWeeks` 会形成教学周的第二个真相源。
- **`NetworkHelper`、`PerformanceMonitor`、`HomePageV2` 里存在未反转义的 HTML 实体**（`&lt;` 混进了类型声明），一旦被 import 立即编译失败；因无人引用才一直潜伏，随本次删除一并消失。`PageHeader` 引用的 `app.media.ic_back` 资源本就缺失，同批移除。

## 2026-10-20

- 全屏窗口模式锁定与登录页垂直占用压缩，消除半屏窗口下内容被裁切；键盘避让固定为 RESIZE，并补 `onWindowStageDestroy` 窗口解绑兜底。
- `check:warnings` 与 ArkTS 警告基线，节次无法解析时不再谎称课程已结束。
- 以实测像素而不是主观判断校准玻璃染色，为玻璃表面补上真实饱和度与真实底色。
- 键盘遮挡与窗口高度全局核查：三个含输入控件的页面均判定为低风险。

## 2026-10-19

- 核对 `payCode` 枚举（01 支付宝、02 微信、06 一卡通余额等），确认充值走网关 `newcard.recharge.create_order`，端侧只需加载 `h5Url` 或提交 `htmlPost`，与 Flutter 版共用同一套网关契约，无需集成微信/支付宝 SDK。
- `RechargePage` 增加官方转账地址分支，并让充值错误对外可见。
