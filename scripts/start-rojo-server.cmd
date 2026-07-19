@echo off
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-rojo-server.ps1"
echo.
echo Rojo server stopped. Check the message above, then close this window.
pause
