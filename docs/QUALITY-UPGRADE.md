# XJITApp 品质改造与验收记录

## 最新 UI 交付入口（2026-10-09 17:18 构建）

- 最终已安装包：[掌上新理工·设计预览](../.wolf/design-handoff/entry-design-preview-signed.hap)，SHA-256 72A7CB2892DDFEB4D93343A69F62F6C4973EC0431809CC5F8D80C5ABCDE941DB。
- [最新验收报告](DESIGN-REVIEW-ACCEPTANCE.md)、[机器记录](../.wolf/design-handoff/final-verification.json)。原生实拍查看页：C:/Users/AIRE/.codex/visualizations/2026/10/08/01a11b29-99fc-7793-82fb-4464fa127967/xjit-native-final-review.html。
- 冻结UI快照87项行为、38组文字配色通过；12组实拍查看器60项检查通过。2×2系统桌面添加、暂停/恢复和实况窗等待文案已实测，真实系统提醒与LiveView权益未验收。
- 共享主源码正在独立迁移学校原生接口，最新预览包来源为128项输入0漂移的冻结UI快照，不是学校直连正式发布包。下方86项及旧包摘要保留为早期历史，不作为当前源码或最终安装包的验收结果。

独立学校直连任务随后已完成构建和安装，个人信息、校园卡余额/流水已做原生适配，公开学校登录页已实拍；完整课表等仍待验证。详见 [学校直连验收](../.wolf/school-native-verification.json)，其111项模拟检查与离线UI的87项独立计数。

## 以下为早期品质改造记录（历史）

记录日期：2026-10-09（Asia/Shanghai）。艾哥授权本轮自主决策，中途不提问。正式源码、独立签名安装包与效果册均已交付；获奖品质仍是持续打磨目标，本记录只声明已经获得证据的结果。

## 可以直接查看

- [本轮原生效果册](../.wolf/quality-final-preview/review.html)：浅色/深色首页、整周课表、课程详情、完整日清单、偏好设置和网络错误。画面来自实际模拟器截图。
- 模拟器中打开 **掌上新理工·设计预览**（com.xjit.app.designreview），可用离线示例浏览布局。它采用包内合成课程与余额，无网络权限，付款码/付款操作不可用。
- [完整机器验收记录](../.wolf/quality-final-verification.json)保存包哈希、128项输入快照、测试日志、截图与未通过范围。

## 本轮实现

首页按课程、校园卡和常用服务建立顺序：压紧页头和余额区域，四个高频入口放在首屏，其他入口展开访问。主卡与横排浮动底栏使用原生沉浸材质，并将外壳渐变、描边、高光和阴影分层。原生材质不支持时采用静态表面回退；氛围背景使用静态渐变，不持续播放背景动画。

课表增加七天总览、今日清单和放大课表。当前周次自动定位，星期标题可查看当天全部课程，课程点击可以读完整名称、教室和教师；长标题保留省略与详情入口。课程和交易文字使用深浅主题对应的可读颜色。主题现在同步给原生控件，修复了深色页面仍出现浅色弹窗的问题。

主要查询详情页统一标题、返回、安全区、加载、空数据、错误与重试布局。刷新失败时保留已经读取的成功内容；迟到响应不能在页面退出、账号变化或注销后重新写入。个人资料和充值页内容顶部对齐。成绩缺失或非有限值显示缺省标记，不伪造0分。

付款码在后台停止定时器，恢复时先清除过期码再请求；隐藏期间返回的响应不能重启计时。充值与电费处理重复提交、退出/切换账号后的迟到结果，密码及时清除；异常不自动重试订单，提示先查询结果。没有执行真实支付。

本轮保留并核验的性能策略：首次访问才挂载课表/我的并保留已访问标签；首页可见且前台时延迟400ms预加载，分两批、每批最多两个请求；缓存和在途读取共享；长交易/成绩/考试等列表使用LazyForEach；偏好存储复用并顺序落盘。减少动效开关可以持久化。这些检查证明相关行为，未测量FPS、功耗或百分比收益。

提醒与实况窗的点击目标改为当前运行包，修复独立安装包跳转正式包的问题；启动包名解析增加缺失abilityInfo的兼容处理，避免启动异常。桌面、课前提醒和实况窗保留独立开关及失败状态。

## 检查结果

- **86项本地行为检查，0失败**：21项服务、37项页面、28项课程/提醒/实况窗。运行实际ETS逻辑，系统存储、网络和系统能力使用模拟实现；不等同于真实账户和支付端到端验收。日志：[服务](../.wolf/quality-service-checks.log)、[页面](../.wolf/quality-page-checks.log)、[校园能力](../.wolf/quality-campus-checks.log)。
- **38组不透明文字配色检查，0失败**，最低4.954:1。覆盖主题正文、次级文字及课程色等选定组合；不能据此称整页WCAG认证或半透明原生材质像素均通过。[配色记录](../.wolf/quality-contrast.json)。
- 三份API26 clean构建均成功；正式构建保留70项ArkTS警告与未配置签名提示，0构建错误。独立调试包签名的SHA-256摘要验证、签名验证和安装均成功。
- 最新预览包已复查浅色/深色首页、七天总览、当前第6周定位、课程详情打开关闭、星期五三门课完整清单、深色原生弹窗、浅色选择与减少动效关闭。最新验收包的网络失败状态已目视确认。
- 交易、成绩、考试、培养方案、余额、资料正常示例，以及减少动效重启恢复和若干错误/重试，在本轮较早版本检查通过。效果册中的交易图明确标注为15:02过程记录，未当作最终包重新验收。
- 最新验收包重试检查受共享模拟器前台切换/布局读取超时影响，未计为通过。控件操作工具会核对预期应用前台，避免误点其他项目。

## 构建与来源

| 安装包 | 包名 | 字节 | 输入项 / 源码漂移 |
|---|---|---:|---:|
| 正式工程（未签名） | com.xjit.app | 1,889,034 | 128 / 0 |
| 设计预览（已签名安装） | com.xjit.app.designreview | 1,934,797 | 128 / 0 |
| 错误状态验收（已签名安装） | com.xjit.app.acceptance | 1,940,408 | 128 / 0 |

- **com.xjit.app**：`5FA480EAAEB620CE2679BE216B46D5F15F50D024EF73B9A2DC230D98DBCDE626`
  路径：[entry-default-unsigned.hap](../.wolf/quality-final-production/entry-default-unsigned.hap)；构建记录：[build-record.json](../.wolf/quality-final-production/build-record.json)。
- **com.xjit.app.designreview**：`F93A90AB3170504B6B34026E34071AFFAC7F0FEF5CDBFF178D5116779E6F8315`
  路径：[entry-design-preview-signed.hap](../.wolf/quality-final-preview/entry-design-preview-signed.hap)；构建记录：[build-record.json](../.wolf/quality-final-preview/build-record.json)。
- **com.xjit.app.acceptance**：`5CDF5B320DCF6576381C5CAA1D416BE4739F353838198BFF2CAE65F697B3E317`
  路径：[entry-acceptance-signed.hap](../.wolf/quality-final-acceptance/entry-acceptance-signed.hap)；构建记录：[build-record.json](../.wolf/quality-final-acceptance/build-record.json)。

正式包也复制到entry/build/default/outputs/default/entry-default-unsigned.hap，正式包名与真实API配置保留。独立测试包只在各自英文构建副本注入包名、调试签名和测试API/离线数据。最终核对三份128项输入均与当前源文件一致。

工程没有Git元数据，未创建提交、推送或读取SSH私钥。修改前基线保存在[原始备份清单](../.ui-backups/quality-20261009-autonomous/manifest.json)，87个文件；合并工作树相对基线35个已存在文件变化、9个新增源文件/复用工具。该数字包含同项目另一会话的协同修改，不作为本会话独占修改数。

## 验收范围和剩余限制

模拟器：127.0.0.1:5555，OpenHarmony 7.0.0.105/API26，1280×2832。原生材质API已在较早上机记录确认可用，但强高光与折射、动态触感和实际性能需真机实证。桌面卡片更新曾在模拟器失败，未声称同步成功；真实提醒授权和实况窗开发者权益也未完整验收。

设计预览使用示例数据，不能用作真实余额/教务数据证明；未验证真实登录加密、后台接口和支付链路，未声称全部路由的最终设备验收已通过。共享模拟器被其他项目使用，部分操作安全退出，截图只收录已目视确认的画面。20-schedule-current.png、03-transactions-error.png等错配截图已排除，不进入效果册。

复用现有DevEco Studio、SDK26.0.0.105、Node v24.14.1、JBR与Hvigor6.26.8缓存。**本轮下载、依赖/插件安装、全局PATH修改均为0**，环境位置记录在本机验收笔记中。一次性检查脚本均stdin执行，没有遗留脚本文件；复用工具、安装包、源码备份与验收证据保留。

此前恢复fixtures服务与HDC反向映射的操作被自动审批拒绝（blocked by policy），本轮未重试或绕过。无服务/映射启动，错误状态验收与包内离线预览分别记录。

## 交付收尾（2026-10-09 15:55，UTC+8）

效果册使用电脑现有Edge检查1280px与390px两种宽度：8张图片全部正常解码，浅色2张、深色5张、过程记录1张筛选结果正确，放大、Escape关闭和关闭按钮可用，无JS错误或横向溢出。记录：[review-check.json](../.wolf/quality-final-preview/review-check.json)。

设计预览已冷启动回到浅色首页，减少动效为关闭，交付画面已目视确认：[35-home-handoff-final.png](../.wolf/quality-final-preview/35-home-handoff-final.png)。该模拟器由多个项目共用，后续前台可能切换；安装的设计预览可从应用列表重新打开。

交付前再次核对三份构建的128项输入与安装包SHA-256，无源码漂移，回归脚本哈希亦一致。只清理本会话6个已知设备临时路径，无递归删除、全局设置修改或遗留一次性脚本；源码备份、安装包、复用工具和验收证据保留。[清理记录](../.wolf/quality-final-preview/cleanup-record.json)。

共享输出提示：交付复核时entry/build/default/outputs/default/entry-default-unsigned.hap的SHA-256为0E4A6C5EE94ACEE0CBAF7102C9F4F837A3BC9996A9F138DAE447753D65072D3F，已与本轮保留正式包不同。该目录由多个会话使用，本轮未覆盖它；请以本报告链接的.wolf/quality-final-production/entry-default-unsigned.hap及其构建记录作为本轮交付版本。三份保留包及其源码输入已单独复核通过。
