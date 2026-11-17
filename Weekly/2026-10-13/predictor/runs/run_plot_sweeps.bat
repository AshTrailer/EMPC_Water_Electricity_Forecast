@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); plot_sweeps" > "C:\Ash\_research_20261013\plot_sweeps.log" 2>&1
exit /b %ERRORLEVEL%
