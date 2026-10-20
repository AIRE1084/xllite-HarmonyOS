# 掌上新理工 HarmonyOS 验收包模拟器验证报告

**日期**：2026-10-20
**执行者**：simulator-verify
**模拟器**：127.0.0.1:5555
**HAP**：`D:\XJITApp-api23-login-simulator\entry\build\default\outputs\default\entry-default-signed.hap`
**包名**：`com.xjit.app.acceptance`

---

## 1. 安装状态

| 操作 | 结果 | 说明 |
|------|------|------|
| hdc 连接 | 通过 | hdc 3.2.0f，目标 127.0.0.1:5555 |
| 覆盖安装 `-r`（默认） | **失败** | `code:9568332 install sign info inconsistent` |
| 覆盖安装 `-r -s 8710` | **失败** | `code:9568269 install file path invalid` |
| 卸载验收包后全新安装 | **成功** | `install bundle successfully`（仅针对验收包，未触碰正式包 com.xjit.app） |

**错误原因说明**：模拟器中残留旧版验收包（appId 不同），`-r` 因签名信息不一致拒绝覆盖；`-s 8710` 因文件路径无效失败。最终通过 `hdc uninstall com.xjit.app.acceptance` + 全新 `hdc install` 完成。

---

## 2. versionCode / versionName

**来源**：`bm dump -n com.xjit.app.acceptance`

| 字段 | 值 |
|------|----|
| `versionCode` | **1000000** |
| `versionName` | **1.0.0** |
| `apiTargetVersion` | **260000026**（API 23 目标） |
| `appProvisionType` | **debug** |
| `appIdentifier` | **6918745147644588845**（新包标识） |

**结论**：versionCode=1000000 确认已安装为 task-4 构建的新验收包。

---

## 3. 启动验证

**命令**：`aa start -b com.xjit.app.acceptance -a EntryAbility`

**结果**：`start ability successfully.`

**aa dump 状态**：
- `AbilityRecord` state: **#READY**
- `app state`: **#FOREGROUND**
- `mission name`: `[#com.xjit.app.acceptance:entry:EntryAbility]`

**结论**：EntryAbility 正常启动并处于前台，未崩溃。

---

## 4. 功能验证

### 4.1 宿舍绑定 / 电费查询

**状态**：**未验证**（数据面阻断）

**原因**：应用启动后停留在 `pages/LoginPage`（登录墙）。模拟器的 `xjit_session` 偏好文件为空，`loadSession()` 因协议校验失败已清空会话。登录走统一网关 `https://xllite.sayqz.com`（`/api/v1/auth/login`），需真实校园账号凭据。shell(uid=2000) 无 root 权限，无法向 `/data/app/el2/100/base/com.xjit.app.acceptance/preferences/` 注入模拟会话。

**静态确认（包内容核对）**：
- `HAP modules.abc` 常量池含 `newcard.electricity.account`、`newcard.electricity.recharge`、`ElectricityPage.ets` ✅
- `HomeTab.ets` quickFeatures() 顺序（电费查询置顶，task-2 fc3cd78）已打进包 ✅

### 4.2 课表时刻映射（8 节制）

**UI 显示**：**未验证**（数据面阻断，无法登录进入课表页）

**静态验证（包内容核对，通过）**：
- `HAP modules.abc` 常量池包含以下 8 节时刻（与用户确认的 2026 秋季作息一致）：
  - `10:00` / `10:55` / `12:00` / `12:55` / `16:00` / `16:55` / `18:30` / `19:25` ✅
  - 第 7 节 **18:30-19:15**（晚自习）✅
  - 第 8 节 **19:25-20:10** ✅
  - 旧 9/10 节时刻 `20:30` / `21:15` / `21:25` / `22:10` 在 HAP 中**零残留** ✅
- `ClassTime` 常量存在 ✅，`ALL_TIMES` / `getCourseMinutes` 消费方链路正常

**结论**：课表时刻数据面验证**通过**（8 节映射正确，旧节次已清除）。

**补充（2026-10-20 晚，推翻本节下午时刻）**：用户更正真实作息为「上午 10:00–13:40、下午 16:00–19:40，45 分一节、小课间 10 分、大课间 20 分」。因此第 7/8 节不是 `18:30/19:25`，而是 **18:00–18:45 / 18:55–19:40**；本节记录的 HAP 常量核对与结论仅对当时那个包有效，已被 [ClassTime.ets](../entry/src/main/ets/utils/ClassTime.ets) 修正。

### 4.3 支付跳转适配（不执行真实支付）

**UI 验证**：**未验证**（数据面阻断，无法登录进入 RechargePage）

**静态验证（包内容核对，通过）**：
- `HAP modules.abc` 常量池含 `officialTransferUrl`、`h5Url`、`htmlPost`、`newcard.recharge.create_order` ✅
- `RechargePage.ets` L90-106 分支顺序（`htmlPost` → `officialTransferUrl` → `h5Url`）已打进包（task-4 同步，提交 2bc313b）✅
- payCode 契约（01=支付宝，02=微信）由 task-3 在服务端契约层核对完成 ✅
- 网关 `create_order` 走 Web 表单/h5 路径，无需端侧 SDK ✅

**结论**：支付跳转代码在包内确认，未执行任何真实支付操作。

---

## 5. 截图与日志

**截图与布局目录**：`D:\整理_\01_项目代码\jiji\XJITApp\docs\simulator-verify-20261020-164745\`

| 文件 | 说明 |
|------|------|
| `00-launch.jpeg` | 应用启动后截图（LoginPage） |
| `01-final-state.jpeg` | 最终状态截图（LoginPage） |
| `00-layout.json` / `layout-after-restart.json` | 启动前后 UI 布局树 |
| `install-log.txt` | 安装操作日志（含错误码） |
| `bmdump-after-install.txt` | 安装后完整 bm dump |
| `aa-dump.txt` | aa 状态 dump |
| `hilog-login-flow.txt` | 登录流程 hilog（系统 WMS/AMS） |
| `hilog-app-warn-error.txt` | 应用相关 WARN/ERROR 过滤结果 |
| `hap-unpacked/` | HAP 解包目录（modules.abc、sourceMaps.map、module.json） |
| `abc-string-check.csv` | HAP 字节码关键字符串扫描结果 |

**hilog 摘要**（`hilog-app-warn-error.txt`，共 42 行）：
- 全部为系统 WMS/SCB 窗口会话管理 INFO/WARN 日志（`startSceneFromOther`、`findTransitionController`、`border radius` 等）
- **无应用自身（com.xjit.app.acceptance）ERROR/WARN 级日志**
- 网关请求未触发（无凭据输入），故无网络层日志

---

## 6. git 状态

| 项目 | 路径 | 状态 |
|------|------|------|
| 验收工程 | `D:\XJITApp-api23-login-simulator` | **非 git 仓库**（无 .git） |
| 主源码 | `D:\整理_\01_项目代码\jiji\XJITApp` | HEAD = **2bc313b**（`Add official transfer URL branch to RechargePage`，**未 push**） |
| 工作区改动 | — | 仅新增 `docs/simulator-verify-20261020-164745/`，**零源码改动** |

---

## 7. 总结

| 验证项 | 结果 |
|--------|------|
| 覆盖安装（验收包） | 通过（需先卸载旧包，签名不一致导致 -r 失败） |
| versionCode 确认 | 通过（1000000 / 1.0.0） |
| EntryAbility 启动 | 通过（FOREGROUND / READY） |
| 电费查询 UI | **未验证**（登录墙阻断） |
| 课表时刻（8 节） | **静态通过**（HAP 字节码确认 18:30/19:25/无 9-10 节） |
| 支付跳转适配 | **静态通过**（HAP 字节码确认 officialTransferUrl/h5Url 分支） |
| 截图与日志 | 已保存至 `docs/simulator-verify-20261020-164745/` |
| git 状态 | 验收工程无 git；主源码 HEAD=2bc313b，工作区干净 |

**后续建议**：如需补验电费/课表/充值三个 UI 项，需在模拟器登录网关 `https://xllite.sayqz.com`（`/api/v1/auth/login`）时提供测试校园账号，完成登录后即可在同一模拟器上导航验证。
