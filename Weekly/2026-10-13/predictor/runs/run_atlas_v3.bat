@echo off
rem 19 models: M19 lead-adaptive AR order added. Writes atlas_v3.mat.
set ATLAS_OUT=atlas_v3.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_full_ensemble_test" > "C:\Ash\_research_20261013\atlas_v3.log" 2>&1
exit /b %ERRORLEVEL%
