@echo off
rem Read-only reconnaissance for the two questions the supervisor raised.
rem The log name is a parameter: reusing one is not safe, see run_atlas_60d.bat.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=probe_mentor
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); probe_mentor" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
