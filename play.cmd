@echo off
setlocal
set "SUGER_GODOT=E:\jam game\godot\Godot_v4.4.1-stable_win64.exe"
if not exist "%SUGER_GODOT%" set "SUGER_GODOT=E:\jam game\godot\Godot_v4.4.1-stable_win64_console.exe"
if not exist "%SUGER_GODOT%" (
  echo Godot was not found. Import project.godot using Godot 4.4 or newer.
  pause
  exit /b 1
)
start "" "%SUGER_GODOT%" --path "%~dp0."
