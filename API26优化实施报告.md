# API 26 原生玻璃与性能优化实施报告

完成日期：2026-10-09（Asia/Shanghai）。工程：掌上新理工，包名 com.xjit.app。

## 已确认的方案

艾哥选择「2：复用本机环境接入原生材质」和「A：编译、目标、最低版本均为 API 26」。build-profile.json5 三项配置现为 26.0.0；新包内最低和目标 API 编码均核对为 260000026。旧系统兼容分支不属于本次交付；不支持沉浸材质的 API 26 设备使用普通表面回退。

## 界面改动

- Materials / NativeGlass 接入本地 SDK 的 @ohos.arkui.uiMaterial.ImmersiveMaterial 和 systemMaterial，支持 THIN / REGULAR、系统阴影、交互高光与形变。材质描述按主题和用途复用。
- 浮动底部导航、首页课程概览和登录面板使用原生玻璃；表格、服务列表和长文本保留清晰的普通表面。原生材质节点移除了竞争的手绘模糊、描边和阴影。设备能力检测不通过时使用不含离屏模糊的回退表面。
- 导航统一为「首页 / 课表 / 我的」，移除占位入口和音乐类标签，按钮补充无障碍描述。主页面统一校园卡片、图标、排版和轻量背景。
- 透明系统栏、图标深浅对比和窗口避让区共同实现沉浸布局。首页、课表、个人页、登录页以及全部 11 个已注册详情页均补齐上下安全区；详情页使用统一的浅色和深色调色板。付款码保持黑码白底。
- 默认跟随系统主题，保留浅色 / 深色手动选择。设置串行持久化，延迟加载旧设置不会覆盖最新选择。未指定颜色模式的配置通知不改变当前主题。

## 加载与性能改动

- 首页课表、余额、待办并行加载，各模块独立发布结果；请求和页面均有生命周期、会话有效性检查。
- 课表和个人页首次访问时再创建，切换后保留状态；课表保留用户选中的周次，预计算课程时间和列表。倒计时、提醒调度、首页分钟刷新仅在对应页面可见且应用在前台时工作。
- 进入主页面延迟 400ms 执行一次预加载。页面隐藏或应用进入后台时取消尚未执行的计时器，返回前台后可重新安排。预加载为「课表 + 余额」「个人信息 + 考试」两阶段，每阶段最多两个请求；第二阶段开始前再次检查会话及前台状态。
- 删除命中缓存后自动强制请求和人工等待。稳定排序请求参数，统一缓存键；普通访问优先有效缓存，手动刷新明确绕过缓存；并发请求和预加载共用在途任务。
- HTTP 缓存 Preferences 单例复用、300ms 合并 flush、内存最多 128 项；过期条目清理，后台显式落盘。课表 TTL 为 30 分钟，其他允许缓存的只读功能为 5 分钟；付款码与支付操作不加入只读缓存。
- 退出登录立即递增会话代次，旧请求、旧持久化读取和旧 token 任务失效。凭据采用快照和串行写入，清理操作排在已开始的写入之后，避免旧 token 在退出后恢复。401 重试等待期间也检查会话代次。
- 待办首次读取合并为同一个任务，消除并发初始化提前返回空列表的问题；后续写入按快照串行保存。
- 付款码按实际到期时间更新倒计时，刷新请求防重；页面隐藏和后台停止计时器，恢复显示时重新取码，避免页面销毁后启动定时任务。
- ApiService 的登录、功能请求、退出等 HTTP 会话在 finally 中释放；移除登录期间额外等待后端预热，主页面统一负责预加载。

## 复用环境（没有下载或安装）

| 项目 | 现有位置 / 版本 |
| --- | --- |
| DevEco Studio | D:/data/devecostudionext/DevEco Studio，26.0.0.851 |
| SDK | 同目录 sdk/default，HarmonyOS 26.0.0.105，API 26 |
| Node | tools/node/node.exe，v24.14.1 |
| Java | 同目录 jbr |
| Hvigor / 插件 | 6.26.8；使用用户 .hvigor/project_caches 内已有 node_modules |
| HDC | sdk/default/openharmony/toolchains/hdc.exe |
| 测试转译器 | SDK ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js |

local.properties 指向以上 SDK。构建脚本仅在子进程工作期间设置 SDK / Java / NODE_PATH，结束后恢复环境变量，没有更改全局 PATH。

新版构建器会将工程路径解析为真实路径，原工程中文路径不被接受，目录联接 D:/XJITApp-api26 也不能解决。本次实际使用独立英文构建副本 D:/XJITApp-api26-build，通过标记文件确认归属，逐文件同步必要源码和配置。原工程仍是修改、记录及包交付的位置；未创建 Git 仓库、提交或推送。

## 可复现的构建和测试

在工程根目录运行：

```powershell
.\tools\build-api26.ps1
& 'D:\data\devecostudionext\DevEco Studio\tools\node\node.exe' .\tools\service-regression.cjs
& 'D:\data\devecostudionext\DevEco Studio\tools\node\node.exe' .\tools\campus-companion-regression.cjs
```

build-api26.ps1 验证现有工具和 6.26.8 缓存，默认先 clean，再构建未签名 debug HAP；检查包内最低 / 目标 API 后复制回工程，校验复制前后 SHA-256，保存所有构建输入的哈希。不会调用依赖安装器或下载 SDK。可用 -DevEcoRoot、-BuildRoot、-NodeModulesPath 指定已有环境；-Incremental 用于同一配置的增量构建，修改 SDK 配置后应保持默认完整构建。

最终完整构建于 2026-10-09 13:34:56（Asia/Shanghai）成功：BUILD SUCCESSFUL，33 个任务（32 执行、1 无变化），18 s 636 ms，0 错误。当前集成源码有 70 项 ArkTS 能力 / 异常处理警告，另有正式包缺少 signingConfig 的提示。这是本次构建耗时记录，不代表与旧版本相比的性能提升比例。

service-regression.cjs 实际转译项目 .ets 服务代码，模拟 HarmonyOS Preferences 和 HTTP；16 项检查全部通过，覆盖缓存批量落盘、过期数据、并发初始化、请求去重、刷新语义、失败资源释放、预加载并发与前后台控制、退出时的读取 / 写入 / 响应竞争、401 后旧请求不重新登录、系统主题和设置持久化竞争。集成的 campus-companion-regression.cjs 另有 25 项全部通过，共 41 项本地行为检查。它们使用模拟系统 API，不能当作 41 项设备或真实后端验收。

## 模拟器验收及修复

艾哥继续选择「1：使用现有 API 26 模拟器验收」。已复用 127.0.0.1:5555 的 OpenHarmony-7.0.0.105 / API 26 模拟器，签名、安装并运行独立包 com.xjit.app.acceptance。仅英文验收副本 D:/XJITApp-api26-simulator 使用本地测试接口 127.0.0.1:18765 和 SDK 自带公开调试签名；正式源码的 com.xjit.app、真实 API 与 signingConfigs: [] 保持原配置。

本轮运行定位并修复：

- EntryAbility 在未收到 Want 的冷启动路径读取参数导致异常，改为安全可选访问，冷启动恢复正常。
- 导航 SVG 改为可随主题着色的填充路径；底部导航下增加独立、不可命中的主题渐变衬底，提高滚动内容经过时的可读性。
- 原生材质检测增加 DISABLE 状态判断；模拟器报告 supported=true、level=0（EXQUISITE）、state=0（DEFAULT）。
- 付款码白底外增加 44vp 白色留白；深色页面下仍有清楚的码区与留白。
- 电费 / 待办输入文字、占位符、光标和背景补齐深浅主题；待办去掉重复的顶部避让间距，并让短内容顶端排列。

主导航、深浅主题、主题重启保存、课表周次保留、手动刷新、详情页和待办增改删已运行检查。热切换标签新增请求为 0；课表手动刷新恰好 1 次；付款码在后台等待 14 秒新增请求为 0，恢复前台请求 1 次。记录与截图见 [API 26 模拟器验收报告](docs/API26-EMULATOR-ACCEPTANCE.md)。

## 交付与完整性

| 产物 | 正式用途包 | 模拟器验收包 |
| --- | --- | --- |
| 路径 | entry/build/default/outputs/default/entry-default-unsigned.hap | .wolf/emulator/entry-acceptance-signed.hap |
| 包名 | com.xjit.app | com.xjit.app.acceptance |
| 大小 | 1,321,765 bytes | 1,371,850 bytes |
| 签名 | 未签名 | SDK 公开调试签名，仅验收 |
| 接口 | 原校园 API | 本机隔离测试接口 |

正式包 SHA-256：`F78D6B36A733136303CE554269918C3E3644C631D732F287DE89D46DF8700486`。

验收包 SHA-256：`DB38CE6AD08BEFB2A05B66EE590FAAFEF9EA23BB195ADF98A839CF318CBA5A3F`。

- 正式构建日志：.wolf/build-api26.log；输入记录：.wolf/build-api26-inputs.json。
- 验收构建、签名、安装记录：.wolf/emulator/build-record.json 及同目录日志。
- 两包对应的 122 项输入均核对无源码漂移，包与截图哈希记录于 .wolf/emulator/final-verification.json。
- 回归日志：.wolf/emulator/service-regression.log、campus-companion-regression.log。
- 修改前备份：.wolf/backups/api26-before；运行修复前备份：.wolf/backups/emulator-before。
- tools 下保留可重复使用的构建、验收、测试接口与 UI 检查工具；一次性处理通过内联命令完成。

以上 SHA-256 是本地生成产物的交付校验值。本次没有下载 SDK、依赖或插件，没有增加全局环境配置。

## 验收边界与待验证项

模拟器能够调用原生材质 API，但最终截图中的玻璃高光、折射表面仍很弱，不能据此宣布高光液态效果已通过。原生高光、折射、触摸反馈、FPS 与功耗仍须支持该能力的鸿蒙真机验收；没有测量性能提升百分比。

目前注册了 14 个路由。本次直接检查主导航及付款码、余额、流水、充值、电费、成绩、考试、个人资料、培养方案、待办页面；首页课表入口现在转到主课表标签，未直接打开旧独立 SchedulePage。没有执行真实付款、地图、通知授权或真实校园后端登录 / 凭据加密联调。全部运行数据来自本机测试接口，付款码标记为不可支付。

新增「桌面与提醒」页面已冒烟打开，但出现「桌面卡片更新失败，请重试」，该项未通过；提醒和 LiveView 的本地行为测试通过不等于设备场景通过。相关并行实现及其独立交付包见 [系统功能实施报告](docs/CAMPUS-COMPANION.md)，其独立包哈希与本报告最新正式包不同。
