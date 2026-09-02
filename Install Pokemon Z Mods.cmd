@echo off
setlocal
title Pokemon Z Mods Installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\install-gui.ps1"
if errorlevel 1 (
  echo.
  echo The installer did not finish successfully.
  pause
)
endlocal
