# 新理工原生玻璃接入记录

更新日期：2026-10-09。目标工程：D:/整理_/01_项目代码/jiji/XJITApp，包名 com.xjit.app，应用名称「掌上新理工」。

艾哥已选方案 2（复用已有工具做原生材质）、A（编译、目标及最低 API 均为 26）和 1（现有 API 26 模拟器验收）。原 API 21 / API 23 与 HdsTabs 方案属于历史调研。

实际入口为 EntryAbility → LoginPage → MainTabs，导航为「首页 / 课表 / 我的」。Materials / NativeGlass 使用 @ohos.arkui.uiMaterial.ImmersiveMaterial 与 systemMaterial，检测设备支持及 DISABLE 状态，不可用时回退为普通表面。原生材质节点不叠加自绘模糊、描边或阴影；底部导航的主题渐变衬底是独立节点，并且不截获触摸。

复用 D:/data/devecostudionext/DevEco Studio（26.0.0.851）、SDK 26.0.0.105 / API 26、自带 Node v24.14.1、jbr 和已有 Hvigor / 插件缓存 6.26.8。local.properties 已指向该 SDK。本次没有下载或安装新依赖、SDK、插件，也没有改全局 PATH。

中文真实路径被构建器拒绝。正式构建使用有归属标记的 D:/XJITApp-api26-build；隔离验收使用 D:/XJITApp-api26-simulator。源码、备份、记录和交付包保留在原工程。tools/build-api26.ps1 与 tools/prepare-simulator.ps1 是可复用入口，缺工具时报告错误，不自动下载安装。

2026-10-09 13:34:56 正式未签名 HAP 完整构建成功。独立验收包 com.xjit.app.acceptance 使用本机测试接口和 SDK 公开调试签名，签名校验及安装成功，已在 API 26 模拟器运行。16 项服务回归与 25 项系统功能模拟回归全部通过。

运行修复涵盖冷启动 Want 空值异常、导航图标深色着色、导航内容衬底、付款码白色留白、电费 / 待办输入框配色、待办顶部间距和滚动布局。主导航及深浅主题有实际模拟器截图；主题重启保存、周次保留、缓存切换、单次刷新和付款码前后台请求有行为记录。

原生材质运行记录为 supported=true、level=0（EXQUISITE）、state=0（DEFAULT）。这证明 API 分支可运行；截图中的高光与折射仍很弱，原生液态视觉效果尚未验收通过，需要支持该材质能力的鸿蒙真机确认。未测 FPS / 功耗，未把历史 .preview 图或构建成功当作最终视觉证据。

完整改动、最新包哈希见 [API26优化实施报告](../API26优化实施报告.md)；运行范围、截图、复现命令及限制见 [模拟器验收报告](API26-EMULATOR-ACCEPTANCE.md)。

最新课表、桌面卡片、课程提醒与 LiveView 的并行实现见 [系统功能实施报告](CAMPUS-COMPANION.md)。本次冒烟检查「桌面与提醒」提示桌面卡片更新失败，设备同步未通过；真实后端和 LiveView 权益 / 场景验证仍待完成。

操作约束：称呼艾哥；不确定的产品与环境选择先问，优先复用已有工具。没有远程认证测试、Git 提交或推送。一次性操作使用内联命令，保留复用工具。今后大文件、SDK、依赖或镜像下载仍需指定 IDM、多线程 / 续传和官方完整性哈希；不可用、不能创建任务或校验失败时先报告并询问。
