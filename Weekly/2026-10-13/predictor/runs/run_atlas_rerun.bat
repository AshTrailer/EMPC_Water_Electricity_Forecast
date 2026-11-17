@echo off
rem Verification run: write the atlas under a different name and compare it
rem against the incumbent atlas_full.mat. Not a replacement run.
set ATLAS_OUT=atlas_rerun.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_full_ensemble_test" > "C:\Ash\_research_20261013\atlas_rerun.log" 2>&1
exit /b %ERRORLEVEL%
