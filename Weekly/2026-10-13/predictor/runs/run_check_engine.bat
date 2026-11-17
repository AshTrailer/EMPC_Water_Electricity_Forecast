@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "run('C:\Ash\_research_20261013\check_engine_offline.m')" > "C:\Ash\_research_20261013\check_engine.log" 2>&1
exit /b %ERRORLEVEL%
