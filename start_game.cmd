@echo off
chcp 65001 >nul
python "%~dp0run.py" play
if errorlevel 1 pause
