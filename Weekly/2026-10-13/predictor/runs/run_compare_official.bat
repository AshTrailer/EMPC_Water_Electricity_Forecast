@echo off
rem The official composite and its correction on the object the model table uses.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=compare_official
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); compare_official_on_deck_object" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
