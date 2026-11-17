@echo off
rem Variable census of the two score cubes.
setlocal
cd /d "%~dp0..\scripts"
matlab.exe -batch "probe_atlas_fields()" > "%~dp0probe_atlas_fields.log" 2>&1
exit /b %ERRORLEVEL%
