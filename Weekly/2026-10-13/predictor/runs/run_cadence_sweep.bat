@echo off
set ATLAS_OUT=atlas_ext.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_update_cadence_sweep" > "C:\Ash\_research_20261013\cadence_sweep.log" 2>&1
exit /b %ERRORLEVEL%
