@echo off
setlocal
set "GAME_GODOT=%A3GAME_GODOT_EXECUTABLE%"
if defined GAME_GODOT if not exist "%GAME_GODOT%" set "GAME_GODOT="
if not defined GAME_GODOT if exist "%LOCALAPPDATA%\A3Game\Godot\4.5.1-stable\windows-x86_64\Godot_v4.5.1-stable_win64.exe" set "GAME_GODOT=%LOCALAPPDATA%\A3Game\Godot\4.5.1-stable\windows-x86_64\Godot_v4.5.1-stable_win64.exe"
if not defined GAME_GODOT for /f "delims=" %%G in ('where godot4.exe 2^>nul') do set "GAME_GODOT=%%G"
if not defined GAME_GODOT for /f "delims=" %%G in ('where godot.exe 2^>nul') do set "GAME_GODOT=%%G"
if not defined GAME_GODOT (
 echo Install Godot 4.5.1 or set A3GAME_GODOT_EXECUTABLE to its executable.
 echo You can also open project/project.godot in the Godot editor.
 pause
 exit /b 1
)
"%GAME_GODOT%" --headless --editor --path "%~dp0project" --import --quit
if errorlevel 1 (
 echo Godot import failed. Open project/project.godot to inspect errors.
 pause
 exit /b 1
)
start "" "%GAME_GODOT%" --path "%~dp0project"
