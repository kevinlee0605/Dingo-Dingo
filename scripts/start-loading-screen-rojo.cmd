@echo off
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-loading-screen-rojo.ps1"
echo.
echo Loading-screen Rojo server stopped. Check the message above, then close this window.
pause
