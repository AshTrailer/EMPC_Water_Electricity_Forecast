@echo off
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "disp('BATCH OK'); disp(version)" > "C:\Ash\_research_20261013\matlab_batch_probe.log" 2>&1
exit /b %ERRORLEVEL%
