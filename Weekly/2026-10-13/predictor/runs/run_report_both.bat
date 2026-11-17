@echo off
rem Selftest first, then the real figure set only if the selftest passed.
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "run('C:\Ash\_research_20261013\selftest_report_surfaces.m')" > "C:\Ash\_research_20261013\selftest_report.log" 2>&1
if errorlevel 1 (
  echo SELFTEST FAILED, real run skipped.
  exit /b 1
)
set ATLAS_IN=atlas_v4.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); report_surfaces" > "C:\Ash\_research_20261013\report_surfaces_v4.log" 2>&1
exit /b %ERRORLEVEL%
