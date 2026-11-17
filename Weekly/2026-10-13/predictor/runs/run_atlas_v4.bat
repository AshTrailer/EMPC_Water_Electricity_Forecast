@echo off
rem M19 rebuilt on (slot, lead, day, order), PART 2 scored on days 29..120
rem with the trailing window taken at d-1. Writes atlas_v4.mat.
set ATLAS_OUT=atlas_v4.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_full_ensemble_test" > "C:\Ash\_research_20261013\atlas_v4.log" 2>&1
exit /b %ERRORLEVEL%
