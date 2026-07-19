$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ProjectRoot "logs"
$OutLog = Join-Path $LogDir "rojo.out.log"
$ErrLog = Join-Path $LogDir "rojo.err.log"

function Resolve-RojoExecutable {
    if ($env:ROJO_EXE) {
        if (Test-Path -LiteralPath $env:ROJO_EXE -PathType Leaf) {
            return (Resolve-Path -LiteralPath $env:ROJO_EXE).Path
        }
        throw "ROJO_EXE does not point to a file: $env:ROJO_EXE"
    }

    $storageRoot = Join-Path $HOME ".aftman\tool-storage\rojo-rbx\rojo"
    if (Test-Path -LiteralPath $storageRoot -PathType Container) {
        $storedRojo = Get-ChildItem -LiteralPath $storageRoot -Filter "rojo.exe" -File -Recurse |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($storedRojo) {
            return $storedRojo.FullName
        }
    }

    $command = Get-Command rojo -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $repoRojo = Join-Path $ProjectRoot "bin\rojo.exe"
    if (Test-Path -LiteralPath $repoRojo -PathType Leaf) {
        return $repoRojo
    }

    throw "Rojo was not found. Run 'aftman install' or set ROJO_EXE to a Rojo executable."
}

$RojoExe = Resolve-RojoExecutable

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Set-Location $ProjectRoot
& $RojoExe serve default.project.json --address 127.0.0.1 --port 34872 *> $OutLog
