# 项目目录与维护约定

更新：2026-10-16。此次整理采用入口文档和职责划分，不搬动被构建脚本、IDE 或历史证据引用的目录。

## 主工程

| 路径 | 职责 |
| --- | --- |
| [entry/src/main/ets](../entry/src/main/ets/) | ArkTS 主源码；pages 页面、components 组件、services 会话与数据、theme 主题、utils 工具 |
| [entry/src/main/resources](../entry/src/main/resources/) | 图标、语言资源、路由与桌面卡片配置 |
| [AppScope](../AppScope/) | 应用级标识和资源 |
| [hvigor](../hvigor/) | 构建器版本配置 |
| [tools](../tools/) | 可复用构建、模拟器、行为回归与配色检查 |
| [docs](./) | 当前进度、架构入口和历史专题验收 |
| [.wolf](../.wolf/) | 历史过程与验收证据；大文件留本机，精选摘要入库 |

正式入口路由以 [main_pages.json](../entry/src/main/resources/base/profile/main_pages.json) 为准，当前 15 项；HomePageV2、MainTabsV2 等名称不代表当前入口。保留旧实现，后续删除需先核实调用和资源引用。

## 同仓库附属项目

- [计算机网络刷题站](../quiz-network/README.md)：独立静态 PWA，不参与 HarmonyOS 构建。
- [Volc AI Proxy](../volc-ai-proxy/README.md)：独立 Node / Express / MySQL 服务，不是校园 API 后端。本轮仅检查其版本管理边界，未启动服务、安装依赖或操作数据库。
- 根目录历史单文件刷题页面和旧实施报告保留，不与主应用进度合并计数。

## 本地内容与产物

SDK 工具链目录、根目录 exe/dll、签名证书、SDK 本地路径、环境变量、缓存、构建包和验收截图均留在原位且受忽略规则约束。暂不做物理迁移，避免破坏工具与历史证据链接。

- 日常修改仅在当前主工程，英文构建目录只是同步快照，不反向覆盖源码。
- 构建目录须为独立真实 ASCII 路径，构建器会解析联接，因此此类临时构建副本不使用 junction。
- 通用 HAP 输出可能被后续构建覆盖，使用同轮输入哈希与包哈希判定对应版本。
- 本轮独立证据在 [.wolf/project-audit-20261016](../.wolf/project-audit-20261016/)，概要见 [当前进度](PROJECT-STATUS.md)。

## Git 约定

- 主分支 `main`。提交源码、配置、可复用工具和必要文档；按已验证工作单元提交。
- 本地私密配置、签名材料、环境变量不入库；现有忽略规则保留并补充通用依赖缓存规则。
- 使用仓库级行尾约定：源码 LF，PowerShell / Windows 批处理 CRLF；不做无关全树重格式化。
- 本轮接收原有未提交动效与界面状态工作，经修复、回归和完整编译后提交；未重写旧提交或删除备份。
- 当前无远端。后续需提供明确仓库地址再配置推送，本地 Git 提交不等同异地备份。
- 维护当前结论时更新 [PROJECT-STATUS.md](PROJECT-STATUS.md)，旧报告保留日期与快照身份，不用旧截图代替新源码验收。
