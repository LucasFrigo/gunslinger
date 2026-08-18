@echo off
setlocal
cd /d "%~dp0.."

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "APK=%CD%\builds\vr\gunslinger-quest.apk"

if not exist "%ADB%" (
  echo adb not found: %ADB%
  exit /b 1
)
if not exist "%APK%" (
  echo APK not found: %APK%
  exit /b 1
)

echo Devices:
"%ADB%" devices
echo Installing %APK%
"%ADB%" install -r "%APK%"
exit /b %ERRORLEVEL%
