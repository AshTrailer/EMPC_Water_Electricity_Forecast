@echo off
rem Small synthetic atlas through the drawing code, to check syntax and layout
rem without loading the real 700 MB atlas.
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "run('C:\Ash\_research_20261013\selftest_report_surfaces.m')" > "C:\Ash\_research_20261013\selftest_report.log" 2>&1
exit /b %ERRORLEVEL%
