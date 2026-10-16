# API23 设备验收门槛

当前结论：最低版本配置与构建通过，尚无 API23 运行证据。现有已注册模拟器均为 API26，不把在 API26 关闭增强效果当作 API23 模块加载验证。

## 首要风险

原先Materials.ets顶层静态导入API26的@ohos.arkui.uiMaterial。现已改为类型导入，并在版本检查之后动态导入应用侧NativeMaterials适配模块；后者封装系统模块。NativeGlass等待加载完成后刷新增强状态，出现序号过滤离开后的迟到结果。新专项验证API23不加载适配模块、并发共享Promise、模块缺失回退；旧22项已改为等待真实适配模块检查，覆盖硬件不支持、系统禁用和查询异常。NativeGlass中的systemMaterial属性仍需真实旧系统执行兼容分支确认。

保留此风险，不在缺少证据时宣称静态导入必然崩溃或必然兼容。模块延迟加载与界面组件分拆应依官方可用机制和实际旧系统结果选择，不能仅用新版本接口检查替换旧版本判断。

## 延迟导入资料核对

已读取[OpenHarmony延迟加载官方文档](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/arkts-utils/arkts-lazy-import.md)：lazy import自API12支持，但其模块解析在冷启动仍会遍历，只将模块源码执行延至首次使用；动态import则在实际执行时触发模块解析及执行。因此把uiMaterial静态导入机械替换为lazy import，不足以证明旧系统缺少模块时可正常链接。本机编译工具确有process_lazy_import实现，但编译器接受语法不替代旧系统运行证据。当前未改生产导入方式，后续需验证动态导入的系统模块支持及ArkUI同步材质消费方式，或取得真实API23结果后再选方案。

## 动态导入方案的已核实边界

[官方动态import文档](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/arkts-utils/arkts-dynamic-import.md)在规格表明确列出@ohos.*系统API，示例使用import('@ohos.curves').then(...)，因此常量动态导入系统模块有公开依据，而非仅支持HAR/HSP。

当前调用链仅NativeGlass使用Materials导出，但nativeSupported在字段初始化和aboutToAppear同步查询，build同步消费glassMaterial。可验证的改造路径应为：类型专用导入与运行时模块分离；API版本先判断，API23不执行动态导入；API26用共享Promise去重加载，失败保留原生模糊；组件出现时异步检查并刷新状态，离开后忽略迟到结果；实际创建材质前确保模块存在。还需检查编译产物是否残留静态系统模块依赖，不能只靠转译测试。此次仅完成契约和调用链核对，未改生产加载逻辑；真实API23链接和systemMaterial兼容分支执行仍是门槛。

### 实际编译试验

曾以缺失系统模块回归先复现静态导入初始化失败，再试验类型导入加动态import、共享Promise和组件出现序号保护。转译23项通过，但实际ArkTS构建明确报10605060（typeof仅可用于表达式，arkts-no-type-query）及10605114（命名空间不可当对象，arkts-no-ns-as-obj）。该试验的模块对象缓存方式不受支持，已仅撤回本轮试验改动，生产仍为原实现；原22项兼容回归复验通过，未生成或安装失败版本。后续应使用可编译的应用侧适配模块导出函数，避免把系统命名空间存作对象，并重新验证产物依赖。

### 实际ABC产物检查

使用本机SDK ark_disasm反汇编已构建modules.abc：Materials的MODULE_REQUEST_ARRAY仅含@ohos:deviceInfo，类型导入未成为静态uiMaterial依赖；loadImmersiveMaterial体内保留指向NativeMaterials的dynamicimport指令；uiMaterial静态依赖仅在NativeMaterials导入表出现。对应未签名HAP SHA256 4214631F451E3BA1885C300D10F7816A27F26D0EF6AFE534CEF995051DE08932。中间Materials.ts仍含import type属于类型信息，不能仅凭文本含uiMaterial认定存在运行时静态依赖。全量回归通过；这些证明产物依赖已按预期隔离，不替代API23实际加载/绘制。

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
