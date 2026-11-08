@echo off
setlocal enabledelayedexpansion

echo ====================================================================
echo  VeriBite Android Signing Keystore Fingerprint Diagnostic Tool
echo ====================================================================

set KEYSTORE_PATH=%~dp0..\mobile_app\android\app\veribite-debug.keystore
set KEYTOOL_CMD=

:: 1. Check if keytool is in PATH
where keytool >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set KEYTOOL_CMD=keytool
    goto :RUN_KEYTOOL
)

:: 2. Check Android Studio JBR
if exist "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" (
    set "KEYTOOL_CMD=C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    goto :RUN_KEYTOOL
)

:: 3. Check JAVA_HOME
if defined JAVA_HOME (
    if exist "%JAVA_HOME%\bin\keytool.exe" (
        set "KEYTOOL_CMD=%JAVA_HOME%\bin\keytool.exe"
        goto :RUN_KEYTOOL
    )
)

echo [ERROR] keytool was not found in PATH, Android Studio JBR, or JAVA_HOME.
echo Please install JDK 17+ or Android Studio.
exit /b 1

:RUN_KEYTOOL
if not exist "%KEYSTORE_PATH%" (
    echo [ERROR] Keystore file not found at: %KEYSTORE_PATH%
    exit /b 1
)

echo Keystore Location: %KEYSTORE_PATH%
echo Key Alias:         androiddebugkey
echo Store Password:    android
echo Package Name:      com.example.mobile_app
echo.
echo --------------------------------------------------------------------
echo Certificate Fingerprints:
echo --------------------------------------------------------------------
"%KEYTOOL_CMD%" -list -v -keystore "%KEYSTORE_PATH%" -alias androiddebugkey -storepass android | findstr /R /C:"SHA1:" /C:"SHA256:"
echo --------------------------------------------------------------------
echo.
echo [DONE] Add the above SHA-1 and SHA-256 to Google Cloud Console
echo under: APIs and Services -- Credentials -- OAuth 2.0 Client IDs (Android).
echo ====================================================================

