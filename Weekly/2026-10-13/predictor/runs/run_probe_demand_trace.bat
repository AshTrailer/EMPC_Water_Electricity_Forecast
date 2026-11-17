@echo off
rem Step by step trace of the demand lookup for a handful of cube cells.
rem Reads predispatch_30min_VIC1.csv read-only, writes no file.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=probe_demand_trace
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); probe_demand_trace" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
