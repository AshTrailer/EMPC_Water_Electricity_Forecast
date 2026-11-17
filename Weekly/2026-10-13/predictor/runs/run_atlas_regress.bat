@echo off
rem Regression run: the 120-day window on the 288-column axis, into its own
rem atlas, so every column it shares with atlas_v5 can be compared bit for bit.
rem
rem The model set keeps every key that a combination rule names (MW, T28,
rem T28_AR4, T28_DMS4, anchor_mix, MW_run) plus one model from each family whose
rem code the 376-column refactor touched. The three 1-hour smoothers are dropped
rem because they are dropped in the real run too.
rem
rem The log name is a parameter. Reusing a log name is NOT safe: a previous run
rem that still holds the handle makes both the delete and the new redirect fail
rem silently, and the reader then sees the previous run's output.
set ATLAS_OUT=atlas_regress.mat
set ATLAS_LEAD_AXIS=288
set ATLAS_WINDOW=120d
set MODEL_EXCLUDE=ma,ma_comp,med,T_ewma,T28_level,MW_level
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=atlas_regress
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_full_ensemble_test" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
