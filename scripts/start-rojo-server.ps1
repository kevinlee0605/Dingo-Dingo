$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RojoExe = "C:\Users\Andrew\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe"
$LogDir = Join-Path $ProjectRoot "logs"
$OutLog = Join-Path $LogDir "rojo.out.log"
$ErrLog = Join-Path $LogDir "rojo.err.log"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Set-Location $ProjectRoot
& $RojoExe serve default.project.json --address 127.0.0.1 --port 34872 *> $OutLog
