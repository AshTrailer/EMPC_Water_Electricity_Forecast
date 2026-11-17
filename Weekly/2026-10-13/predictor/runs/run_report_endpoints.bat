@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "run('C:\Ash\_research_20261013\report_endpoints.m')" > "C:\Ash\_research_20261013\report_endpoints.log" 2>&1
exit /b %ERRORLEVEL%