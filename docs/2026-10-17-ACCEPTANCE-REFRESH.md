# 独立验收包刷新

2026-10-17；应用源码基线81d6f2b。

- 既有独立工程：D:\XJITApp-api23-login-simulator；沿用原有独立签名配置，构建前后配置SHA256一致，未读取或导出签名密钥。
- 对比既有基线a4be718，将entry/src下2个变化文件复制到独立工程，逐文件SHA256匹配：TodoPage.ets、TodoService.ets。
- 使用既有DevEco hvigor执行assembleHap成功，生成entry/build/default/outputs/default/entry-default-signed.hap。
- 新签名包SHA256：99315E37A2A37E8D8FF995ABADDB817773144004F415AAC96A379AD1B85BD873。
- HDC端口8710查询设备返回[Empty]。本轮未执行安装、启动、通知投递或支付；未触碰正式应用会话。

该记录证明独立工程签名构建成功，不证明API23运行、真机渲染、1700002修复、系统提醒送达、桌面卡片展示或小艺分发。签名验收包与源码包隔离，未推送、未正式发布。
