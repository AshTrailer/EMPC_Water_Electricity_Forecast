@echo off
rem Shapes of the four dimensional atlas read, and the baseline band ratio.
setlocal
cd /d "%~dp0..\scripts"
set NAME=%1
if "%NAME%"=="" set NAME=probe_m02_shapes
matlab.exe -batch "probe_m02_shapes" > "%~dp0%NAME%.log" 2>&1
exit /b %ERRORLEVEL%
