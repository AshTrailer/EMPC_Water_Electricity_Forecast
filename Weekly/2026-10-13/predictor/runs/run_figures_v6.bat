@echo off
set ATLAS_IN=atlas_v5.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); report_surfaces" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\figures_v6.log" 2>&1
exit /b %ERRORLEVEL%