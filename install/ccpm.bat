@echo off
setlocal enabledelayedexpansion

set REPO_URL=https://github.com/automazeio/ccpm.git

:: Generate unique temp directory name using timestamp
for /f "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set TEMP_DIR=ccpm-temp-%ldt:~0,14%

echo Cloning repository from %REPO_URL% to temporary directory...
git clone %REPO_URL% %TEMP_DIR%

if %ERRORLEVEL% EQU 0 (
    echo Clone successful. Copying CCPM files to current directory...
    
    :: Copy .claude directory if it exists
    if exist "%TEMP_DIR%\.claude" (
        xcopy "%TEMP_DIR%\.claude" ".claude" /E /I /Q >nul
        echo Copied .claude\ directory
    )
    
    :: Copy other relevant files if they exist
    if exist "%TEMP_DIR%\AGENTS.md" (
        copy "%TEMP_DIR%\AGENTS.md" . >nul
        echo Copied AGENTS.md
    )
    if exist "%TEMP_DIR%\COMMANDS.md" (
        copy "%TEMP_DIR%\COMMANDS.md" . >nul
        echo Copied COMMANDS.md
    )
    
    :: Clean up temporary directory
    echo Cleaning up temporary directory...
    rmdir /s /q "%TEMP_DIR%" 2>nul
    
    echo CCPM installation complete! Run '/pm:init' to get started.
) else (
    echo Error: Failed to clone repository.
    :: Clean up on failure too
    if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)
