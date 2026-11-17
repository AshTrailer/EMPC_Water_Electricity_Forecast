@echo off
rem Where the rebuilt clamp and the official cube disagree.
setlocal
cd /d "%~dp0..\scripts"
matlab.exe -batch "probe_d02_clamp()" > "%~dp0probe_d02_clamp.log" 2>&1
exit /b %ERRORLEVEL%
