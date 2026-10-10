@echo off
chcp 65001 >nul
echo 启动 localtunnel 隧道：http://localhost:3000
npx localtunnel --port 3000
pause
