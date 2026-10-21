# 独立验收包刷新

2026-10-17；最新应用源码9da60d1，配套回归423700d，产物验证工具c130320。

## 持久清理标记刷新

- 同步TodoService，entry/src全部128份源码资源SHA256一致，签名配置未变。
- 退出先写cleanup_pending并flush，再清空任务并flush，成功后清除标记；新服务读取标记后封锁普通读写。共享存储重建回归覆盖真实清理删除失败和明确重试。
- 尚非完整账号存储，标记写入前/标记落盘失败窗口仍未解决；不声明真机异常终止恢复通过。
- assembleHap、真实签名/代码签名、独立包身份、API23/26及配置/篡改负向检查通过。
- 最新签名包SHA256：E480F00A33B212767C11560C7F41B7A1663A97C90F60A94D52D4AF582AC24D9F。
- HDC端口8710仍为[Empty]。未安装启动，未执行真实支付，正式应用及会话未动。


## 全部分支等待及双故障诊断刷新

- 同步AuthManager与TodoReminderService：退出等待所有清理结束才返回失败；待办登记与补偿取消双失败同时保留诊断。
- entry/src全部128份源码资源再次SHA256完全一致；独立签名配置未变。
- assembleHap与产物正负向回归通过：真实签名、代码签名、独立包名、最低API23/目标API26及篡改签名检测。
- 最新签名包SHA256：6CB69C46AB3E2C01F5CFEDC9756108D3B481DDA46A24B42E853F95BEA2BD6EDE。
- HDC端口8710为[Empty]，未安装启动或实际登记提醒；正式应用会话未动，未执行真实支付。


## 全量源码资源字节核对

- 对权威源码entry/src下128个文件逐一比对独立工程SHA256。初次发现ReminderGroups修复未同步，以及Materials末尾空行、Constants BOM/末尾空行差异；差异检查确认后两者没有业务逻辑差异。
- 同步上述3份文件后128个源码及资源全部逐字节哈希一致；未修改独立签名配置或应用包身份。
- 独立工程assembleHap成功，签名正向验证、四类配置负向及清单篡改签名负向均通过。
- 最新签名包SHA256：544ACCAA2F461ADF16A44BF3B752C14BE831051E2CEF89F79BC21EEEB4B819EA。
- 本次核对范围为entry/src，未把独立AppScope身份及签名配置强行改成正式工程；不等同全工程逐字节一致。
- 未安装启动或真实支付，正式应用和会话未操作；设备最近查询为空，真机验收仍未完成。


## 退出清理失败恢复产物

- 同步ProfileTab.ets、AuthManager.ets、CampusCompanionService.ets，逐文件SHA256相同，独立签名配置未变。
- 包含退出失败可见及按钮重试、课程伴随清理错误上报、实况窗结束失败继续其他清理、设置/卡片故障不阻断课程提醒取消。
- assembleHap成功；真实签名与代码签名验证通过；最低API23、目标API26、独立包身份检查通过。
- 四类配置错误及清单篡改副本均被准确检出，原始HAP哈希不变。
- 最新签名包SHA256：CB4595DDC4B2F9ECCACCCDB7B05441BF9DFE42D7E94CB424C91EE0A5254A7A46。
- HDC端口8710仍为[Empty]。本轮未安装启动，正式应用和会话未操作，未执行真实支付。


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
