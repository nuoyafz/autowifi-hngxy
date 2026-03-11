@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PS1_FILE=%SCRIPT_DIR%校园网自动登录.ps1"

if not exist "%PS1_FILE%" (
    echo Error: 校园网自动登录.ps1 not found!
    pause
    exit /b 1
)

powershell -ExecutionPolicy Bypass -File "%PS1_FILE%"
