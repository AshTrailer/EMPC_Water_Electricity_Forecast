@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "run('C:\Ash\_research_20261013\report_ranks.m')" > "C:\Ash\_research_20261013\report_ranks.log" 2>&1
exit /b %ERRORLEVEL%