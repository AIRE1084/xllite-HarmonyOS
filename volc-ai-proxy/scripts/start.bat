@echo off
chcp 65001 >nul
cd /d "%~dp0.."
echo [1/3] 检查依赖...
if not exist node_modules call npm install
echo [2/3] 初始化 MySQL 数据库...
call npm run init-db
echo [3/3] 启动服务...
call npm start
pause
