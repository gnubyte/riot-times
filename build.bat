@echo off
setlocal EnableDelayedExpansion
rem ============================================================
rem  Riot Times - Windows build script
rem  Usage:  build.bat            (release build -> build\RiotTimes\)
rem          build.bat debug      (debug build)
rem  Set GODOT env var to override the engine binary location.
rem ============================================================
cd /d "%~dp0"

set "GODOT=%GODOT%"
if "%GODOT%"=="" (
    if exist "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" (
        set "GODOT=C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
    ) else if exist "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe" (
        set "GODOT=C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
    ) else (
        where godot >nul 2>nul && set "GODOT=godot"
    )
)
if "%GODOT%"=="" (
    echo [build] ERROR: Godot not found. Set the GODOT env var to your engine binary.
    exit /b 1
)

set "MODE=release"
set "FLAG=--export-release"
if /i "%~1"=="debug" (
    set "MODE=debug"
    set "FLAG=--export-debug"
)

echo [build] engine : %GODOT%
echo [build] mode   : %MODE%
echo [build] output : build\RiotTimes\

rem fail fast on broken scripts before exporting
echo [build] checking scripts...
"%GODOT%" --headless --path . --import >nul 2>&1
if errorlevel 1 (
    echo [build] ERROR: script import/parse failed. Run Godot editor for details.
    exit /b 1
)

rem clean previous build (keep any user data files)
if exist "build\RiotTimes" rmdir /s /q "build\RiotTimes"
mkdir "build\RiotTimes" 2>nul

echo [build] exporting Windows Desktop...
"%GODOT%" --headless --path . %FLAG% "Windows Desktop"
if errorlevel 1 (
    echo [build] ERROR: export failed.
    exit /b 1
)

if not exist "build\RiotTimes\RiotTimes.exe" (
    echo [build] ERROR: build\RiotTimes\RiotTimes.exe missing after export.
    exit /b 1
)

for %%F in ("build\RiotTimes\RiotTimes.exe") do set "SIZE=%%~zF"
set /a SIZE_MB=%SIZE% / 1048576
echo.
echo [build] SUCCESS: build\RiotTimes\RiotTimes.exe  (~%SIZE_MB% MB)
echo [build] Run it with build\RiotTimes\RiotTimes.exe
endlocal
exit /b 0
