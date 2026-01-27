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

if exist "%TARGET_DIR%\.claude" (
    echo Existing .claude directory detected.
    echo Merging ccpm files into existing .claude directory...

    REM Backup existing CLAUDE.md if it exists
    if exist "%TARGET_DIR%\.claude\CLAUDE.md" (
        echo Backing up existing CLAUDE.md to CLAUDE.md.backup
        copy /Y "%TARGET_DIR%\.claude\CLAUDE.md" "%TARGET_DIR%\.claude\CLAUDE.md.backup" >nul
    )

    REM Copy directories using xcopy (won't overwrite existing files)
    for %%d in (agents commands context prds rules) do (
        if exist "%TEMP_DIR%\.claude\%%d" (
            if not exist "%TARGET_DIR%\.claude\%%d" mkdir "%TARGET_DIR%\.claude\%%d"
            xcopy /E /Y /I "%TEMP_DIR%\.claude\%%d" "%TARGET_DIR%\.claude\%%d" >nul 2>&1
        )
    )

    REM Copy CLAUDE.md
    copy /Y "%TEMP_DIR%\.claude\CLAUDE.md" "%TARGET_DIR%\.claude\CLAUDE.md" >nul

    echo Merge complete. Your existing customizations are preserved.
) else (
    echo Creating new .claude directory...
    xcopy /E /I "%TEMP_DIR%\.claude" "%TARGET_DIR%\.claude" >nul
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
echo   2. Check .claude/CLAUDE.md for configuration options
echo.

endlocal
