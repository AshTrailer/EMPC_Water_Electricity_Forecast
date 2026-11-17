@echo off
rem Three diagnostics on the scored surface: D02, D03, D06.
setlocal
cd /d "%~dp0..\scripts"
set NAME=%1
if "%NAME%"=="" set NAME=d02_d03_d06
matlab.exe -batch "diagnose_d02_d03_d06('%NAME%')" > "%~dp0%NAME%.log" 2>&1
exit /b %ERRORLEVEL%
