@echo off
rem Read-only: does a product overlap agree, and does a correction on the official
rem forecast help. The log name is a parameter: reusing one is not safe.
set LOGSUF=%1
if "%LOGSUF%"=="" set LOGSUF=check_agreement
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\scripts'); check_product_agreement" > "C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Weekly\2026-10-13\predictor\runs\%LOGSUF%.log" 2>&1
exit /b %ERRORLEVEL%
