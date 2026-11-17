@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); report_by_lead_and_slot" > "C:\Ash\_research_20261013\report_profiles.log" 2>&1
exit /b %ERRORLEVEL%
