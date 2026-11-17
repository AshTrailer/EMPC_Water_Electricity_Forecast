@echo off
rem The real figure set from the rebuilt atlas, into the project folder.
set ATLAS_IN=atlas_v4.mat
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "cd('C:\Ash\Projects\EMPC_Water_Electricity_Forecast\Predicitor'); report_surfaces" > "C:\Ash\_research_20261013\report_surfaces_v7.log" 2>&1
exit /b %ERRORLEVEL%
