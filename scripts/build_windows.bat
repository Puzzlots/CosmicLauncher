@echo off
cd %USERPROFILE%\Documents\GitHub\Puzzlots\CosmicLauncher

REM --- Extract version from pubspec.yaml (format: version: 1.2.3+4) ---
for /f "tokens=2 delims= " %%v in ('findstr /b "version:" pubspec.yaml') do set PUBVERSION=%%v

REM --- Strip the build number after the + if present ---
for /f "tokens=1 delims=+" %%a in ("%PUBVERSION%") do set APPVERSION=%%a

echo Building version %APPVERSION%...

call flutter build windows
if errorlevel 1 (
    echo Flutter build failed!
    pause
    exit /b 1
)

call iscc.exe /DMyAppVersion=%APPVERSION% scripts\installer_script.iss
if errorlevel 1 (
    echo Inno Setup build failed!
    pause
    exit /b 1
)

echo Zipping portable build...
set OUTPUT_ZIP=build\bin\polaris_launcher_windows_portable-%APPVERSION%.zip
if exist %OUTPUT_ZIP% del %OUTPUT_ZIP%
powershell -Command "Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath '%OUTPUT_ZIP%'"

echo Done! Version %APPVERSION% built successfully.