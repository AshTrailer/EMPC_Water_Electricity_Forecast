@echo off
rem Which sample of the price series the cube calls the actual.
setlocal
cd /d "%~dp0..\scripts"
matlab.exe -batch "probe_d02_offset()" > "%~dp0probe_d02_offset.log" 2>&1
exit /b %ERRORLEVEL%
