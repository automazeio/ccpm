@echo off

set REPO_URL=https://github.com/automazeio/ccpm.git
set TEMP_DIR=%TEMP%\ccpm-install-%RANDOM%
set TARGET_DIR=.

echo Cloning CCPM repository...
git clone %REPO_URL% %TEMP_DIR%

if %ERRORLEVEL% EQU 0 (
    echo Clone successful. Installing CCPM system...
    
    rem Check if .claude directory already exists
    if exist .claude (
        echo WARNING: .claude directory already exists!
        echo    Please backup your existing .claude directory before continuing.
        echo    Then remove it and re-run this installer.
        rmdir /s /q %TEMP_DIR% 2>nul
        exit /b 1
    )
    
    rem Copy ccpm contents to .claude
    if exist %TEMP_DIR%\ccpm (
        xcopy /E /I %TEMP_DIR%\ccpm .claude
        echo CCPM system installed to .claude/
    ) else (
        echo Error: ccpm directory not found in repository.
        rmdir /s /q %TEMP_DIR% 2>nul
        exit /b 1
    )
    
    rem Clean up temporary directory
    rmdir /s /q %TEMP_DIR% 2>nul
    
    echo CCPM installation complete!
    echo    Run: /pm:init to set up your project
    
) else (
    echo Error: Failed to clone repository.
    rmdir /s /q %TEMP_DIR% 2>nul
    exit /b 1
)