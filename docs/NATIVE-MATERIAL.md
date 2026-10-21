# 原生玻璃材质接入

应用：掌上新理工（`com.xjit.app`）。本文说明 HarmonyOS 沉浸玻璃材质的接入方式、能力检测与回退路径。

## 入口与结构

入口链路为 `EntryAbility → LoginPage → MainTabs`，底部导航为「首页 / 课表 / 我的」。

`entry/src/main/ets/components/Materials.ets` 与 `NativeGlass.ets` 使用 `@ohos.arkui.uiMaterial` 的 `ImmersiveMaterial` 与 `systemMaterial` 构建材质表面。

## 接入约束

材质节点本身不叠加自绘模糊、描边或阴影。这与 `backgroundEffect` 系列 API 的分工一致：`uiMaterial` 负责系统级材质，`backdropBlur` / `backgroundBlurStyle` 只暴露半径参数，不能用来模拟玻璃。

底部导航的主题渐变衬底是独立节点，并且不截获触摸事件，避免遮挡导航点击区域。

## 能力检测与回退

运行时读取 `deviceInfo.sdkApiVersion` 判断设备是否支持 `uiMaterial`。该字段存在两种编码：`"60100023"` 与 `"23"`，统一按 `raw >= 100000000 ? raw % 1000 : raw` 归一化后再比较。

检测同时覆盖设备支持状态与 `DISABLE` 状态。任一条件不满足时回退为普通表面，界面结构与交互不变，仅材质效果降级。

## 运行状态

在 API 26 模拟器上读取到的材质状态为 `supported=true`、`level=0`（`EXQUISITE`）、`state=0`（`DEFAULT`）。这证明 API 分支可以正常进入并返回有效材质等级。

## 未验收项

模拟器渲染出的高光与折射强度明显弱于预期，液态玻璃的视觉效果需要支持该材质能力的鸿蒙真机确认。FPS 与功耗均未测量。历史 `.preview` 图与构建成功记录不作为视觉效果证据。

## 相关文档

- 系统功能（课表卡片、课程提醒、实况窗）的实现见 [系统功能实施报告](CAMPUS-COMPANION.md)。
- 设备侧验收门槛见 [API23 设备验收门槛](API23-DEVICE-GATE.md)。
