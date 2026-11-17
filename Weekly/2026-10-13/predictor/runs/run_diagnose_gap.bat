@echo off
rem Where the official composite beats the bench, and why. Reads atlas_60d.mat and
rem official_60d.mat read-only and writes deck\diagnose_official_gap.json.
rem The log name is a parameter: reusing one is not safe, see run_atlas_60d.bat.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=diagnose_gap
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); diagnose_official_gap" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
