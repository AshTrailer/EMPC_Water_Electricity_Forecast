@echo off
rem Read-only extraction of every number the deck quotes, from atlas_60d.mat and
rem official_60d.mat. matfile handles mean the 397 MB error cube is never loaded.
rem The log name is a parameter: reusing one is not safe, see run_atlas_60d.bat.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=extract_numbers
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); extract_deck_numbers" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
