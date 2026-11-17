@echo off
set ATLAS_OUT=atlas_v3.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_ensemble_online_test" > "C:\Ash\_research_20261013\ensemble_online.log" 2>&1
exit /b %ERRORLEVEL%
