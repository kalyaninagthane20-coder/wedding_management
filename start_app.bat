@echo off
cd /d "%~dp0"
if not exist ".env" ( echo .env file missing - copy .env.example to .env and enter your MySQL password. & pause & exit /b 1 )
if not exist "node_modules" call npm install
start "" http://localhost:3000
node server.js
pause
