@echo off
rem The correction the supervisor asked for, measured on the same 32 scored days.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=correction
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); error_correction_official" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
