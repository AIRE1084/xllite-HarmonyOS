# 掌上新理工 · HarmonyOS

面向新疆理工学院的校园应用，使用 ArkTS / ArkUI，最低、目标及编译环境为 HarmonyOS API 26。视觉方向为鸿蒙原生沉浸玻璃。

## 项目入口

- [当前进度与下一步](docs/PROJECT-STATUS.md)：本轮实测结论、业务缺口、交付边界。
- [目录与维护约定](docs/PROJECT-MAP.md)：源码、附属项目、工具链、历史产物和 Git 规则。
- [学校接口与认证契约](docs/SCHOOL-NATIVE-API.md)：学校直连协议与历史验收。
- [设计验收](docs/DESIGN-REVIEW-ACCEPTANCE.md)、[原生材质](docs/NATIVE-MATERIAL.md)、[实况窗申请草稿](docs/LIVEVIEW-APPLICATION.md)。

当前属于**开发与联调阶段，而非正式发布版本**。原生个人信息、余额、流水已有实现；其余十项业务尚待原生协议与真实账号验收。源码另含 XLLite 网关会话分支，详见当前进度中的路由说明。历史离线预览数据不代表学校业务成功。

## 本机验证

在工程根目录执行，复用已安装的 Node、DevEco、SDK 和 Hvigor 缓存，无需安装新依赖：

```powershell
npm test
# 编译器不接受中文实际路径，须使用独立真实英文目录，非目录联接。
pwsh -File .\tools\build-api26.ps1 -BuildRoot 'D:\XJITApp-organize-20261016-build' -EvidenceName 'project-audit-20261016'
```

测试默认读取本机 DevEco SDK 的 TypeScript，可用 `XJIT_TYPESCRIPT_PATH` 指定已有版本。构建脚本检查现有 DevEco 和 Hvigor 6.26.8；其他机器需配置脚本参数及本地 SDK 配置。

构建默认产出未签名 HAP，正式签名配置保持空值。本地密钥、环境变量、SDK 副本、缓存、截图和大体积验收包均排除在 Git 外。当前仓库只有本地提交，没有远端备份。
