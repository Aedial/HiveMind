@echo off
:: Setup script for HiveMind pre-commit hooks (Windows)

echo 🔧 Setting up HiveMind pre-commit hooks...

:: Check if pre-commit is installed
pre-commit --version >nul 2>&1
if errorlevel 1 (
    echo 📦 Installing pre-commit...
    
    :: Try pip installation
    pip --version >nul 2>&1
    if not errorlevel 1 (
        pip install pre-commit
    ) else (
        pip3 --version >nul 2>&1
        if not errorlevel 1 (
            pip3 install pre-commit
        ) else (
            echo ❌ Could not install pre-commit automatically
            echo Please install pre-commit manually:
            echo   pip install pre-commit
            echo   or visit: https://pre-commit.com/#installation
            exit /b 1
        )
    )
)

:: Check if lua is available
lua -v >nul 2>&1
if errorlevel 1 (
    echo ❌ Lua is not installed or not in PATH
    echo Please install Lua 5.3 or later:
    echo   Download from https://www.lua.org
    echo   Or use package manager like Chocolatey: choco install lua
    exit /b 1
)

:: Install the pre-commit hooks
echo ⚙️  Installing pre-commit hooks...
pre-commit install

:: Create artifacts directory
if not exist "Artifacts" mkdir "Artifacts"

echo ✅ Pre-commit setup complete!
echo.
echo 📋 Available commands:
echo   pre-commit run --all-files                           # Run all hooks on all files
echo   pre-commit run                                        # Run hooks on staged files  
echo   pre-commit run --hook-stage manual --all-files       # Run performance tests
echo.
echo 🎯 Pre-commit will now automatically run tests before each commit!
echo    To skip pre-commit: git commit --no-verify