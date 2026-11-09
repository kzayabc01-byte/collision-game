@echo off
setlocal
set "PUMPKIN_GODOT=E:\jam game\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%PUMPKIN_GODOT%" set "PUMPKIN_GODOT=D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%PUMPKIN_GODOT%" (
  echo Godot was not found. Open scenes/pumpkin_studio.tscn in Godot and press F6.
  pause
  exit /b 1
)
"%PUMPKIN_GODOT%" --headless --editor --path "%~dp0." --import --quit
if errorlevel 1 (
  echo Model import failed. Open project.godot in Godot to inspect errors.
  pause
  exit /b 1
)
start "" "%PUMPKIN_GODOT%" --path "%~dp0." res://scenes/pumpkin_studio.tscn
