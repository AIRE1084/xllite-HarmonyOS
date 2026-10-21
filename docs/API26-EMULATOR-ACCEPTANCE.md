# API 26 模拟器验收记录

日期：2026-10-09（Asia/Shanghai）。艾哥选择方案 1，使用现有本地 API 26 模拟器。范围为原生材质接入、UI 与缓存 / 预加载运行检查。

## 环境与数据隔离

- 模拟器：127.0.0.1:5555，OpenHarmony-7.0.0.105 / API 26，屏幕 1280 × 2832。
- 构建环境：已有 DevEco 26.0.0.851、SDK 26.0.0.105、Node 24.14.1、jbr、Hvigor / 插件 6.26.8。没有新下载、安装或全局 PATH 改动。
- 英文验收目录 D:/XJITApp-api26-simulator 有工程归属标记；仅该副本改包名、应用名称、测试接口及材质日志。正式源码接口与签名配置保持原值。
- 验收应用 com.xjit.app.acceptance，名称「掌上新理工·验收」，使用 SDK 随附公开 OpenHarmony 调试证书，不读取用户私有签名文件。
- tools/simulator-fixtures.cjs 仅监听 127.0.0.1:18765，不转发上游；账号 2026000001 / fixture-only，数据全部合成。付款被拒绝，付款码以 SIMULATOR-NOT-FOR-PAYMENT 标记。
- 测试接口 publicKey 返回 401，未验证真实校园登录加密链路。没有发送测试或真实凭据到校园后端。

## 本轮修复

| 问题 | 修复与结果 |
| --- | --- |
| 冷启动 Want 缺失，读取 parameters 导致页面不能加载 | EntryAbility 使用 want?.parameters；最终重启无相关 JS 异常 |
| 导航 SVG 线条在深色下不随主题着色 | 改用单色填充路径，深色图标可读 |
| 内容滚到浮动导航下方影响文字辨识 | 独立主题渐变衬底，HitTestMode.None，不占触摸 |
| 原生材质禁用状态未被判断 | 支持检测之外，增加 state != DISABLE 条件 |
| 付款码周边深色背景过近 | 黑码白底 220vp，外加 44vp 白色留白 |
| 电费与待办输入框深色文字 / 占位符不清 | 显式跟随主题设置前景、占位符、光标、背景 |
| 待办顶部留白大、短内容居中 | 减少重复安全区间距，滚动区填满剩余高度并顶端对齐 |

涉及 MainTabs、Materials、三枚 nav SVG、EntryAbility、QRCodePage、ElectricityPage、TodoPage。修复前备份位于 .wolf/backups/emulator-before。保留了同时新增的课表、桌面卡片、提醒与 LiveView 功能。

## 行为结果

| 项目 | 观察结果 | 证据 |
| --- | --- | --- |
| 服务本地回归 | 16 通过，0 失败 | service-regression.log |
| 集成系统功能本地回归 | 25 通过，0 失败；模拟系统 API | campus-companion-regression.log |
| 首屏 / 预加载 | 课表与余额并行，随后个人资料与考试并行，各 1 次 | requests.jsonl |
| 已加载标签来回切换 | 新增网络请求 0；选中第 3 周保留 | interaction-results.json |
| 课表手动刷新 | 请求恰好 1 次 | interaction-results.json |
| 付款码前台 | 观察到自动刷新 | qr-lifecycle-results.json |
| 付款码后台 / 恢复 | 后台等待 14 秒请求 0，恢复前台请求 1 | qr-lifecycle-results.json |
| 待办 | 新增、切换完成、删除均通过；合成待办已删除 | todo-results.json |
| 冷启动与主题 | 会话及浅色选择恢复，无启动 JS 错误 | startup-results.json |
| 跟随系统 | 可切换，验收结束选回跟随系统；未改全局系统主题 | 28-profile-system-final.png |
| 桌面与提醒冒烟 | 页面可打开，但显示「桌面卡片更新失败，请重试」；同步未通过 | 19-campus-settings-dark.png |

以上证据均在 ../.wolf/emulator。共 41 项本地行为回归通过，不等同于 41 项设备测试。

直接打开检查了主页面和付款码、余额、流水、充值、电费、成绩、考试、个人资料、培养方案、待办详情。工程当前有 14 个注册路由；首页课表入口进入保留状态的主课表标签，旧独立 SchedulePage 未直接打开。16-schedule-detail-dark.png 实际是主课表标签截图。

## 最终画面

- [首页浅色：最终包冷启动](../.wolf/emulator/27-home-light-final.png)
- [首页深色：导航衬底与图标](../.wolf/emulator/22-home-dark-final.png)
- [课表浅色：第 3 周](../.wolf/emulator/21-schedule-week3-light.png)
- [付款码深色：白色留白](../.wolf/emulator/23-qrcode-dark-final.png)
- [电费深色：输入与合成查询结果](../.wolf/emulator/24-electricity-result-dark.png)
- [待办深色：最终输入框与顶端布局](../.wolf/emulator/25-todo-dark-final.png)
- [个人页浅色](../.wolf/emulator/26-profile-light-final.png)
- [个人页：跟随系统](../.wolf/emulator/28-profile-system-final.png)

全部为本次模拟器实际截图，主要截图另有 layout-同名.json。较早编号的图片可能在后续修复之前；04-profile-light.png 实际是课表，不作为个人页证据。最终画面及包的 SHA-256 见 final-verification.json。

## 原生材质与验证限制

native-material-runtime.log 记录 ImmersiveMaterialSupported=true level=0 state=0。本地 API 26 SDK 对应 level=EXQUISITE、state=DEFAULT；API 分支构建和运行可用。

截图仍未清晰呈现预期的强高光 / 折射，不能宣布高光液态玻璃视觉验收通过。支持该能力的鸿蒙真机还需检查高光、折射、交互触感与滚动流畅度。未测 FPS、功耗或性能提升百分比；真实校园后端、凭据加密、支付、地图、提醒授权及 LiveView 权益未在本轮验证。桌面卡片同步失败独立列为未通过。

## 产物与复现

| 项目 | 正式用途包 | 隔离验收包 |
| --- | --- | --- |
| 文件 | entry/build/default/outputs/default/entry-default-unsigned.hap | .wolf/emulator/entry-acceptance-signed.hap |
| 包名 | com.xjit.app | com.xjit.app.acceptance |
| 大小 | 1,321,765 bytes | 1,371,850 bytes |
| 签名 / 接口 | 未签名；正式 API | SDK 公开调试签名；本机合成数据 |

正式 SHA-256：`F78D6B36A733136303CE554269918C3E3644C631D732F287DE89D46DF8700486`。

验收 SHA-256：`DB38CE6AD08BEFB2A05B66EE590FAAFEF9EA23BB195ADF98A839CF318CBA5A3F`。

最终正式构建完成于 2026-10-09 13:34:56，33 个任务，18 s 636 ms，70 项 ArkTS 警告及未签名提示，0 错误。两包对应的 122 项源码 / 配置输入核对无漂移。正式记录 .wolf/build-api26-inputs.json；验收记录 .wolf/emulator/build-record.json，包含签名 / 安装日志；汇总 final-verification.json。

复现时在工程根目录的一个终端运行本地接口：

```powershell
& 'D:\data\devecostudionext\DevEco Studio\tools\node\node.exe' .\tools\simulator-fixtures.cjs
```

另一个终端建立端口映射、构建并安装验收包，然后在模拟器打开「掌上新理工·验收」并使用上述合成账号：

```powershell
& 'D:\data\devecostudionext\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' -t '127.0.0.1:5555' rport tcp:18765 tcp:18765
.\tools\prepare-simulator.ps1 -Install
```

prepare-simulator.ps1 检查已安装 SDK、插件缓存和目标 API，使用已存在工具构建，验签并安装，不自动安装依赖。tools/simulator-ui.cjs 为可复用 UI 检查工具，输入前核对前台包，避免操作其他应用。

测试结束仅停止本次接口进程、移除本次 18765 反向映射、恢复临时屏幕超时并清理本次设备临时文件；验收应用、可复用英文构建目录、工具、编号截图、日志和包保留供复查。实际清理结果见 .wolf/emulator/cleanup-record.json。一次性操作使用内联命令，没有新增一次性脚本文件。

课表 / 桌面 / 提醒 / LiveView 的独立实现和包见 [CAMPUS-COMPANION.md](CAMPUS-COMPANION.md)；其专用包与本报告最终包的哈希不同。
