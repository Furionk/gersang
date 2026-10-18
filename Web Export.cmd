@echo off
setlocal
set "GODOT_EXE=R:\App\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot was not found. Open this project in Godot and use Project - Tools - Web Export Studio.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --editor --path "%~dp0." -- --web-export-studio
