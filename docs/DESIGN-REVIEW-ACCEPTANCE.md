# 掌上新理工原生 UI 最终验收记录

记录日期：2026-10-09（Asia/Shanghai）。艾哥授权睡觉期间自主推进，不中途询问。本记录以 17:18 构建的最终离线 UI 快照、模拟器实拍和校验日志为准；获奖品质作为持续设计目标，没有声称获得奖项或认证。

## 当前交付

模拟器已安装「掌上新理工·设计预览」，独立包名 `com.xjit.app.designreview`。最后一次前台抓图为浅色首页，桌面课表开启、课前提醒与实况窗关闭；共享设备的后续前台变化不在此次抓图证明范围内。

- [已安装 UI 包](../.wolf/design-handoff/entry-design-preview-signed.hap)，1,954,060 bytes。
- SHA-256：`72A7CB2892DDFEB4D93343A69F62F6C4973EC0431809CC5F8D80C5ABCDE941DB`。
- [构建记录](../.wolf/design-handoff/build-record.json)、[安装校验](../.wolf/design-handoff/final-install-check.json)、[完整验收记录](../.wolf/design-handoff/final-verification.json)。
- 实拍查看页：C:/Users/AIRE/.codex/visualizations/2026/10/08/01a11b29-99fc-7793-82fb-4464fa127967/xjit-native-final-review.html；12 组可切换、放大的原生画面，7 组来自最终包，5 组保留较早构建参考并明确标注来源。

## 源码与真实接口范围

共享主工程存在独立的学校原生接口迁移，保留了这些改动，没有回退到旧网关。本次 UI 包从 `.wolf/design-handoff-source` 冻结快照构建：按上一版记录恢复 128 项输入，唯一追加差异为将桌面暂停标题缩短为“课表已暂停”。恢复来源逐项记录在 [来源清单](../.wolf/design-handoff-source/source-provenance.json)。

最终 128 项快照输入校验 0 漂移。检查时，共享主源码与此快照已有 22 项变化或缺失；这份离线快照的校验不能证明学校直连构建或账号联调；独立任务后续构建结果见下方。本次不覆盖这些业务改动，也不将离线 UI 快照当作学校原生接口正式发布版。

旧服务回归在迁移后的共享源码上产生 8 项失败，原因包括已移除的 saveSession/saveAccessToken 假设；日志保留在 `.wolf/design-release/service-regression.log`。对冻结 UI 快照重跑的服务检查通过，不能据此替代新接口回归。本UI任务在并行修改期间尝试的正式构建没有确认成功输出，不计通过；后续学校直连任务的成功构建另有独立记录。

此前未签名正式源码包 `.wolf/design-formal-release/entry-production-source-unsigned.hap` 仅作迁移前档案，1,899,725 bytes，SHA-256 `A02A65C9AF0D05FCA36D3F7E120682247395F09C740A4747B72A0004940ACA94`。它不是当前学校直连工程的最终发布包。

## 独立学校直连任务的后续结果（17:43记录）

学校直连版本已独立完成构建和模拟器安装，正式未签名包及调试包摘要经本轮只读复核；130项构建输入检查时0漂移。结果引用 [学校直连验收](../.wolf/school-native-verification.json) 和 [交叉核对记录](../.wolf/design-handoff/school-native-cross-reference.json)，没有重新执行或合并其测试计数。

- 独立调试应用「掌上新理工·学校直连」，包名 com.xjit.app.schoolnative，与离线UI预览共存。学校统一认证公开登录页已在模拟器显示，[实拍](../.wolf/school-native-emulator/03-school-cas-ready.png) 已目视核对。
- 原生读取已实现：个人信息、校园卡余额、消费流水。39项服务+43项页面+29项校园能力，共111项模拟回归通过；真实登录后的数据读取尚未验证。
- 完整学期课表、成绩、考试、培养方案、付款及相关充值/电费接口仍待登录后协议验证与原生适配。学校网页入口是过渡访问路径，不能计为这些原生接口已完成。
- [学校直连正式源码包](../.wolf/school-native-production/entry-default-unsigned.hap)仍未签名，不是可上架发布包；[独立模拟器包](../.wolf/school-native-emulator/entry-school-native-signed.hap)可查看学校登录流程。

## 已实施和设备核对

首页将下一节课作为主信息，随后是校园卡与四个常用服务；冷白蓝与深色外观、原生材质、高光描边和悬浮导航统一。减少动效与外观偏好保留。课表提供七天总览、今日时间轴、放大入口及完整课程详情，处理单双周、跨节与冲突；窄格长标题通过详情和清单补充阅读。

本轮进一步修复：下一节课重复节次、FormDimension 2×2 参数、开关与状态刷新、桌面长标题两行及底部日期排版、实况窗开启后的等待文案、桌面暂停标题换行。

| 最终包实测 | 结果 | 实拍 |
| --- | --- | --- |
| 首页 | 下一节课、19:00、教室、校园卡、常用服务可读，抓图时首页在前台 | [13-home-final](../.wolf/design-handoff/13-home-final.jpeg) |
| 七天总览 | 第6周、周一至周日、具体日期和周课程数可见；下方内容可滚动 | [10-schedule-route](../.wolf/design-handoff/10-schedule-route.jpeg) |
| 今日清单 | 下一节课节次仅显示一次；滚动后完整显示三门课和19:00–20:40晚课 | [11-today](../.wolf/design-handoff/11-today.jpeg)、[12-today-complete](../.wolf/design-handoff/12-today-complete.jpeg) |
| APP桌面关闭 | 关闭开关隐藏课程，预览显示“课表已暂停”，添加按钮禁用 | [05-widget-disabled](../.wolf/design-handoff/05-widget-disabled.jpeg) |
| 系统桌面关闭/恢复 | 已有2×2系统卡片暂停与恢复通过，课程、时间、教室、周次和同步日期可见 | [06-desktop-disabled](../.wolf/design-handoff/06-desktop-disabled.jpeg)、[08-desktop-restored](../.wolf/design-handoff/08-desktop-restored.jpeg) |
| 实况窗等待 | 开关开启后准确提示“等待进入课前10分钟”；只证明开关与等待状态 | [07-settings-restored](../.wolf/design-handoff/07-settings-restored.jpeg) |
| 最终开关状态 | 桌面开启、提醒关闭、实况窗关闭，状态文案一致 | [09-settings-final](../.wolf/design-handoff/09-settings-final.jpeg) |

设备为已有 Mate90Pro API26 模拟器，当前 HDC 地址 127.0.0.1:10077；恢复原配置设备，没有重置数据或下载镜像。旧深色首页、深色周课表、放大课表、课程详情、当天弹窗按查看页来源标签保留，不替代最终包重新验收。

排除：01-current-route 是启动画面；04-live-wait 实际开关关闭，不能作为等待状态通过证据；早期 design-delivery 的错配路由图片不计最终验收。

## 检查结果与边界

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| API26离线预览构建/签名/安装 | 成功，签名verify-app通过，HAP与构建记录及stage摘要一致 | final-install-check.json |
| 冻结快照输入 | 128项，0漂移 | build-record.json / final-install-check.json |
| 服务 / 校园能力 / 页面行为 | 21 / 29 / 37，共87项，0失败；系统与网络使用替身 | regression-results.json |
| 不透明文字配色 | 38组，最低4.954:1，0失败；不覆盖全部玻璃像素或整页可访问性 | contrast-regression.log |
| 最终预览离线边界 | 6项静态检查通过：无网络权限、无HTTP会话、保留域名、支付不可用、离线标注、快照不变 | offline-boundary-check.json |
| 实拍查看器 | 12组 × 1280/390宽度，60项检查，0失败；无JS错误、文档横向溢出或外网请求 | xjit-native-final-review-check.json |

行为日志均在 `.wolf/design-handoff/`，查看器记录在效果页同目录。查看器的60项不追加到原生87项行为计数。历史10项注入边界检查另有早期记录，不混称本次重新执行。

## 待验证与限制

- 学校真实账号登录、实际课表/校园卡取数尚未由本记录完成。预览课程、教师、余额为合成示例；stage移除INTERNET权限，付款码和支付不可用。
- 桌面2×2添加、暂停、恢复与系统跨进程同步已实测；2×4设备画面与离开APP后的长期系统调度未验收。
- 课前10分钟系统提醒计划与开关已实现，本地回归通过；真实系统登记、授权和定时触发未实测。
- 实况窗TIMER适配、开关及等待文案已实现；华为场景权益未提交或获批，系统胶囊未显示验收，APP关闭后自动创建未来实况窗尚未实现。申请草稿见 [实况窗申请资料](LIVEVIEW-APPLICATION.md)。
- 外部教室地图跳转、真机玻璃折射与高光、FPS、内存、功耗及完整大字体流程未验收。

此前旧后端检查与fixture/映射操作被自动审批拒绝，返回 blocked by policy；未重试或绕过。真实账号端到端联调不记为通过。

本轮下载、依赖安装、插件安装、全局PATH修改均为0，复用已有DevEco、SDK、Hvigor缓存、Node、Java、Edge和Playwright。一次性脚本经stdin运行；5个确切设备临时路径已清理，无递归删除，保留源码备份、stage、安装包和验收证据。
