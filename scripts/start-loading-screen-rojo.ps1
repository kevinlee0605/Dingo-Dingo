$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "loading-screen.project.json"
$LogDir = Join-Path $ProjectRoot "logs"
$OutLog = Join-Path $LogDir "loading-screen-rojo.out.log"
$Port = 34873

function Resolve-RojoExecutable {
    $command = Get-Command rojo -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $aftmanRojo = Join-Path $HOME ".aftman\bin\rojo.exe"
    if (Test-Path -LiteralPath $aftmanRojo -PathType Leaf) {
        return $aftmanRojo
    }

    throw "Rojo was not found. Run 'aftman install' before starting the loading-screen server."
}

$RojoExe = Resolve-RojoExecutable

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Set-Location $ProjectRoot
Write-Host "Starting the safe loading-screen and responsive-UI Rojo project."
Write-Host "Only ReplicatedFirst and the responsive adapter are mapped; StarterGui is not managed by this server."
Write-Host "Connect the Studio Rojo plugin to localhost:$Port."
& $RojoExe serve $ProjectFile --address 127.0.0.1 --port $Port 2>&1 | Tee-Object -FilePath $OutLog
