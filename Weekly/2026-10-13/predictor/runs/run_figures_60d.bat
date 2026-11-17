@echo off
rem Figures for the 60-day, 376-column atlas, with the official composite beside
rem it. Output goes to its own folder so the earlier 288-column figure set is not
rem overwritten and neither set can be mistaken for the other.
rem
rem The log name is a parameter; reusing a log name is not safe.
set ATLAS_IN=atlas_60d.mat
set OFFICIAL_IN=official_60d.mat
set FIG_DIR=C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\figures_60d
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=figures_60d
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); report_surfaces" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
