@echo off
rem Extended atlas: 18 models, M13 to M16 folded in. Writes atlas_ext.mat.
set ATLAS_OUT=atlas_ext.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_full_ensemble_test" > "C:\Ash\_research_20261013\atlas_ext.log" 2>&1
exit /b %ERRORLEVEL%
