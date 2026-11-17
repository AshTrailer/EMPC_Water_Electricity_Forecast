@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "run('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts\report_numbers.m')" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\numbers_v5.log" 2>&1
exit /b %ERRORLEVEL%