@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); run_ar_order_sweep" > "C:\Ash\_research_20261013\ar_sweep.log" 2>&1
exit /b %ERRORLEVEL%
