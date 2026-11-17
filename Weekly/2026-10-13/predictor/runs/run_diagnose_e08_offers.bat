@echo off
rem Run the E08 offer stack diagnostic. The log name is the only argument.
setlocal
set ROOT=C:\Ash\Projects\EMPC_Water_Electricity_Forecast
set WD=%ROOT%\Weekly\2026-10-13
set LOG=%WD%\predictor\runs\%~1
if "%1"=="" set LOG=%WD%\predictor\runs\e08_offers.log
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('%WD%\predictor\scripts'); diagnose_e08_offers" > "%LOG%" 2>&1
echo exit %ERRORLEVEL% >> "%LOG%"
