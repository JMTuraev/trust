@echo off
setlocal enabledelayedexpansion
REM Trust QA — telefon ekranidan surat olib D:\trust\qa-shots ga saqlaydi.
REM Har Enter bosilganda BITTA surat oladi. Telefonda kerakli ekranni oching, keyin Enter.

set OUT=D:\trust\qa-shots
if not exist "%OUT%" mkdir "%OUT%"

where adb >nul 2>&1
if %errorlevel%==0 (set ADB=adb) else (set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe)

echo === adb holati === > "%OUT%\_status.txt"
"%ADB%" devices >> "%OUT%\_status.txt" 2>&1
"%ADB%" shell pm list packages uz.trust.trust_mobile >> "%OUT%\_status.txt" 2>&1
type "%OUT%\_status.txt"
echo.

set /a N=0
:loop
set /p x="Telefonda ekranni oching, keyin ENTER (chiqish uchun q + ENTER): "
if /i "!x!"=="q" goto end
set /a N+=1
"%ADB%" exec-out screencap -p > "%OUT%\shot_!N!.png"
echo   -> shot_!N!.png saqlandi
goto loop

:end
echo DONE. Jami !N! ta surat: %OUT%
endlocal
