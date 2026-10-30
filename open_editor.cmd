@echo off
chcp 65001 >nul
python "%~dp0run.py" editor
if errorlevel 1 pause
