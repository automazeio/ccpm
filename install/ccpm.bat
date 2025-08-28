@echo off

set REPO_URL=https://github.com/automazeio/ccpm.git
set TARGET_DIR=.

echo Cloning repository from %REPO_URL%...
git clone %REPO_URL% %TARGET_DIR%

if %ERRORLEVEL% EQU 0 (
    echo Clone successful. Removing .git directory...
    rmdir /s /q .git 2>nul
    rmdir /s /q install 2>nul
    del /q .gitignore 2>nul
    echo Git directory removed. Repository is now untracked.
) else (
    echo Error: Failed to clone repository.
    exit /b 1
)
