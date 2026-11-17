@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "run('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts\probe_ar_sweep.m')" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\probe_ar_sweep.log" 2>&1
exit /b %ERRORLEVEL%