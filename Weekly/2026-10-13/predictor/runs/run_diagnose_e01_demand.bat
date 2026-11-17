@echo off
rem E01 demand information gate and candidate. Reads atlas_60d.mat,
rem official_60d.mat and predispatch_30min_VIC1.csv read-only, writes
rem research\verify\e01_demand.json.
rem The log name is a parameter: reusing one is not safe, see run_atlas_60d.bat.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=e01_demand
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); diagnose_e01_demand" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
