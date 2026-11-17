@echo off
rem Two candidates from the price-history set: M02 per-column selection, M05 profile PCA.
setlocal
cd /d "%~dp0..\scripts"
set NAME=%1
if "%NAME%"=="" set NAME=m02_m05
matlab.exe -batch "diagnose_m02_m05('%NAME%')" > "%~dp0%NAME%.log" 2>&1
exit /b %ERRORLEVEL%
