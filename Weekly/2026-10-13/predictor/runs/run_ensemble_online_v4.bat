@echo off
rem Online engine against the rebuilt atlas and the offline reference.
set ATLAS_OUT=atlas_v4.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_ensemble_online_test" > "C:\Ash\_research_20261013\ensemble_online_v4.log" 2>&1
exit /b %ERRORLEVEL%
