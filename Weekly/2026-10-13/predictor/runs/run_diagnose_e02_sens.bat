@echo off
rem E02 price sensitivity gate and candidate. Reads atlas_60d.mat,
rem official_60d.mat, sens_vic1.csv and predispatch_30min_VIC1.csv read-only,
rem writes research\verify\e02_sens.json.
rem The log name is a parameter: reusing one is not safe, see run_atlas_60d.bat.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=e02_sens
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); diagnose_e02_sens" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
