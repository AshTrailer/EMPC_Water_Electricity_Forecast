@echo off
rem The real run: 60-day window on the 376-column lead axis, into atlas_60d.mat.
rem
rem MODEL_EXCLUDE drops the three 1-hour smoothers, which stop being forecasts
rem past their own window, and ar_adapt, whose column is bit-identical to
rem T28_ARn because they are the same predictor under two names. M19 survives as
rem the order solution in ar_sel and ar_sel_hist.
rem
rem The log name is a parameter. Reusing a log name is NOT safe: a previous run
rem that still holds the handle makes both the delete and the new redirect fail
rem silently, and the reader then sees the previous run's output.
set ATLAS_OUT=atlas_60d.mat
set ATLAS_LEAD_AXIS=376
set ATLAS_WINDOW=60d
set MODEL_EXCLUDE=ma,ma_comp,med,ar_adapt
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=atlas_60d
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_full_ensemble_test" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
