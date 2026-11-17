@echo off
rem Official AEMO composite on the 376-column atlas grid, 60-day window.
rem Stages P5MIN to its own 55-minute horizon, then PREDISPATCH, then PD7DAY.
rem
rem The log name is an argument and defaults to a fresh name each run. Reusing a
rem log name is NOT safe: if a previous run still holds the file handle, both the
rem delete and the new redirect fail silently and the reader ends up looking at
rem the previous run's output.
set OFFICIAL_OUT=official_60d.mat
set OFFICIAL_CSV_DAY=2026-09-01
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=official_atlas
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); build_official_atlas" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
