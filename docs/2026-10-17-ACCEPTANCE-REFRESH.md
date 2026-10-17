# 独立验收包刷新

2026-10-17；最新应用源码基线a5f25f2，产物验证工具基线fa42d88。

## 最新诊断及状态修复产物

- 同步CampusCompanionService.ets，逐文件哈希相同，独立签名配置前后不变，assembleHap成功。
- 包含旧关闭结果不覆盖重开状态、设置选项白名单、1700002 SDK定义与实际根因区分、本应用提醒数量口径修正。
- 实际运行acceptance-artifact-regression.ps1：verify-app成功，签名及代码签名通过；错误最低API、正式包预期负向测试通过。
- 签名HAP实际清单：com.xjit.app.acceptance，minAPIVersion=60100023，targetAPIVersion=260000026。
- 最新SHA256：04A7ADC493249AF195A79ACFC3AC71B38A404895C32A25659974783E2D73A9D5。
- 签名工具仍提示可选outproof参数缺失，但返回验证成功；不声明零警告。
- HDC端口8710为[Empty]。未安装启动、未执行真实支付，正式包及会话保持不动。


## 授权与系统预检竞态修复刷新

- 同步CampusCompanionService.ets并核对SHA256相同，签名配置前后哈希一致；assembleHap成功。
- 包含旧发布错误、通知授权等待、实况窗能力等待的版本校验，配套回归覆盖退出或关闭后的迟到结果。
- 最新签名包SHA256：B018D7017095E4C10C41C0746D0594D407851A328939C58DA75FE594098D0C08。
- 直接从签名HAP压缩条目的module.json读取：bundleName=com.xjit.app.acceptance，minAPIVersion=60100023，targetAPIVersion=260000026，apiReleaseType=Release。该元数据符合最低API23、目标API26；不代表API23运行验证。
- HDC端口8710仍为[Empty]，未安装启动、未执行真实支付，正式包及会话不动。

## 提醒发布时效修复刷新

- 在前版基础上同步CampusCompanionService.ets与TodoReminderService.ets，逐文件SHA256匹配。
- 课程、待办均在逐条系统发布前重新检查触发时间，跳过系统等待后已过期的提醒；不把模拟回归当作送达证据。
- 独立工程assembleHap签名构建成功；签名配置前后SHA256不变。
- 最新签名包SHA256：27263036016BE4E987BE78F7D8E617BC1E51DB0A0B45D7FA291C5FD540EEEB67。
- HDC端口8710仍为[Empty]，未安装或启动，正式应用会话不动。

## 前版记录

- 既有独立工程：D:\XJITApp-api23-login-simulator；沿用原有独立签名配置，构建前后配置SHA256一致，未读取或导出签名密钥。
- 对比既有基线a4be718，将entry/src下2个变化文件复制到独立工程，逐文件SHA256匹配：TodoPage.ets、TodoService.ets。
- 使用既有DevEco hvigor执行assembleHap成功，生成entry/build/default/outputs/default/entry-default-signed.hap。
- 新签名包SHA256：99315E37A2A37E8D8FF995ABADDB817773144004F415AAC96A379AD1B85BD873。
- HDC端口8710查询设备返回[Empty]。本轮未执行安装、启动、通知投递或支付；未触碰正式应用会话。

该记录证明独立工程签名构建成功，不证明API23运行、真机渲染、1700002修复、系统提醒送达、桌面卡片展示或小艺分发。签名验收包与源码包隔离，未推送、未正式发布。
