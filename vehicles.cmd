@echo off
set "SUGER_GODOT=D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%SUGER_GODOT%" set "SUGER_GODOT=D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%SUGER_GODOT%" set "SUGER_GODOT=E:\jam game\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%~dp0.godot\global_script_class_cache.cfg" goto import_project
findstr /c:"ArenaRoute" "%~dp0.godot\global_script_class_cache.cfg" >nul 2>&1
if errorlevel 1 goto import_project
goto launch_game
:import_project
"%SUGER_GODOT%" --headless --editor --path "%~dp0." --import --quit
if errorlevel 1 (
  echo Project import failed. Open project.godot in Godot to inspect errors.
  pause
  exit /b 1
)
:launch_game
start "" "%SUGER_GODOT%" --path "%~dp0." res://scenes/vehicle_showcase.tscn
