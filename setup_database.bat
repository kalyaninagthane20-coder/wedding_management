@echo off
REM Creates the wedding_db database (tables + sample data + views + procedures + triggers).
REM You will be asked for your MySQL password once.
cd /d "%~dp0"
set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
if not exist "%MYSQL%" set "MYSQL=mysql"
set /p DBUSER=MySQL user [root]:
if "%DBUSER%"=="" set DBUSER=root
"%MYSQL%" -u %DBUSER% -p --default-character-set=utf8mb4 < sql\00_run_all.sql
if errorlevel 1 ( echo. & echo Setup FAILED - check the user name / password above. ) else ( echo. & echo Database ready. Next: copy .env.example to .env, put your password in it, then run start_app.bat )
pause
