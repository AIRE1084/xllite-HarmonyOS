# Volc AI Proxy 本地中转站

这是一个本地部署的火山引擎 Ark API 中转站，使用 Node.js + Express + phpStudy MySQL。功能包括管理后台、用户 API Key、5小时限制、日限制、周限制、调用统计、日志、状态检查和本地隧道脚本。

## 目录

项目位于：`D:\jiji\XJITApp\volc-ai-proxy`

## 启动前准备

先打开 phpStudy，启动 MySQL。默认连接配置在 `.env`：host=127.0.0.1，port=3306，user=root，password=root，database=volc_ai_proxy。

如果你的 phpStudy MySQL 密码不是 root，请改 `.env` 里的 `DB_PASSWORD`。

如果只想先测试后台和额度逻辑，可以不填 `ARK_API_KEY`，系统会进入 Mock 模式。要真实中转火山引擎，必须把 `.env` 中的 `ARK_API_KEY` 改成你的 Ark API Key。

## 一键启动

双击：`scripts/start.bat`

或者在 PowerShell 中执行：

```powershell
cd D:\jiji\XJITApp\volc-ai-proxy
npm install
npm run init-db
npm start
```

## 后台

地址：`http://localhost:3000/admin`

默认账号：admin
默认密码：admin123

## 中转调用

本地中转地址：`http://localhost:3000/v1/chat/completions`

请求头使用后台创建的用户 Key：

```text
Authorization: Bearer sk-local-xxxx
```

## 用户额度接口

```text
GET http://localhost:3000/user/stats
Authorization: Bearer 用户API_KEY
```

## 状态检查

```text
GET http://localhost:3000/api/status
```

后台里也有“实时检查”，会检查本地服务、数据库、Ark 配置状态。

## 隧道

ngrok：双击 `scripts/tunnel-ngrok.bat`

localtunnel：双击 `scripts/tunnel-localtunnel.bat`

## 自测

服务启动后执行：

```powershell
npm run test:smoke
```

这会测试状态接口、后台登录、创建测试用户、用户额度接口。
