@echo off
rem Run the E09 structural read diagnostic. Argument 1 is the cell mode:
rem "aligned" restricts to cells on the half hour publication grid, "all" uses
rem every band cell with the origin and target snapped to that grid.
setlocal
cd /d "%~dp0..\scripts"
set NAME=%1
if "%NAME%"=="" set NAME=e09_stack
matlab.exe -batch "diagnose_e09_stack('%NAME%')" > "%~dp0%NAME%.log" 2>&1
exit /b %ERRORLEVEL%
