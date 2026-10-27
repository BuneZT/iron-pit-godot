param(
    [switch]$DebugBuild,
    [switch]$RunTests
)

$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$godotExe = "C:\Users\marci\Documents\game_dev\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe"

if (-not (Test-Path $godotExe)) {
    Write-Error "Godot binary not found at: $godotExe"
    exit 1
}

if ($RunTests) {
    Write-Host "Running test suite before export..." -ForegroundColor Yellow
    & $godotExe --headless --path $projectRoot -s res://tests/run_tests.gd
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Tests failed! Aborting export."
        exit $LASTEXITCODE
    }
}

$exportMode = if ($DebugBuild) { "--export-debug" } else { "--export-release" }
$modeLabel = if ($DebugBuild) { "Debug" } else { "Release" }

New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot "build") | Out-Null
Write-Host "Building Iron Pit for Windows ($modeLabel)..." -ForegroundColor Cyan

& $godotExe --headless --path $projectRoot $exportMode "Windows Desktop" "build\IronPit.exe"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Standalone build ready at: build\IronPit.exe" -ForegroundColor Green
} else {
    Write-Error "Export failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
