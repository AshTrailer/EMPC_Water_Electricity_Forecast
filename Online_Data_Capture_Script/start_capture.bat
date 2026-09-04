@echo off
rem ============================== start_capture.bat ==============================
rem Start the AEMO data capture loop from this folder.
cd /d "%~dp0"
python aemo_capture.py %*
echo.
pause