@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title SP1RZ UTILS

for /F %%a in ('echo prompt $E^|cmd') do set "ESC=%%a"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "WHITE=%ESC%[97m"
set "RESET=%ESC%[0m"

set "LOGFILE=%~dp0sp1rz_install_log.txt"

:: Проверка прав администратора и автозапрос через UAC
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorLevel%' NEQ '0' (
    echo [!] Нужны права администратора. Запрашиваю разрешение...
    goto UACPrompt
) else (
    goto gotAdmin
)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\sp1rz_getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\sp1rz_getadmin.vbs"
    "%temp%\sp1rz_getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\sp1rz_getadmin.vbs" del "%temp%\sp1rz_getadmin.vbs"
    pushd "%CD%"
    cd /d "%~dp0"

:: ============================================================
:: Определение версии Windows (10 или 11)
:: ============================================================
set "OSVER=10"
set "BUILD=0"
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul ^| findstr /i "CurrentBuild"') do set "BUILD=%%a"
if not defined BUILD set "BUILD=0"
if %BUILD% geq 22000 set "OSVER=11"

:: Проверка наличия winget
where winget >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Winget не найден. Установите его из Microsoft Store ^(App Installer^) и запустите скрипт снова.
    pause > nul
    exit /b 1
)

:menu
cls
echo.
echo.
echo        %RED%//////////////////////////////%RESET%
echo        %RED%///%RESET%                        %RED%///%RESET%
echo        %RED%///%RESET%      %WHITE%SP1RZ UTILS%RESET%       %RED%///%RESET%
echo        %RED%///%RESET%                        %RED%///%RESET%
echo        %RED%//////////////////////////////%RESET%
echo.
echo        %WHITE%Обнаружена ОС: Windows %OSVER% (build %BUILD%)%RESET%
echo.
echo        [1] Установка программы (winget)
echo        [2] Активация Windows (KMS)
echo        [3] Установка Microsoft Office
echo        [0] Выход
echo.
set /p choice=Выбери пункт: 

if "%choice%"=="1" goto install
if "%choice%"=="2" goto activate
if "%choice%"=="3" goto util3
if "%choice%"=="0" exit
goto menu

:install
cls
echo        %WHITE%Установка программы через winget%RESET%
echo.
set /p appname=Введите название программы: 
if "%appname%"=="" goto menu
echo.
echo Ищу "%appname%"...
echo.
winget search "%appname%"
echo.
echo Скопируй точный ID нужной программы из колонки Id выше.
set /p appid=Введите ID (или Enter для отмены): 
if "%appid%"=="" goto menu
echo.

set "ALREADY_INSTALLED=0"
winget list --id %appid% -e --accept-source-agreements >nul 2>&1
if !errorLevel! equ 0 set "ALREADY_INSTALLED=1"

if "!ALREADY_INSTALLED!"=="1" (
    echo [=] %appid% уже установлена, пропускаем.
    echo [%date% %time%] %appid% - уже установлена, пропущено >> "%LOGFILE%"
) else (
    echo [*] Установка: %appid% ...
    winget install --id %appid% -e --silent --accept-package-agreements --accept-source-agreements
    if !errorLevel! equ 0 (
        echo [+] %appid% успешно установлена.
        echo [%date% %time%] %appid% - OK >> "%LOGFILE%"
    ) else (
        echo [-] Ошибка при установке %appid% ^(код: !errorLevel!^)
        echo [%date% %time%] %appid% - ОШИБКА, код !errorLevel! >> "%LOGFILE%"
    )
)
echo.
echo Лог сохранён в: %LOGFILE%
echo.
pause
goto menu

:: ============================================================
:: АКТИВАЦИЯ WINDOWS
:: ============================================================
:activate
cls

:: --- Проверка: не активирована ли уже система ---
set "LICSTAT="
powershell -NoProfile -Command "(Get-CimInstance SoftwareLicensingProduct -Filter 'PartialProductKey IS NOT NULL' | Where-Object {$_.Name -like 'Windows*'} | Select-Object -First 1 -ExpandProperty LicenseStatus)" > "%temp%\sp1rz_lic.txt" 2>nul
set /p LICSTAT=<"%temp%\sp1rz_lic.txt"
del "%temp%\sp1rz_lic.txt" 2>nul

if "%LICSTAT%"=="1" (
    echo.
    echo        %GREEN%=========================================%RESET%
    echo        %GREEN%   Windows уже активирован!            %RESET%
    echo        %GREEN%=========================================%RESET%
    echo.
    echo        %WHITE%Повторная активация не требуется.%RESET%
    echo        %WHITE%Для проверки вручную: slmgr /xpr%RESET%
    echo.
    pause
    goto menu
)

echo        %WHITE%Активация Windows через KMS%RESET%
echo.
echo        Выберите версию Windows:
echo.
echo        [1] Windows 11  (KMS: kms.msguides.com)
echo        [2] Windows 10  (KMS: kms.digiboy.ir)
echo        [0] Назад
echo.
set /p wver=Выбери пункт: 

if "%wver%"=="1" goto act_win11
if "%wver%"=="2" goto act_win10
if "%wver%"=="0" goto menu
goto activate

:: ============================================================
:: WINDOWS 11 — ключи + сервер kms.msguides.com
:: ============================================================
:act_win11
if not "%OSVER%"=="11" (
    cls
    echo.
    echo        %RED%####################################################%RESET%
    echo        %RED%#                                                  #%RESET%
    echo        %RED%#  Этот пункт для Windows 11.                      #%RESET%
    echo        %RED%#  У вас обнаружена Windows %OSVER%.                      #%RESET%
    echo        %RED%#                                                  #%RESET%
    echo        %RED%####################################################%RESET%
    echo.
    echo        %WHITE%Пожалуйста, выберите свою версию Windows в меню.%RESET%
    echo.
    pause
    goto activate
)
cls
set "WKEY="
set "WNAME="
set "WINVER=Windows 11"
set "KSERVER=kms.msguides.com"
set "KSERVER2=kms8.msguides.com"
echo        %WHITE%Активация: Windows 11%RESET%
echo.
echo        Выберите редакцию:
echo.
echo        [1] Home
echo        [2] Home N
echo        [3] Pro
echo        [4] Pro N
echo        [5] Education
echo        [6] Education N
echo        [0] Назад
echo.
set /p wchoice=Выбери пункт: 

if "%wchoice%"=="1" (
    set "WKEY=TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"
    set "WNAME=Windows 11 Home"
)
if "%wchoice%"=="2" (
    set "WKEY=3KHY7-WNT83-DGQKR-F7HPR-844BM"
    set "WNAME=Windows 11 Home N"
)
if "%wchoice%"=="3" (
    set "WKEY=W269N-WFGWX-YVC9B-4J6C9-T83GX"
    set "WNAME=Windows 11 Pro"
)
if "%wchoice%"=="4" (
    set "WKEY=MH37W-N47XK-V7XM9-C7227-GCQG9"
    set "WNAME=Windows 11 Pro N"
)
if "%wchoice%"=="5" (
    set "WKEY=NW6C2-QMPVW-D7KKK-3GKT6-VCFB2"
    set "WNAME=Windows 11 Education"
)
if "%wchoice%"=="6" (
    set "WKEY=2WH4N-8QGBV-H22JP-CT43Q-MDWWJ"
    set "WNAME=Windows 11 Education N"
)
if "%wchoice%"=="0" goto activate

if not defined WKEY goto act_win11
goto do_activate

:: ============================================================
:: WINDOWS 10 — ключи + сервер kms.digiboy.ir
:: ============================================================
:act_win10
if not "%OSVER%"=="10" (
    cls
    echo.
    echo        %RED%####################################################%RESET%
    echo        %RED%#                                                  #%RESET%
    echo        %RED%#  Этот пункт для Windows 10.                      #%RESET%
    echo        %RED%#  У вас обнаружена Windows %OSVER%.                      #%RESET%
    echo        %RED%#                                                  #%RESET%
    echo        %RED%####################################################%RESET%
    echo.
    echo        %WHITE%Пожалуйста, выберите свою версию Windows в меню.%RESET%
    echo.
    pause
    goto activate
)
cls
set "WKEY="
set "WNAME="
set "WINVER=Windows 10"
set "KSERVER=kms.digiboy.ir"
set "KSERVER2=kms8.msguides.com"
echo        %WHITE%Активация: Windows 10%RESET%
echo.
echo        Выберите редакцию:
echo.
echo        [1] Home
echo        [2] Home Single Language
echo        [3] Pro
echo        [4] Enterprise
echo        [5] Education
echo        [0] Назад
echo.
set /p wchoice=Выбери пункт: 

if "%wchoice%"=="1" (
    set "WKEY=KTNPV-KTRK4-3RRR8-39X6W-W44T3"
    set "WNAME=Windows 10 Home"
)
if "%wchoice%"=="2" (
    set "WKEY=7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH"
    set "WNAME=Windows 10 Home Single Language"
)
if "%wchoice%"=="3" (
    set "WKEY=W269N-WFGWX-YVC9B-4J6C9-T83GX"
    set "WNAME=Windows 10 Pro"
)
if "%wchoice%"=="4" (
    set "WKEY=NPPR9-FWDCX-D2C8J-H872K-2YT43"
    set "WNAME=Windows 10 Enterprise"
)
if "%wchoice%"=="5" (
    set "WKEY=NW6C2-QMPVW-D7KKK-3GKT6-VCFB2"
    set "WNAME=Windows 10 Education"
)
if "%wchoice%"=="0" goto activate

if not defined WKEY goto act_win10
goto do_activate

:: ============================================================
:: ОБЩИЙ БЛОК АКТИВАЦИИ
:: ============================================================
:do_activate
cls
echo        %WHITE%Активация: %WNAME%%RESET%
echo        %WHITE%KMS-сервер: %KSERVER%%RESET%
echo.

echo [*] Шаг 1/3 — Установка ключа...
cscript //nologo %windir%\system32\slmgr.vbs /ipk %WKEY%
if !errorLevel! neq 0 (
    echo [-] Не удалось установить ключ ^(код: !errorLevel!^)
    echo [%date% %time%] Активация %WNAME% - ошибка установки ключа !errorLevel! >> "%LOGFILE%"
    echo.
    pause
    goto menu
)
echo [+] Ключ установлен.
echo.

echo [*] Шаг 2/3 — Установка KMS-сервера...
cscript //nologo %windir%\system32\slmgr.vbs /skms %KSERVER% >"%temp%\sp1rz_kms.txt" 2>&1
type "%temp%\sp1rz_kms.txt"
findstr /i /c:"error" /c:"ошибка" /c:"не удалось" "%temp%\sp1rz_kms.txt" >nul
if !errorLevel! neq 0 (
    echo [+] KMS-сервер: %KSERVER%
) else (
    echo [!] %KSERVER% не сработал, пробую %KSERVER2% ...
    cscript //nologo %windir%\system32\slmgr.vbs /skms %KSERVER2%
    echo [+] KMS-сервер: %KSERVER2%
)
if exist "%temp%\sp1rz_kms.txt" del "%temp%\sp1rz_kms.txt" 2>nul
echo.

echo [*] Шаг 3/3 — Активация...
cscript //nologo %windir%\system32\slmgr.vbs /ato
if !errorLevel! equ 0 (
    echo.
    echo [+] Команда активации выполнена.
    echo [%date% %time%] Активация %WNAME% ^(%WKEY%^) через %KSERVER% - команда /ato выполнена >> "%LOGFILE%"
) else (
    echo.
    echo [-] Ошибка активации ^(код: !errorLevel!^)
    echo [%date% %time%] Активация %WNAME% ^(%WKEY%^) - ошибка /ato код !errorLevel! >> "%LOGFILE%"
)
echo.
echo Для проверки статуса: slmgr /xpr
echo Лог: %LOGFILE%
echo.
pause
set "WKEY="
set "WNAME="
set "WINVER="
set "KSERVER="
set "KSERVER2="
goto menu

:: ============================================================
:: УСТАНОВКА MICROSOFT OFFICE (через C2R bootstrapper + ODT)
:: ============================================================
:util3
cls
echo        %WHITE%Установка Microsoft Office%RESET%
echo.
echo        Выберите вариант:
echo.
echo        [1] Microsoft 365 Apps for enterprise
echo        [2] Office LTSC Professional Plus 2021
echo        [3] Office Professional Plus 2019
echo        [0] Назад
echo.
set /p officechoice=Выбери пункт: 

set "OFFPROD="
set "OFFNAME="
set "OFFCHANNEL="
if "%officechoice%"=="1" (
    set "OFFPROD=O365ProPlusRetail"
    set "OFFNAME=Microsoft 365 Apps for enterprise"
    set "OFFCHANNEL=Current"
)
if "%officechoice%"=="2" (
    set "OFFPROD=ProPlus2021Volume"
    set "OFFNAME=Office LTSC Professional Plus 2021"
    set "OFFCHANNEL=PerpetualVL2021"
)
if "%officechoice%"=="3" (
    set "OFFPROD=ProPlus2019Volume"
    set "OFFNAME=Office Professional Plus 2019"
    set "OFFCHANNEL=PerpetualVL2019"
)
if "%officechoice%"=="0" goto menu
if not defined OFFPROD goto util3

echo.
echo [*] Установка: %OFFNAME%
echo     Это может занять 10-30 минут, дождитесь завершения.
echo.

:: --- Проверка: не установлен ли уже Office ---
reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds >nul 2>&1
if !errorLevel! equ 0 (
    echo [=] Office уже установлен в системе, пропускаем.
    echo [%date% %time%] %OFFNAME% - уже установлен, пропущено >> "%LOGFILE%"
    echo.
    pause
    goto menu
)

:: --- Рабочая папка ---
set "ODTDIR=%TEMP%\sp1rz_odt"
if exist "%ODTDIR%" rmdir /s /q "%ODTDIR%"
mkdir "%ODTDIR%"

:: --- Скачивание C2R bootstrapper ---
echo [*] Скачиваю установщик Office ^(setup.exe^)...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile '%ODTDIR%\setup.exe' -UseBasicParsing } catch { exit 1 }"

if not exist "%ODTDIR%\setup.exe" (
    echo [-] Не удалось скачать установщик.
    echo [%date% %time%] %OFFNAME% - ошибка скачивания >> "%LOGFILE%"
    rmdir /s /q "%ODTDIR%" 2>nul
    echo.
    pause
    goto menu
)

:: --- Проверка размера ---
for %%F in ("%ODTDIR%\setup.exe") do set "ODTSIZE=%%~zF"
if !ODTSIZE! LSS 3000000 (
    echo [-] Файл слишком мал ^(!ODTSIZE! байт^), вероятно ошибка.
    echo [%date% %time%] %OFFNAME% - setup.exe повреждён ^(!ODTSIZE!^) >> "%LOGFILE%"
    rmdir /s /q "%ODTDIR%" 2>nul
    echo.
    pause
    goto menu
)

:: --- Проверка MZ-заголовка (это .exe, а не HTML) ---
powershell -NoProfile -Command "$f=[IO.File]::ReadAllBytes('%ODTDIR%\setup.exe'); if ($f[0] -ne 77 -or $f[1] -ne 90) { exit 1 }"
if !errorLevel! neq 0 (
    echo [-] Скачался не EXE-файл ^(HTML/редирект^). Прерываю.
    rmdir /s /q "%ODTDIR%" 2>nul
    echo.
    pause
    goto menu
)

:: --- Снимаем MOTW (Mark of the Web) ---
powershell -NoProfile -Command "Unblock-File -Path '%ODTDIR%\setup.exe' -ErrorAction SilentlyContinue" >nul 2>&1

echo [+] Установщик готов ^(!ODTSIZE! байт^).
echo.

:: --- Создание configuration.xml ---
echo [*] Готовлю конфигурацию ^(канал: %OFFCHANNEL%^)...
(
echo ^<Configuration^>
echo   ^<Add OfficeClientEdition="64" Channel="%OFFCHANNEL%"^>
echo     ^<Product ID="%OFFPROD%"^>
echo       ^<Language ID="ru-ru" /^>
echo       ^<Language ID="en-us" /^>
echo     ^</Product^>
echo   ^</Add^>
echo   ^<Property Name="AUTOACTIVATE" Value="0" /^>
echo   ^<Property Name="FORCEAPPSHUTDOWN" Value="TRUE" /^>
echo   ^<Display Level="Full" AcceptEULA="TRUE" /^>
echo   ^<Logging Level="Standard" Path="%ODTDIR%\log" /^>
echo ^</Configuration^>
) > "%ODTDIR%\configuration.xml"

:: --- Запуск установки ---
echo [*] Запускаю установщик Office...
echo.
"%ODTDIR%\setup.exe" /configure "%ODTDIR%\configuration.xml"

if !errorLevel! equ 0 (
    echo.
    echo [+] %OFFNAME% успешно установлен.
    echo [%date% %time%] %OFFNAME% - OK >> "%LOGFILE%"
) else (
    echo.
    echo [-] Установка завершилась с кодом !errorLevel!
    echo     Подробный лог: %ODTDIR%\log
    echo [%date% %time%] %OFFNAME% - ошибка, код !errorLevel! >> "%LOGFILE%"
)

echo.
echo Лог скрипта: %LOGFILE%
echo.
pause
set "OFFPROD="
set "OFFNAME="
set "OFFCHANNEL="
set "ODTDIR="
set "ODTSIZE="
goto menu