@echo off
set "SUGER_GODOT=E:\jam game\godot\Godot_v4.4.1-stable_win64.exe"
if not exist "%SUGER_GODOT%" set "SUGER_GODOT=E:\jam game\godot\Godot_v4.4.1-stable_win64_console.exe"
start "" "%SUGER_GODOT%" --path "%~dp0." res://scenes/vehicle_showcase.tscn
