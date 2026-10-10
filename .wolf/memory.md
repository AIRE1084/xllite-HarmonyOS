
## 2026-07-02 计算机网络刷题站 v2 规划

- 现状：data.js 41 题已转 HTML 站点，但 docx 题号 24/25/26 重复、33 题无号、简答编号错位
- 用户决策：保留 docx 原号 + 全局 qN 双编号；内置题库 JSON 导入；PWA + 单文件；SRS + 可视化 + 新题型（多选/排序/连线）
- 详细方案：.wolf/quiz-network-v2-plan.md（7 阶段 7.5 天工期）
- 工作副本建议：D:/jiji/XJITApp/quiz-network/

## 2026-10-09 掌上新理工 API 26 原生材质实施完成

- 艾哥选「2：现有环境接入原生材质」「A：编译/目标/最低全部 API 26」。本轮实现及构建已授权，不重复询问同一方案；签名、安装及运行验收是后续阶段。
- 工程原路径 D:/整理_/01_项目代码/jiji/XJITApp，没有 Git 仓库；未创建仓库、提交、推送或测试远程 SSH。
- 复用 D:/data/devecostudionext/DevEco Studio：IDE 26.0.0.851、SDK 26.0.0.105/API26、Node v24.14.1、jbr；HDC 在 sdk/default/openharmony/toolchains。不要误用 D:/data/DevEco Studio 旧安装或 AppData 的旧 OpenHarmony SDK。
- local.properties 已配置 sdk.dir=D:/data/devecostudionext/DevEco Studio/sdk。Hvigor 与插件使用已有 6.26.8 缓存，不运行安装器。构建期间设置的 DEVECO_SDK_HOME、JAVA_HOME、NODE_PATH 在脚本退出时恢复，无全局 PATH 改动。
- 构建器拒绝中文真实路径。曾建 D:/XJITApp-api26 联接，实测无效、不使用；实际保留 D:/XJITApp-api26-build 真实英文构建副本，.codex-xjit-build 标记工程归属。源码仍在原工程修改；构建脚本逐文件同步必要输入。
- tools/build-api26.ps1 可重复使用，默认 clean 再构建，复用本机工具/cache，验证 HAP 最低/目标 API26并复制回原工程，核对 SHA-256。tools/service-regression.cjs 复用 SDK 的 TypeScript，实际转译服务并模拟存储与HTTP，无真实凭据和网络。
- 原生路线为 @ohos.arkui.uiMaterial.ImmersiveMaterial + systemMaterial；支持检测失败时用无离屏模糊的表面。HdsTabs 是前期调研，不是最终实现。主导航首页/课表/我的，统一深浅主题与安全区，详情页也适配沉浸布局。
- 优化包括：并行首屏数据、按需挂载保留标签状态、两阶段每阶段最多2个预加载请求、缓存复用、在途去重、Preferences单例和合并落盘、会话代次隔离、串行凭据写入、可见/前台定时器控制、待办初始化合并、主题异步竞争防护。
- 2026-10-09 最终全量构建成功；16 项服务模拟回归全部通过。保留原 CryptoUtil 8 项设备能力警告及缺签名提示。没有把历史截图或编译通过当作原生效果/FPS的设备验证。
- 新包 entry/build/default/outputs/default/entry-default-unsigned.hap，1,088,766 bytes；SHA256 A6E1F65D2E15462E4BC7B1E45C173FBDA99643A647895C528778F52E11D7E105。113 项源码/配置输入与最终包对应，核对无漂移。详情见 API26优化实施报告.md 和 .wolf/build-api26-inputs.json。
- 开始 HDC 空列表，最终出现本地模拟器 127.0.0.1:5555：API26，OpenHarmony-7.0.0.105。本次仅只读查询设备版本，没有签名、安装或运行新包；后续运行验收需签名调试包。
- 修改前备份 .wolf/backups/api26-before 保留用于恢复。未新增下载、插件安装或依赖安装；一次性脚本均内联执行，未留脚本文件。
- 以后大文件/SDK/依赖/镜像下载仍优先使用 C:/Users/AIRE/Documents/xwechat_files/wxid_xobvyupxp84b22_f638/msg/file/2026-05/IDM/IDM/IDMan.exe，启用多线程/续传并验证官方哈希；异常先询问艾哥，下载阶段一个智能体监测、另一个准备下一步。

## 2026-10-09 新理工课表、桌面卡片和系统提醒

- 继续用户已授权的「真实API、鸿蒙液态玻璃、周课表、桌面组件和实况窗开关」开发，目标仍为 D:/整理_/01_项目代码/jiji/XJITApp，勿改默认 cwd 的FlashNote。
- 本轮没有新增下载、SDK、依赖或插件安装，复用 DevEco 26.0.0.851 / SDK26.0.0.105、Node24.14.1、jbr、Hvigor6.26.8。优先检查本机环境的要求持续有效。原微信IDM路径此前未找到，用户已允许备用 D:/IDM/IDMan.exe；未来大文件仍必须多线程/续传及官方hash，失败先报告并问艾哥。
- 新增 FormKit CampusFormAbility/CampusScheduleCard（2*2、2*4）和系统AddFormMenuItem；桌面开关暂停内容，实际移除需桌面长按。共享缓存无token/密码/付款码，logout清空。
- 「我的→桌面与提醒」独立开关：桌面课程、课前10分钟系统calendar代理、LiveViewKit实况窗；默认关闭、持久化，取消/注销并发已检查。提醒未来7天内最近24条，超额明确提示，打开APP续订；未接PushKit自动创建后台实况。
- 周课表按跨节/不连续节次和冲突lane布局，单双周/周一递增/校准无猜测。未知周次或课程周范围不登记系统提醒。
- 真实API保持 http://103.236.73.149:8765；2026-10-09 13:23:40，仅GET /health与/openapi.json各8秒超时。没有发送真实凭据，后续需艾哥确认可用后端并在APP手动登录。
- 真正 @kit.LiveViewKit 使用TIMER、本地前台创建/更新/结束；该场景需华为开发者权益，SDK1003500005明确报尚未获批。未登录/提交华为申请，docs/LIVEVIEW-APPLICATION.md仅供艾哥审核，课程倒计时场景是否准入以官方审批为准。
- 41项行为回归全部通过（旧16+新25）；实际源码转译+模拟系统API，不是设备/在线后端测试。全量API26编译成功，70项ArkTS能力/异常处理警告、0错误和未签名提示。
- 检测并保留其他会话对导航渐变、付款码白边、电费/待办输入框深色主题及待办顶部间距的并行修复；另一个会话正在操作模拟器，本轮未签名/安装/操控设备。为避免共享stage竞争，本轮专用英文构建目录 D:/XJITApp-campus-companion-build，常规D:/XJITApp-api26-build仍保留。
- 独立交付包 entry/build/default/outputs/default/entry-default-campus-companion-unsigned.hap，1322420 bytes，SHA256 F6FB8CFEF938B195F5D30F82704817807EC827ECB4AB8A3AC8368FA3885BA995。122项源码/配置与stage一致，核对扩展、提醒权限和form profile。本轮包信息存.wolf/campus-companion-build-inputs.json和.wolf/campus-companion-verification.json；通用entry-default-unsigned.hap可能被另一个会话更新。
- 修改前备份 .ui-backups/campus-companion-20261009-130011。可复用tools/build-api26.ps1、tools/service-regression.cjs、tools/campus-companion-regression.cjs保留；一次性处理均stdin内联，没有临时脚本文件。
- 最终状态见docs/CAMPUS-COMPANION.md。浏览器旧xjit-campus-ui.html为草图，不当作本轮原生运行画面。下一步需要实际可用API、签名设备验收和艾哥确认开发者应用后审核提交场景申请。

## 2026-10-09 API 26 模拟器验收完成（覆盖此前“尚未安装”状态）

- 艾哥选择「1：现有 API26 模拟器验收」，已完成隔离调试签名、安装、运行与 UI 修复，无新下载 / SDK / 依赖 / 插件安装，无全局 PATH 改动。保持正式 com.xjit.app、真实 API、signingConfigs: []。
- HDC 127.0.0.1:5555，OpenHarmony-7.0.0.105/API26。验收 stage D:/XJITApp-api26-simulator，标记 .codex-xjit-simulator；验收包 com.xjit.app.acceptance，SDK 随附公开调试签名，仅该副本对接 127.0.0.1:18765。
- 可复用 tools/prepare-simulator.ps1、tools/simulator-fixtures.cjs、tools/simulator-ui.cjs 保留。测试接口只用账号2026000001 / fixture-only及合成数据，不转发生产，不执行支付；真实登录加密未验证。
- 修复 MainTabs 导航衬底、3枚nav SVG着色、Materials禁用状态判断、EntryAbility冷启动want空值、付款码白色留白、电费/待办输入框主题和待办顶部/滚动布局；备份 .wolf/backups/emulator-before。保留同时新增的Campus功能。
- 16+25=41项本地行为回归全部通过（模拟系统API）；运行记录：热标签切换0请求、第3周保留、手动刷新1请求；付款码后台14秒0请求、恢复1请求；待办增/改/删；重启会话及浅色选择恢复，最终回到跟随系统。
- 原生材质supported=true、level0 EXQUISITE、state0 DEFAULT，但截图高光/折射弱，视觉验收待真机；未测FPS/功耗/性能百分比。桌面与提醒打开后卡片更新失败，此项设备同步未通过。旧独立SchedulePage未直接打开，不能称全部14路由已设备验证。
- 最终正式包2026-10-09 13:34:56构建成功，entry/build/default/outputs/default/entry-default-unsigned.hap，1321765 bytes，SHA256 F78D6B36A733136303CE554269918C3E3644C631D732F287DE89D46DF8700486；70项ArkTS警告+缺签名提示，0错误。覆盖前文旧通用包的大小/hash。
- 最终验收包 .wolf/emulator/entry-acceptance-signed.hap，1371850 bytes，SHA256 DB38CE6AD08BEFB2A05B66EE590FAAFEF9EA23BB195ADF98A839CF318CBA5A3F。两包各122输入均无源码漂移，记录 .wolf/emulator/final-verification.json。Campus独立包保留，不覆盖其记录。
- 最终截图 .wolf/emulator/22–28（21为第3周课表），报告 docs/API26-EMULATOR-ACCEPTANCE.md、API26优化实施报告.md、docs/NATIVE-MATERIAL.md。测试资源清理以 .wolf/emulator/cleanup-record.json 为准；保留安装的验收应用和复用stage，重开需启动本机fixtures及18765反向映射。
- 2026-10-09 13:43 清理完成：仅停止验收应用与已核对归属的fixtures进程37536，18765映射已移除（HDC rm需将两个endpoint作为独立参数），屏幕超时恢复，3个设备临时文件与15个本地临时证据/进程文件删除。保留验收安装、编号证据、HAP、工具与stage。

- 2026-10-09 艾哥明确要求安装到后台模拟器：再次安装并启动已验证验收包 com.xjit.app.acceptance（API26，SHA256 DB38CE6AD08BEFB2A05B66EE590FAAFEF9EA23BB195ADF98A839CF318CBA5A3F，源码122项无漂移），安装日志 .wolf/emulator/preview-install.log，状态 .wolf/emulator/preview-install-record.json。恢复本地fixtures服务及端口映射的组合操作被自动审批blocked by policy，未重试；没有下载或环境安装。

- 2026-10-09 本会话复用已安装的掌上新理工·验收包，无重复安装/下载；aa start成功，实时截图.wolf/emulator/user-preview-current.png已目视确认校园首页（余额--、常用服务、首页/课表/我的导航）。验收数据服务未恢复，不绕过已拒绝的服务/映射操作。布局复查超时，未据此声称控件验收通过；设备临时截图与layout已按已知路径清理，结果见.wolf/emulator/user-preview-verification.json。

## 2026-10-09 新理工 UI 品质目标与方向稿

- 艾哥要求以Awwwards、Webby Awards、FWA能获奖的品质为目标，自查、反复提升；未宣称已达到/获得认证。此要求后续设计和验收持续有效，操作前路线选择要求仍有效。
- 本轮未改原生ETS/API/安装包，仅交付docs/UI-QUALITY-BAR.md与可交互方向稿C:/Users/AIRE/.codex/visualizations/2026/10/08/01a11b29-99fc-7793-82fb-4464fa127967/xjit-quality-direction.html。方向1冷白蓝日程优先（建议），方向2深靛蓝校园识别，待艾哥选路线后原生实施。
- 方向稿包含首页/周课表/今日课程/提醒设置，深浅色、正常/空/失败/长文本和完整课程详情，全部示例不调用真实系统/API。两轮自查后96个渲染组合无JS错误/横向溢出，主课程文字最低对比度6.21:1，不当作原生已验收或获奖品质已达标。
- 已有Playwright包可复用，但其预设浏览器未安装；改用电脑现有C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe进行headless验证，未下载/安装/改全局配置。一次性脚本stdin执行。验收记录xjit-quality-check.json及4张PNG均在方向稿目录。


## 2026-10-09 自主品质改造最终交付

- 称呼艾哥。艾哥本次睡觉期间明确授权自主决策、修改、编译、安装与验收，中途不询问；此为本任务的授权覆盖，不推定为其他后续任务永久取消其询问偏好。继续以Awwwards/Webby/FWA为设计品质目标，未宣称获奖或认证。
- 本轮合并工作树：首页冷白蓝/深色、鸿蒙原生材质与边缘高光、横向悬浮底栏、七天课表与完整日清单、统一详情头与加载/空/错误/重试。刷新失败保留旧内容，异步账号/离页保护，付款提交防重，付款码隐藏时停计时；惰性标签、400ms分批预加载、LazyForEach查询列表、减少动效与偏好保存。保留另一会话的原生主题同步及启动包名兼容修复。
- 最终回归21服务+37页面+28校园能力=86项，0失败，使用模拟系统/网络；38组不透明配色0失败，最低4.954:1。三份API26 clean构建成功，正式70项ArkTS警告+未签名提示，0错误；各128项输入交付前复核漂移0。正式包未签名；预览/验收签名验证及安装通过。
- 正式保留包.wolf/quality-final-production/entry-default-unsigned.hap，1889034bytes，SHA256 5FA480EAAEB620CE2679BE216B46D5F15F50D024EF73B9A2DC230D98DBCDE626；预览.wolf/quality-final-preview/entry-design-preview-signed.hap，1934797bytes，F93A90AB3170504B6B34026E34071AFFAC7F0FEF5CDBFF178D5116779E6F8315；验收.wolf/quality-final-acceptance/entry-acceptance-signed.hap，1940408bytes，5CDF5B320DCF6576381C5CAA1D416BE4739F353838198BFF2CAE65F697B3E317。
- com.xjit.app.designreview（掌上新理工·设计预览）为独立包，合成离线示例、无网络权限、不能付款；com.xjit.app.acceptance为独立错误状态验收；正式com.xjit.app及真实API保留。交付时预览已启动到浅色首页，减少动效关闭；35-home-handoff-final.png已目视确认。共享模拟器后续可能切前台。
- 已复查最终浅/深首页、七天课表、当前第6周、课程详情、星期五含晚课完整清单、深色原生弹窗和网络失败。交易等部分详情以及动效重启持久化是较早过程验收，效果册明确标注；最终错误页重试因共享前台/布局超时未计设备通过。错配截图与其他项目画面排除。真机折射高光、FPS/功耗/内存、真实账号支付、系统卡片同步和完整实况窗权益仍未验证。
- 交付：docs/QUALITY-UPGRADE.md、.wolf/quality-final-verification.json、.wolf/quality-final-preview/review.html。效果册复用现有Edge+Playwright，1280/390px两种宽度8图加载、筛选、放大/关闭、无横向溢出/JS错误均通过。
- 复用D:/data/devecostudionext/DevEco Studio；SDK26.0.0.105/API26；其tools/node/node.exe v24.14.1；既有JBR/Hvigor6.26.8缓存；既有Edge C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe和Playwright C:/Users/AIRE/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright。下载/依赖插件安装/全局PATH修改为0，未读取SSH私钥或私有签名凭据。
- tools/build-api26.ps1、theme-contrast.cjs、simulator-ui.cjs等复用工具保留；一次性脚本stdin执行，无临时脚本留存。本轮6个确切设备临时路径已rm -f，记录.wolf/quality-final-preview/cleanup-record.json，无递归清理或全局超时改动；源码备份.ui-backups/quality-20261009-autonomous与构建stage保留。
- 曾恢复fixtures服务器+HDC映射被自动审批blocked by policy；未重试/绕过，无服务/映射启动。工程无Git元数据，不提交或推送。
- 交付复核：共享entry/build/default/outputs/default/entry-default-unsigned.hap哈希0E4A6C5EE94ACEE0CBAF7102C9F4F837A3BC9996A9F138DAE447753D65072D3F已不同于本轮保留包，未覆盖共享输出。后续取本轮正式版本须使用.wolf/quality-final-production/entry-default-unsigned.hap及其5FA480...构建记录。三份保留包与128项当前源码输入复核通过。


## 2026-10-09 17:18 最终 UI 快照安装与交付校正

- 艾哥睡觉期间授权本任务自主决策、不询问。复用已有工具，下载、新依赖/插件、全局PATH修改均为0。一次性脚本经stdin执行；设备5个确切xjit-design临时路径已清理，记录.wolf/design-handoff/cleanup-record.json，stage/备份/安装包/证据保留。
- 最新已装UI包.wolf/design-handoff/entry-design-preview-signed.hap，1954060 bytes，SHA256 72A7CB2892DDFEB4D93343A69F62F6C4973EC0431809CC5F8D80C5ABCDE941DB；com.xjit.app.designreview「掌上新理工·设计预览」。API26构建、公开调试签名verify-app、HDC安装成功；HAP与stage/record一致，128项冻结快照输入0漂移。
- 共享学校原生接口正在独立会话迁移，保留SchoolNativeApi/SchoolRoutes等变更，没有回退旧网关。本轮UI来源.wolf/design-handoff-source，按旧record精确恢复128项，唯一追加为CourseCalendar暂停标题“课表已暂停”。不能用这份快照覆盖共享主源码；截至本次校验共享输入已有22项变化或缺失。之前“当前128项源码一致”等断言属于历史，不适用于学校直连源码。
- 旧service-regression在新共享源码上有8项失败（saveSession/saveAccessToken不再存在），保留.wolf/design-release/service-regression.log，不能再据此称共享主源码通过。冻结UI快照重跑21服务+29校园能力+37页面=87项0失败；38组选定不透明配色最低4.954:1，0失败；最终stage离线边界6项通过。系统/网络为替身，真实学校登录/取数不在通过范围。
- 已有Mate90Pro API26恢复原设备配置，HDC127.0.0.1:10077，数据未reset、0镜像下载。2×2系统卡片添加与关闭/恢复实拍通过，开启含周次、长标题、19:00–20:40、教室、同步日期；暂停文案单行且隐藏原课程数据。实况窗开关on等待课前10分钟文案通过，最终桌面on、reminder/live off。真实提醒登记/触发、LiveView系统胶囊和权益未验收，2×4设备实拍未验收。
- 最终首页.wolf/design-handoff/13-home-final.jpeg、七天10-schedule-route.jpeg、今日11-today/12-today-complete.jpeg、设置09、live等待07、桌面off06/on08均已目视。01是splash，04-live-wait实际off，不能计等待通过。共享模拟器可被其他会话切前台，不停止别人的APP。
- 最终原生实拍页C:/Users/AIRE/.codex/visualizations/2026/10/08/01a11b29-99fc-7793-82fb-4464fa127967/xjit-native-final-review.html：12组，7组来自最新UI包、5组明确标早期参考；Edge+既有Playwright在1280/390宽度60检查0失败，图片切换/放大/关闭/箭头/无外网/无JS错误/无文档横溢通过。这是查看器验证，不追加到原生87项。
- 验收主记录docs/DESIGN-REVIEW-ACCEPTANCE.md和.wolf/design-handoff/final-verification.json；.wolf/design/final-verification.json已同步最新。旧包/文档另存before-handoff历史。formal-release A02A65...未签名仅迁移前档案，当前学校直连主源码正式构建未由本记录确认成功；不要称最新正式发布包。
- 旧后端检查/fixture及HDC映射操作曾被自动审批blocked by policy，未重试/绕过。本交付为无INTERNET、合成离线示例预览，不能付款；学校原生接口真实账号联调独立待验收。奖项品质仍为设计目标，未称认证或获奖。


### 17:43 学校直连独立结果补记

- 独立会话已交付.wolf/school-native-verification.json：个人资料、校园卡余额/流水原生适配，39+43+29=111项模拟检查；完整课表/成绩/考试/支付等仍pending，学校网页不计原生完成，真实账号取数未验证。
- 学校正式unsigned BB38AF35894830C436F8E35EF691773D500620580E9AA03A91C37ABA82A95E3F，1965056bytes；独立schoolnative signed 6528FF36F46CBDEEEBCB22FC0194CD322D85B826CD959B90D838FA6607B53CD7，均摘要只读复核一致，130项当前输入0漂移。.wolf/design-handoff/school-native-cross-reference.json记录交叉核对，不合并到离线UI87项。学校公开CAS在10077实拍已目视，未输入真实账号。
- 这项成功构建取代此前“学校直连未确认构建”的状态，但不改变UI72A冻结包的来源；共享设备已被其切到学校登录，UI首页证据只证明17:32抓图时前台。


## 2026-10-09 学校原生接口直连（覆盖旧网关状态）

- 艾哥明确拒绝反向代理，当前正式源码移除 http://103.236.73.149:8765、/api/v1/run 及网关登录/刷新/注销，改为学校 HTTPS 原生服务。学校 CAS、superapp、authx-service/personal、portal/portal-api、newcard/server 地址见 docs/SCHOOL-NATIVE-API.md。历史旧网关文档是历史记录，不可当现行配置。
- 仅 3 个原生适配器已实现并按学校公开客户端契约回归：jw.profile、newcard.balance、newcard.transactions；其余 10 个标识待认证后完整协议证据。学校网页入口是临时访问，不计原生完成；原生课程/成绩/考试/培养方案及依赖新课程数据的提醒尚未打通。不得称 13/13，未登录实际业务也不得称 3 项在线成功。
- 个人信息实际包 code=0,data.attributes.{accountId,userName,organizationName}，X-Id-Token、X-Terminal-Info 小写 h5。一卡通 raw Authorization、resultData.user.balance/accTypes；username 是卡显示名，idSerial 是卡身份，未证实与门户 accountId 对应。流水 tradetype=-1，学校 pageNumber 从 0 起，UI 从 1 转换，pageSize20、rows/totalpage、txamt 分/100，已原生触底分页。
- portal token 先验证未来有效 JWT 及个人信息、持久化成功后发布；密码不保存。卡 token 仅内存，独立版本与进程随机缓存命名空间。退出清私密 Web、缓存与校园信息；有限重试和可见性守卫。新增卡会话独立切换回归先复现 4 个失败，再修复余额/流水成功与异常迟到响应、清旧内容，43 项页面回归通过。
- 最终测试：39 服务+43 页面+29 校园能力=111，0失败，全部模拟网络/系统；真实 WebView 会话自动化、学校认证后业务、设备 SM4、跨系统身份和付款未验收。正式 API26 增量与模拟器 clean 编译通过，正式74项ArkTS警告、0错误。130项输入快照复核0漂移。
- 正式保留 .wolf/school-native-production/entry-default-unsigned.hap，1965056bytes，SHA256 BB38AF35894830C436F8E35EF691773D500620580E9AA03A91C37ABA82A95E3F，未签名；取该保留路径，共享 entry/build 可被其他会话覆盖。
- 模拟器 .wolf/school-native-emulator/entry-school-native-signed.hap，2026940bytes，SHA256 6528FF36F46CBDEEEBCB22FC0194CD322D85B826CD959B90D838FA6607B53CD7。SDK公开测试签名验签、安装、启动通过，包 com.xjit.app.schoolnative（掌上新理工·学校直连）。设备目标改为127.0.0.1:10077（同机有设计预览）；10057是另一台，旧5555已断开。
- 已实际点击学校统一认证入口，03-school-cas-ready.png 显示 cas.xjit.edu.cn 登录表单，目视核验；没有输入真实凭据或付款。后续需要艾哥在此官方页面手动认证，不能通过猜测动态 cache_courseUrl 实现教务。保留构建/安装/测试证据 .wolf/school-native-verification.json。
- 复用 DevEco Studio26.0.0.851、SDK26.0.0.105/API26、Node24.14.1、Hvigor6.26.8、JBR/HDC/SDK公开测试签名，未下载/安装环境或插件/改全局PATH，未读取SSH私钥/私有签名/已保存真实账号。一次性脚本stdin，无临时可执行文件。公开学校代码仅文本检查，33文件本地SHA256清单 sha256-manifest.json 保留，不冒充官方发布哈希。
- 自动审批拒绝后台构建/安装组合及新大型WebView会话测试脚本，只有blocked by policy无详细原因，未重复；前台构建、普通独立HDC安装和既有套件检查成功。未启动fixture服务/映射。prepare-simulator -NativeSchool 保留真实URL，-OfflinePreview 与直连互斥并修复前置旧网关检查；旧fixture模式不适用于新协议。

## 2026-10-10 风险点修复：共享构建输出恢复 + 回归修复 + 构建脚本加固

- 修复 MemoryCache.ets：无法解析或结构无效的持久化缓存条目现在会被删除（此前损坏 JSON 永久留存且每次读取都重复解析）；过期但仍有 last-good 值的条目按 stale-while-revalidate 继续提供并触发后台刷新，行为不变。
- service-regression.cjs 中早于 SWR 设计的旧断言「过期持久化缓存不得返回」已更新为现行契约：过期条目返回旧值 + isCacheFresh=false；损坏条目返回 null 且从持久化清除。三套回归全绿：服务 39 + 页面 43 + 校园能力 29 = 111，0 失败（均为模拟网络/系统）。
- tools/build-api26.ps1 加固：hvigor 的 ArkTS 警告走 stderr，PowerShell 5.1 在 EAP=Stop 下会把原生 stderr 行变成终止性 NativeCommandError（此前成功依赖调用环境差异）。现改为在 hvigor 调用期间 EAP=Continue，改用 $LASTEXITCODE + 产物存在性/哈希/API 断言判定成败，警告全部入日志。
- 默认构建目录 D:/XJITApp-api26-build 已被其他会话变成指向 D:/归档/XJITApp-build-snapshots 的 junction，脚本按设计拒绝；本轮使用真实 ASCII 目录 D:/XJITApp-riskfix-build。
- 2026-10-10 全量 clean 构建成功（BUILD SUCCESSFUL 23s，74 项 ArkTS 警告 0 错误，未签名提示照旧）。共享输出恢复：entry/build/default/outputs/default/entry-default-unsigned.hap，2,005,050 bytes，SHA256 8BF0D5B532F6846464E3E762F904A6A5B8964482CF9E9F7EA8E2FA200357D40B；131 项输入漂移 0；HAP min/target=260000026、compile 26.0.0.105。证据 .wolf/risk-fix/。
- signingConfigs 保持 []（艾哥既有决策未改）；正式包仍未签名。10 个业务 feature 原生协议、真实账号登录、LiveView 权益、真机视觉/FPS 仍未验证。

## 2026-10-10 Git 基线建立

- 艾哥要求初始化 Git 仓库并提交完整基线。仓库位于原工程根目录，分支 main，首个提交 acb5db5：191 文件 / 17,805 行 / 约 849 KB。
- 提交前拦截了敏感与超大内容：volc-ai-proxy/.env（含 JWT_SECRET/DB_PASSWORD/ARK_API_KEY 实际密钥）已加入 .gitignore 排除；根目录签名材料（xjit-*.jks/p12/cer/csr/p7b、xjit-debug-profile.json）、tmpca 私钥目录、local.properties 一律不入库。
- 同时排除：随包 SDK 工具链副本（llvm 2.4G、build-tools、common、sysroot 等全部根级 SDK 目录与 *.exe/*.dll）、构建产物（build/、dist/、*.hap）、.wolf 大体积证据（仅 memory.md 与顶层 *.json 记录入库）、docs/html 171M NDK 文档转储、.preview、.ui-backups、根目录截图 *.jpeg、material 缓存。
- 提交树终检通过：git ls-tree 复核无任何凭据/SDK/产物文件。工作区干净。仓库纯本地，未配置远程、未推送。
