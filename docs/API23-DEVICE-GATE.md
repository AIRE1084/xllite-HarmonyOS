# API23 设备验收门槛

当前结论：最低版本配置与构建通过，尚无 API23 运行证据。现有已注册模拟器均为 API26，不把在 API26 关闭增强效果当作 API23 模块加载验证。

## 首要风险

Materials.ets 顶层静态导入 @ohos.arkui.uiMaterial；本机 SDK 将该模块整体标为 since 26.0.0。supportsImmersiveMaterial 内的版本判断与异常捕获发生在导入之后。当前转译回归始终提供模块替身，因此只证明 API23 不调用增强方法，未覆盖真实系统缺少模块时的链接行为。NativeGlass 中的 systemMaterial 属性也需真实旧系统执行兼容分支确认。

保留此风险，不在缺少证据时宣称静态导入必然崩溃或必然兼容。模块延迟加载与界面组件分拆应依官方可用机制和实际旧系统结果选择，不能仅用新版本接口检查替换旧版本判断。

## 延迟导入资料核对

已读取[OpenHarmony延迟加载官方文档](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/arkts-utils/arkts-lazy-import.md)：lazy import自API12支持，但其模块解析在冷启动仍会遍历，只将模块源码执行延至首次使用；动态import则在实际执行时触发模块解析及执行。因此把uiMaterial静态导入机械替换为lazy import，不足以证明旧系统缺少模块时可正常链接。本机编译工具确有process_lazy_import实现，但编译器接受语法不替代旧系统运行证据。当前未改生产导入方式，后续需验证动态导入的系统模块支持及ArkUI同步材质消费方式，或取得真实API23结果后再选方案。

## 接入设备后的操作

以下命令在项目根目录执行，TARGET 用设备列表中确认的 API23 目标替换；不默认使用当前 API26 目标。

```powershell
$env:HDC_SERVER_PORT = '8710'
& 'D:\data\devecostudionext\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
& .\tools\check-device-api.ps1 -Target 'TARGET' -ExpectedApi 23
# Stop if the gate fails. Installation requires a separately verified API23 signing pipeline.
```

1. 从系统设置确认系统/API版本，并记录目标标识和已安装验收包SHA256；连接地址本身不证明API版本。
2. 首次无会话启动必须显示原生登录页与品牌图标，无模块链接错误或异常退出。此步骤无需提交密码。
3. 原生模糊及高光壳体可见，增强材质不执行；浅深色与减少动效切换正常。运行日志只收集模块错误和栈，过滤凭据及业务个人数据。
4. 如需业务验证，由用户在应用内手动登录，再执行课表与个人摘要只读检查，避免支付、充值和付款码。
5. 连续切换三个标签、切后台恢复、强制停止后启动，验证最终落点、偏好与会话恢复；文字放大和小屏单独留证。

## 安装工具边界

现有prepare-simulator.ps1仅支持API26模拟器：设备前置检查固定26，签名compatibleVersion参数为26，证据记录api为26。此前给出的API23调用该工具命令已移除；BuildRoot目录包含api23不改变这一事实。API23设备接入后，需先确认该设备接受的调试签名/描述文件及兼容签名参数，单独建立安装链，再执行上述模块链接和绘制验收。不得仅移除版本检查就宣称工具支持API23。

## 结果判定

构建通过、安装通过、进程启动成功、登录页实际绘制、兼容材质呈现分别记录；任何单项不替代其他项。若出现模块链接失败，先保存错误栈与包哈希，再按可复现最小路径修复；不以移除所有高版本效果代替用户要求的分层适配。
