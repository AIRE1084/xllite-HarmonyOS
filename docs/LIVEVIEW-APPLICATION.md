# 新理工实况窗申请材料（待审阅，尚未提交）

准备日期：2026-10-09。本文件是结合当前实现的申请草稿，未代替华为审批。TIMER用于课程倒计时是否符合准入，以华为审核结果为准。

## 拟申请信息

| 项目 | 草稿 / 待补信息 |
| --- | --- |
| 应用 | 掌上新理工 |
| Bundle Name | com.xjit.app；提交时必须与开发者后台实际应用一致 |
| 拟申请场景 | TIMER（计时） |
| 场景说明 | 学生已同步本人课表并主动开启课程实况窗；课前10分钟内进入APP时查看下一节课程倒计时，开课后显示上课计时 |
| 展示内容 | 课程名称、教室、教师、距上课/上课中、剩余时间；点击回APP课表 |
| 用户控制 | 「我的 → 桌面与提醒 → 课程实况窗」，独立开关，关闭或注销结束展示 |
| 生命周期 | AUTO_STOP_WHEN_APP_TERMINATE，APP进程终止后自动结束；课程结束/后续前台刷新时结束或切换 |
| 触发方式 | 当前为本地SDK；APP前台执行。没有服务器自动创建未来实况窗的已上线能力 |
| App ID / 开发者主体 | 待艾哥在实际开发者账号确认，未猜测 |
| 正式签名证书指纹 | 待确定正式/调试签名后填写；不从旧证书推断 |
| 演示截图或视频 | 待本轮签名包在支持设备上运行后录制；UI草图不能替代 |

## 可审阅的场景描述

掌上新理工为学校学生提供课程查询。学生登录并取得本人的课表后，可主动开启课程实况窗。学生在课前十分钟进入应用时，状态栏胶囊及系统实况区域展示课程名、教室和距上课倒计时；开课后更新为上课计时。用户点击返回课表查看完整信息，随时可在应用内关闭，退出登录时清理展示。当前只实现本地SDK触发，进程被终止时自动结束。

实况窗不展示登录密码、访问token或付款码。桌面课表与课前系统提醒分别开关，关闭实况窗不影响学生单独启用其他功能。

## 提交前实际所需

1. 在艾哥的华为开发者账号中确定「掌上新理工」对应应用、Bundle Name、App ID和签名信息。
2. 打开当前官方 Live View Kit 权限申请页面核对 TIMER 的准入要求、所需材料和实际表单字段。此次在线检索未取得可复核的页面正文；场景权限要求已由本机官方SDK声明核对，未据此声称审核已通过。
3. 用已签名的本轮包在支持设备上核对系统能力、通知/实况窗开关和真实课表；提交真实演示材料。
4. 艾哥审阅申请内容和开发者身份信息后，在对应后台提交。当前没有调用任何提交工具，也没有取得受理编号。
5. 获批后核对错误1003500005是否消失，并验收胶囊创建/更新/关闭、课程结束、退出登录、进程终止等行为。

## 已知失败分支（排查后补充记录，2026-10-19）

排查“无法调用灵动岛”反馈，本地实现与调用链路无代码级 bug，当前阻塞点集中在场景权限与设备开关两个系统条件：

- **场景权限未获批（错误码 1003500005）**：`LiveViewService.ets` 使用 `event: 'TIMER'` 计时场景，`@hms.core.liveview.liveViewManager.d.ts` 官方声明中 `startLiveView` 明确列 `1003500005 - The right of liveView is not enabled`，即应用必须先在华为开发者后台获批对应场景权益，否则即便系统开关已开，调用仍会被拒绝。这是当前最可能的失败根因。
- **系统开关未开（错误码 1003500004 / `isLiveViewEnabled()` 返回 false）**：`LiveViewService.isLiveViewSupported()` 会先调用 `liveViewManager.isLiveViewEnabled()` 检查本应用实况窗开关，未开启时直接短路返回 `系统实况窗未开启`，不再走 `startLiveView`。
- **设备不支持或无法连接实况窗服务（错误码 801 / 1003500003）**：老机型或 LiveView Kit 服务不可用时命中此分支，提示设备能力问题而非权限问题。
- **API23 兼容性结论**：`build-profile.json5` 设 `compatibleSdkVersion = 6.1.0(23)`、`compileSdkVersion = 26.0.0`。本机 SDK 官方声明显示 `liveViewManager` 各 API（`isLiveViewEnabled` / `startLiveView` / `updateLiveView` / `stopLiveView` / `LiveView` 基础字段）自 API11 起即存在，项目 `@kit.LiveViewKit` 导入路径在本机 SDK（`sdk/default/hms/ets/build-tools/ets-loader/kit_configs/@kit.LiveViewKit.json`）有明确映射，构建可解析，无证据表明 API23 最低版本会因 LiveView 导入本身失败；但以下字段有版本门槛，API23 运行时可能不支持或降级：`LiveView.lifeCycleMode`（since 26.0.0，API23 运行时该字段不生效，默认 `STOP_BY_APP`，不影响创建但生命周期与 `AUTO_STOP_WHEN_APP_TERMINATE` 语义有差异）、`PrimaryData.aliveTime`（since 6.1.1(24)，API23 运行时该字段被忽略）、`subEvent`/`shareUrl`（since 26.0.0，当前代码未使用）。因此若目标设备真机为 API23，需在真实运行阶段确认系统是否自动忽略高版本字段而非报错；当前无证据表明 API23 会导致 `startLiveView` 直接失败，该风险记录在案，不作为本轮代码修改范围。
- **生命周期清理失败分支**：`LiveViewService.stopCurrent()` 在 `stopLiveView` 返回非 0 时抛出 `系统结束实况窗失败（<code>）`；`CampusCompanionService.clearCampusCompanion()` 捕获后写 `liveViewStatus = '系统实况窗结束失败，请检查系统设置'` 并保留错误，不静默吞掉。若用户在关闭或退出流程中反复看到该提示，指向 `stopLiveView` 返回 `1003500008`（同秒创建数超限）或 `1003500011`（sequence 冲突）等系统侧限制，需结合具体错误码进一步定位。

## 灵动岛适配（2026-10-22 补齐）

对照本机 SDK `@hms.core.liveview.liveViewManager.d.ts` 逐字段核对后，此前实现存在三处缺口，已修复：

| 能力 | 起始版本 | 处理 |
| --- | --- | --- |
| `capsule.icon` | API 11 | 指向 `rawfile/liveview_capsule.png`（1.5 KB，远低于 API 26 前 30 KB 的上限） |
| `capsule.tailIcon` | 6.0.0(20) | 同上；HarmonyOS 6.0 起才可用，按 API 等级下发 |
| `capsule.isContentDisplayed` / `isTailIconDisplayed` | 6.0.0(20) | 同上；控制灵动岛尾部副文案与尾图标是否显示 |
| `primary.content` 的 `${placeholder.timer}` | API 12 | 主区改用系统计时占位符，由系统每秒替换，APP 不必每秒推更新 |

另一处实质缺陷：**上课瞬间的状态切换原先是整体替换 `capsule` 对象**，而图标与尾部开关挂在该对象上，替换会把它们一起丢掉，HarmonyOS 6.0 上会退化成没有图标的裸胶囊。现改为就地修改标量字段，并在失败回滚时按字段逐一还原（原先保存的是对象引用，还原会写回已改过的值）。

胶囊主色按来源区分：课程 `#FF315FC4`（品牌靛蓝），待办 `#FF7B5CE6`（品牌紫）。

`getActiveLiveView` 返回的 `sequence` 在系统未自动生成版本号时为 `4294967295`，该值无效且不能用于更新，因此本实现自建版本号，不采用系统回读值。

## 可审核代码

- [LiveViewService](../entry/src/main/ets/services/LiveViewService.ets)：start/update/stop，TIMER payload，胶囊图标与尾部开关，计时占位符，权限/部分失败处理。
- [CampusCompanionService](../entry/src/main/ets/services/CampusCompanionService.ets)：课程触发、开关持久化、课程结束/注销清理。
- [CampusSettingsPage](../entry/src/main/ets/pages/CampusSettingsPage.ets)：用户开关与状态提示。
- [完整实施和验证状态](CAMPUS-COMPANION.md)。

本机官方声明：`D:/data/devecostudionext/DevEco Studio/sdk/default/hms/ets/api/@hms.core.liveview.liveViewManager.d.ts`，`LiveView.event`说明TIMER为计时并需要相应场景权限；`startLiveView`列明1003500005为场景权益未开通。
