@echo off
cd /d "%~dp0.."
"C:\Users\Andrew\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe" serve default.project.json --address 127.0.0.1 --port 34872
echo.
echo Rojo server stopped. Check the message above, then close this window.
pause
