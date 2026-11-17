@echo off
rem Which product puts impossible prices into the official cube. Read-only.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=official_outliers
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); probe_official_outliers" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
