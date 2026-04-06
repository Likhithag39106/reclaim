@echo off
REM AI Recovery Service Startup Script for Windows
REM Starts the FastAPI AI service on Python 3.10

echo ===============================================
echo AI Recovery Plan Service - Startup
echo ===============================================
echo.

REM Check if virtual environment exists
if not exist "venv\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found!
    echo Please run setup first:
    echo   C:\Python310\python.exe -m venv venv
    echo   venv\Scripts\activate
    echo   pip install -r requirements.txt
    pause
    exit /b 1
)

REM Activate virtual environment
echo [1/3] Activating virtual environment...
call venv\Scripts\activate.bat

REM Check if dependencies are installed
echo [2/3] Checking dependencies...
python -c "import fastapi, tensorflow, uvicorn" 2>nul
if errorlevel 1 (
    echo ERROR: Dependencies not installed!
    echo Please run: pip install -r requirements.txt
    pause
    exit /b 1
)

echo [3/3] Starting AI service on http://localhost:8000
echo.
echo Press Ctrl+C to stop the service
echo ===============================================
echo.

REM Start the service
python app.py

REM If service exits
echo.
echo Service stopped.
pause
