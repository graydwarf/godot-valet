@echo off
setlocal enabledelayedexpansion

set GODOT=C:\dad\apps\godot\godot-4.5-stable\Godot_v4.5-stable_win64.exe
set PROJECT_PATH=C:\dad\projects\godot\godot-4\applications\godot-valet
set TEST_USER_DIR=C:\dad\projects\godot\godot-4\applications\godot-valet\test-user-data

echo === Godot Valet Test Runner ===
echo.

:: Check for --stay flag to keep app open after tests
set EXIT_FLAG=--exit-on-complete
if "%1"=="--stay" (
    set EXIT_FLAG=
    echo Mode: Stay open after tests ^(review results in Test Manager^)
) else (
    echo Mode: Exit after tests ^(use --stay to keep app open^)
)
echo.

:: Reset test environment
echo Resetting test environment...
if exist "%TEST_USER_DIR%\project-items" rmdir /s /q "%TEST_USER_DIR%\project-items"
if exist "%TEST_USER_DIR%\godot-version-items" rmdir /s /q "%TEST_USER_DIR%\godot-version-items"

:: Create directories
mkdir "%TEST_USER_DIR%\project-items" 2>nul
mkdir "%TEST_USER_DIR%\godot-version-items" 2>nul

:: Copy fixtures
echo Copying test fixtures...
xcopy /s /e /i /q "%PROJECT_PATH%\test-fixtures\*" "%TEST_USER_DIR%\" >nul 2>&1

:: Run tests
echo.
echo Starting Godot with test mode...
echo Command: "%GODOT%" --path "%PROJECT_PATH%" --user-dir "%TEST_USER_DIR%" -- --test-all %EXIT_FLAG%
echo ================================
"%GODOT%" --path "%PROJECT_PATH%" --user-dir "%TEST_USER_DIR%" -- --test-all %EXIT_FLAG%
set TEST_RESULT=%ERRORLEVEL%
echo ================================

:: Report result
echo.
if %TEST_RESULT% EQU 0 (
    echo === TESTS PASSED ===
) else (
    echo === TESTS FAILED ===
)

exit /b %TEST_RESULT%
