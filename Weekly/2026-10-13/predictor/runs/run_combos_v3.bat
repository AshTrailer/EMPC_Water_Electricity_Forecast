@echo off
rem Offline combination study on the 19-model atlas. Writes combos.mat, which
rem run_ensemble_online_test.m reads as its reference.
set ATLAS_OUT=atlas_v3.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_ensemble_combos" > "C:\Ash\_research_20261013\combos_v3.log" 2>&1
exit /b %ERRORLEVEL%
