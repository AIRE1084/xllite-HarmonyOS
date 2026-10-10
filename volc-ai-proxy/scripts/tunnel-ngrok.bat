@echo off
chcp 65001 >nul
echo 启动 ngrok 隧道：http://localhost:3000
ngrok http 3000
pause
