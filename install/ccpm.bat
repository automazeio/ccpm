@echo off
setlocal enabledelayedexpansion

set REPO_URL=https://github.com/automazeio/ccpm.git
set TARGET_DIR=%CD%
set TEMP_DIR=%TEMP%\ccpm-%RANDOM%

echo Installing Claude Code PM...
echo Cloning repository to temporary directory...

git clone --depth 1 %REPO_URL% "%TEMP_DIR%"
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to clone repository.
    exit /b 1
)

REM The repo has ccpm/ folder that should become .claude/
set SOURCE_DIR=%TEMP_DIR%\ccpm

if exist "%TARGET_DIR%\.claude" (
    echo Existing .claude directory detected.
    echo Merging ccpm files into existing .claude directory...

    REM Copy directories using xcopy
    for %%d in (agents commands context prds rules scripts hooks) do (
        if exist "%SOURCE_DIR%\%%d" (
            if not exist "%TARGET_DIR%\.claude\%%d" mkdir "%TARGET_DIR%\.claude\%%d"
            xcopy /E /I /D "%SOURCE_DIR%\%%d" "%TARGET_DIR%\.claude\%%d" >nul 2>&1
        )
    )

    REM Copy config files if they don't exist
    for %%f in (ccpm.config settings.json.example settings.local.json) do (
        if exist "%SOURCE_DIR%\%%f" (
            if not exist "%TARGET_DIR%\.claude\%%f" (
                copy "%SOURCE_DIR%\%%f" "%TARGET_DIR%\.claude\%%f" >nul
            )
        )
    )

    echo Merge complete. Your existing customizations are preserved.
) else (
    echo Creating new .claude directory...
    xcopy /E /I "%SOURCE_DIR%" "%TARGET_DIR%\.claude" >nul
)

REM Create epics directory if it doesn't exist
if not exist "%TARGET_DIR%\.claude\epics" mkdir "%TARGET_DIR%\.claude\epics"

REM Cleanup temp directory
rmdir /s /q "%TEMP_DIR%" 2>nul

echo.
echo Claude Code PM installed successfully!
echo.
echo Next steps:
echo   1. Run '/pm:init' in Claude Code to complete setup
echo   2. Copy relevant instructions from README.md to your CLAUDE.md
echo.

endlocal
