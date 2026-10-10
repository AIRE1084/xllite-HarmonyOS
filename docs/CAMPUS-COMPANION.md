# 新理工课表、桌面卡片与系统提醒实施报告

## 2026-10-09 17:18 UI 交付更新

最终结果以 [原生设计验收记录](DESIGN-REVIEW-ACCEPTANCE.md) 和 [.wolf/design-handoff](../.wolf/design-handoff/final-verification.json) 为准。独立离线 UI 预览已装到已有 API26 模拟器，系统2×2桌面卡片的添加、暂停与恢复已实测；课程名、时间、教室、周次与底部同步日期完整可见。APP三个开关独立，实况窗开启后的等待提示已核对，最后留桌面开启、提醒与实况窗关闭。

本轮修复 FormDimension 的2×2参数、设置开关状态刷新、卡片紧凑排版、暂停文案“课表已暂停”，以及实况窗等待/关闭文案。29项校园能力回归在冻结UI快照上通过；系统提醒实际登记/触发、LiveView场景权益和系统胶囊仍未验收，2×4设备画面也未验收。

共享主工程正在独立迁移学校原生接口，本报告下方旧 API_BASE、/api/v1 协议及早期未验收状态为实施历史，不能当作当前学校直连配置或最新验收结论。冻结快照是UI交付来源，不覆盖当前主源码；学校真实账号联调尚未由本记录完成。

独立学校直连任务随后已完成构建和安装，个人信息、校园卡余额/流水已做原生适配，公开学校登录页已实拍；完整课表等仍待验证。详见 [学校直连验收](../.wolf/school-native-verification.json)，其111项模拟检查与离线UI的87项独立计数。

## 以下为早期实施记录（历史）

日期：2026-10-09（Asia/Shanghai）。目标工程：`D:/整理_/01_项目代码/jiji/XJITApp`，正式包名 `com.xjit.app`，应用「掌上新理工」。

早期记录：当时源码实现及 API 26 全量构建已完成，设备与真实账号验收尚未完成。桌面2×2后续已实测通过，最新边界见上方更新。

## 在 APP 中使用

- 首页课程入口进入主导航「课表」，默认展示整周，可以切换今日列表。
- 「我的 → 桌面与提醒」分别控制桌面课表、课前 10 分钟系统提醒、课程实况窗，三个开关独立保存，默认关闭。
- 设置页「同步」强制请求真实 `jw.schedule`。接口无当前教学周或开学日期时，在该页按学校校历确认当前周；之后按周一递增。
- 开启桌面开关，再点击「添加课表到桌面」中的系统添加项，并在系统窗口确认。关闭开关隐藏课表内容；移除卡片需要在桌面长按处理。
- 课程提醒需要系统通知授权。未来 7 天内最多登记最近 24 条有效课程提醒；打开 APP 自动续订，超出时状态文字明确显示数量。
- 实况窗当前由进入 APP 或前台分钟刷新触发：课前 10 分钟内显示倒计时，开课后更新上课计时，点击回课表。需要设备系统能力、应用通知/实况窗设置和华为场景权限。

## 已实施范围

| 范围 | 当前实现 | 验证边界 |
| --- | --- | --- |
| 真实 API 数据链路 | 复用正式登录/token与业务接口；课表成功后同时同步页面、桌面缓存、提醒计划 | 正式地址探测超时，未完成真实登录或取课表 |
| 原生液态玻璃 | 复用 `uiMaterial.ImmersiveMaterial` / `systemMaterial`，主导航、首页课程概览、设置页卡片预览使用原生材质；有设备能力检测和可读表面回退 | 本轮没有运行原生画面/FPS验收；桌面服务卡片使用其支持的普通表面 |
| 周课表 | 7 天 × 学校已有 10 节作息；跨节课程合并，不连续节次拆分；重叠课程分列；单双周、跨周日期、今日高亮、结束状态、点击详情和教室导航 | 未改学校作息；宽表横向滑动，极多冲突课程的可读性待设备确认 |
| 桌面卡片 | 真实 FormExtensionAbility、2×2 / 2×4 配置、系统 AddFormMenuItem、下一节/时间/教室/后续课程、点击回课表 | 系统确认/卡片跨进程刷新尚待设备验收；离开 APP 后刷新由系统调度，非逐秒更新 |
| 后台课程提醒 | 真正 `reminderAgentManager` 日历代理，课前10分钟，可在应用进程退出后由系统触发；关闭/注销取消 | 已通过模拟API行为检查，系统触发时机与权限待设备验收 |
| 实况窗/状态栏胶囊 | 真正 `LiveViewKit` start/update/stop，TIMER场景、毫秒计时、点击回课表、序列递增、权限和部分成功错误提示、关闭/注销清理 | 仅 SDK 接入；没有华为审批结果，本轮没有在设备显示实况窗 |

## 真实 API 状态及数据约定

历史配置位置：`entry/src/main/ets/utils/Constants.ets`，当时 `API_BASE = http://103.236.73.149:8765`；此为已迁移前的旧网关记录，不代表当前学校原生接口配置。

- 登录：`POST /api/v1/auth/login`，JSON `{ username, password }`，成功响应 `data.accessToken`。
- 业务：`POST /api/v1/run`，Bearer token，JSON `{ feature: 'jw.schedule', params: {} }`，成功响应 `{ ok: true, data: ... }`。
- 其他校园卡、成绩、考试等原有真实 feature 保留，缓存/请求去重/退出时会话隔离保持。
- 课表 `data.courses` 必须是数组。字段接受原接口别名，并统一为 `title / day / teacher / weeks / sections / location`。
- 课程日期由 `currentWeek`（或 `week`）以及取数日期锚定，或由 `termStartDate` 锚定。`totalWeeks` / `weeksTotal` 可控制学期周数。
- 若接口没有当前周次，必须按真实学校校历手工校准。若单门课程没有有效上课周范围或有效节次，不登记该课的系统提醒。
- API取数时间 `scheduleFetchedAt` 与手工校准独立：同一缓存响应不会覆盖已校准周次；退出期间的旧会话数据不能重新写回桌面。

2026-10-09 13:23:40（本地时间）再次探测 `/health` 和 `/openapi.json`，仅 GET、每项8秒超时，两项都未收到响应。此结果只表示当前环境未能访问配置地址，不能据此判断服务器永久下线。没有读取或发送真实用户密码，未调用真实登录/校园付款业务。恢复联调需要确认当前可用后端地址及服务状态，由艾哥在 APP 中自行登录。

## 系统能力申请与限制

桌面组件已注册 FormKit 扩展及系统添加入口，需由用户在设备上的系统窗口确认。本轮未提交任何应用市场或开发者后台资料。

课程提醒已声明 `ohos.permission.PUBLISH_AGENT_REMINDER`，用户主动开启时请求通知授权。未来7天内登记最多24条是本应用的实现上限，不是本报告声称的系统额度；超过时明确提示最近24条，打开APP续订。

本机 API26 官方 SDK 的 `@hms.core.liveview.liveViewManager.d.ts` 将 TIMER 定义为计时场景，并说明使用对应场景需申请权限。当前代码选择 TIMER，课程倒计时是否满足准入规则须由华为审核确认。错误 `1003500005` 会提示场景权限尚未开通，不作为接入成功。

当前 `AUTO_STOP_WHEN_APP_TERMINATE` 生命周期会在 APP 被系统终止时结束实况窗。APP关闭后的未来课程不会自动新建实况窗；目前没有接通后端 PushKit 触发链路，是否允许此计时场景使用该链路也需要按官方场景规则确认。系统代理课程提醒与此独立。

为艾哥准备的可审核申请草稿见 [实况窗申请材料](LIVEVIEW-APPLICATION.md)。未登录开发者账号、未发送申请、未取得审批或证书权限。

## 验证结果

- API26 full clean → assembleHap 构建成功，0个 ArkTS 编译错误；70个警告主要涉及系统能力可用性/抛错处理和既有加密模块，另有未配置签名提示。
- `tools/service-regression.cjs`：16项通过，覆盖登录、缓存、预加载、退出并发、主题持久化。
- `tools/campus-companion-regression.cjs`：25项通过，覆盖单双周、周一递增、节次边界、冲突布局、桌面暂停、系统提醒授权/登记/取消/并发、实况窗payload/更新/权限失败/清理。
- 两组共41项，使用实际源码转译及模拟系统API、存储、网络，不是实时校园API或设备权限测试。
- 交付 HAP 的122项源码/配置输入与英文构建副本核对一致；包内最低/目标API26、`CampusFormAbility`、提醒权限、服务卡片profile/尺寸配置已核对。
- 本轮 HDC 仅只读发现已有模拟器 `127.0.0.1:5555`。另一个会话正在做模拟器UI验收，本轮没有操作它的安装包或设备，不把其他版本的画面当作本轮系统功能验证。
- 浏览器中的旧 `xjit-campus-ui.html` 是UI草图，不是本轮原生APP运行截图。

## 产物与复现

本轮专用未签名包：[entry-default-campus-companion-unsigned.hap](../entry/build/default/outputs/default/entry-default-campus-companion-unsigned.hap)。独立文件名用于避免并行会话覆盖通用产物；未签名包不能直接作为已安装验收版本。

- 大小：1322420 bytes。
- 编译SDK：26.0.0.105，最低/目标API：26。
- SHA-256：`F6FB8CFEF938B195F5D30F82704817807EC827ECB4AB8A3AC8368FA3885BA995`。
- 独立构建副本：`D:/XJITApp-campus-companion-build`，源码仍在原工程。
- 输入记录：`.wolf/campus-companion-build-inputs.json`。
- 包核验及后端探测：`.wolf/campus-companion-verification.json`。
- 新增检查：`.wolf/campus-companion-checks.json`。
- 构建日志：`.wolf/campus-companion-build-console.log`。
- 本轮修改前备份：`.ui-backups/campus-companion-20261009-130011`。

在原工程 PowerShell 执行，均复用现有工具，不安装依赖：

```powershell
& .\tools\build-api26.ps1 -BuildRoot 'D:\XJITApp-campus-companion-build'
& 'D:\data\devecostudionext\DevEco Studio\tools\node\node.exe' .\tools\service-regression.cjs
& 'D:\data\devecostudionext\DevEco Studio\tools\node\node.exe' .\tools\campus-companion-regression.cjs
```

构建脚本的常规输出仍为 `entry-default-unsigned.hap`；本轮专用包是核对源码与包哈希后复制的交付快照。

## 关键代码

- `services/ApiService.ets`：真实课表归一化、缓存和同步入口。
- `services/CampusCompanionService.ets`：开关/周次、串行同步、系统提醒和生命周期。
- `services/LiveViewService.ets`：真正系统实况窗SDK适配。
- `services/WidgetService.ets`、`formability/CampusFormAbility.ets`、`widget/pages/CampusScheduleCard.ets`：跨进程缓存、桌面扩展和卡片UI。
- `utils/CourseCalendar.ets`、`utils/ScheduleLayout.ets`、`components/ScheduleGrid.ets`：课程日期/课次、布局和整周表。
- `pages/CampusSettingsPage.ets`：开关、权限状态、桌面添加和周次校准。

## 环境与下一步

复用 DevEco `D:/data/devecostudionext/DevEco Studio`、API26现有SDK、Node24.14.1、jbr、Hvigor6.26.8缓存，无新下载或安装，无全局PATH修改。一次性处理使用内联脚本；两个回归脚本和构建脚本保留作为可复用工具。

完成真实运行还需要：确认可用后端地址、艾哥在APP自行登录、签名并安装本轮专用包验收桌面/提醒/实况窗。华为场景申请必须核对艾哥开发者账号中的应用与签名信息后，由艾哥审阅提交。
