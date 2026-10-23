@echo off
echo ========================================================
echo       Puff-er: APK Build ^& Export nach Google Drive
echo ========================================================
echo.

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [FEHLER] Flutter SDK wurde nicht im PATH gefunden!
    echo Bitte stelle sicher, dass Flutter installiert und im Systempfad hinterlegt ist.
    echo.
    pause
    exit /b 1
)

echo [1/3] Lade Abhaengigkeiten (flutter pub get)...
call flutter pub get
if %errorlevel% neq 0 (
    echo [FEHLER] Fehler bei flutter pub get!
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Kompiliere Release-APK (flutter build apk --release)...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo [FEHLER] Fehler beim Kompilieren der APK!
    pause
    exit /b %errorlevel%
)

echo.
echo [3/3] Kopiere fertige APK nach G:\Meine Ablage\apk\Puff-er...
if not exist "G:\Meine Ablage\apk\Puff-er" mkdir "G:\Meine Ablage\apk\Puff-er"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "G:\Meine Ablage\apk\Puff-er\Puff-er.apk"

if %errorlevel% equ 0 (
    echo.
    echo [ERFOLG] Die APK wurde erfolgreich gespeichert in:
    echo "G:\Meine Ablage\apk\Puff-er\Puff-er.apk"
) else (
    echo [FEHLER] Fehler beim Kopieren nach G:\Meine Ablage\apk\Puff-er!
)

echo.
pause
