@echo off
setlocal enabledelayedexpansion
title KBU PC Inventory Tool

REM ============================================================
REM  KBU PC Inventory Tool -- Windows Batch Launcher
REM  Double-click this file to run the inventory scanner.
REM ============================================================

REM Detect project root (directory where this BAT file lives)
set "PROJECT_ROOT=%~dp0"
set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"

REM Path to the main PowerShell script
set "SCRIPT_PATH=%PROJECT_ROOT%\src\KBU_PC_Inventory.ps1"

REM Check that PowerShell is available
where powershell.exe >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo  [ERROR] PowerShell is not found on this system.
    echo.
    echo  KBU PC Inventory Tool requires PowerShell 5.1 or later.
    echo  Please install or enable PowerShell and try again.
    echo.
    pause
    exit /b 1
)

REM Check that the script file exists
if not exist "%SCRIPT_PATH%" (
    echo.
    echo  [ERROR] Inventory script not found:
    echo    %SCRIPT_PATH%
    echo.
    echo  Please ensure the repository is extracted completely.
    echo.
    pause
    exit /b 1
)

REM Launch PowerShell with ExecutionPolicy Bypass
REM   -NoProfile:  skip profile scripts for consistent behavior
REM   -NoLogo:     suppress copyright banner
REM   -File:       run the specified script
echo.
echo  Starting KBU PC Inventory Tool...
echo  Project root: %PROJECT_ROOT%
echo.

powershell.exe -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"

REM If PowerShell returned an error code, pause so the user can read it
if %ERRORLEVEL% neq 0 (
    echo.
    echo  [WARNING] The inventory tool exited with code %ERRORLEVEL%.
    echo  If this is unexpected, run the script manually from PowerShell:
    echo    powershell -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
    echo.
    pause
)

endlocal
