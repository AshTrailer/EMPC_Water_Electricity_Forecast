@echo off
rem Atlas v5: M19 candidate regressor fixed, candidate set widened to [1 2 3 4 5 6 8],
rem and the selection criterion saved so the choice can be audited. Then the figures.
set ATLAS_OUT=atlas_v5.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_full_ensemble_test" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\atlas_v5.log" 2>&1
if errorlevel 1 (
  echo ATLAS FAILED, figures skipped.
  exit /b 1
)
set ATLAS_IN=atlas_v5.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); report_surfaces" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\figures_v5.log" 2>&1
exit /b %ERRORLEVEL%
