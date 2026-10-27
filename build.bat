@echo off
setlocal
cd /d "%~dp0"

echo ==============================================
echo Building Iron Pit (Windows Standalone Release)
echo ==============================================

if not exist "build" mkdir "build"

set "GODOT_BIN=C:\Users\marci\Documents\game_dev\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe"

"%GODOT_BIN%" --headless --path "." --export-release "Windows Desktop" "build\IronPit.exe"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Build created at: build\IronPit.exe
) else (
    echo.
    echo [ERROR] Build failed with exit code %ERRORLEVEL%
)

echo.
pause
