@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title SP1RZ UTILS v1.0

for /F %%a in ('echo prompt $E^|cmd') do set "ESC=%%a"
set "RED=%ESC%[91m"
set "WHITE=%ESC%[97m"
set "RESET=%ESC%[0m"

set "LOGFILE=%~dp0sp1rz_install_log.txt"

:: Проверка прав администратора и автозапрос через UAC
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorLevel%' NEQ '0' (
    echo %RED%[!]%WHITE% Нужны права администратора. Запрашиваю разрешение...%RESET%
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
    echo %RED%[!]%WHITE% Winget не найден. Установите его из Microsoft Store ^(App Installer^) и запустите скрипт снова.%RESET%
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
echo        %RED%[1]%WHITE% Установка программы (winget)%RESET%
echo        %RED%[2]%WHITE% Активация Windows (KMS)%RESET%
echo        %RED%[3]%WHITE% Установка Microsoft Office%RESET%
echo        %RED%[0]%WHITE% Выход%RESET%
echo.
echo        %RED%------------------------------%RESET%
echo        %WHITE%Версия программы %RED%1.0%WHITE% by %RED%SP1RZ%RESET%
echo        %RED%------------------------------%RESET%
echo.
set /p choice=%WHITE%Выбери пункт: %RESET%

if "%choice%"=="1" goto install
if "%choice%"=="2" goto activate
if "%choice%"=="3" goto util3
if "%choice%"=="0" exit
goto menu

:install
cls
echo        %RED%=========================================%RESET%
echo        %WHITE%     Установка программы через winget    %RESET%
echo        %RED%=========================================%RESET%
echo.
set /p appname=%WHITE%Введите название программы: %RESET%
if "%appname%"=="" goto menu
echo.
echo %RED%[*]%WHITE% Ищу "%appname%"...%RESET%
echo.
winget search "%appname%"
echo.
echo %RED%[*]%WHITE% Скопируй точный ID нужной программы из колонки Id выше.%RESET%
set /p appid=%WHITE%Введите ID (или Enter для отмены): %RESET%
if "%appid%"=="" goto menu
echo.

set "ALREADY_INSTALLED=0"
winget list --id %appid% -e --accept-source-agreements >nul 2>&1
if !errorLevel! equ 0 set "ALREADY_INSTALLED=1"

if "!ALREADY_INSTALLED!"=="1" (
    echo %RED%[=]%WHITE% %appid% уже установлена, пропускаем.%RESET%
    echo [%date% %time%] %appid% - уже установлена, пропущено >> "%LOGFILE%"
) else (
    echo %RED%[*]%WHITE% Установка: %appid% ...%RESET%
    winget install --id %appid% -e --silent --accept-package-agreements --accept-source-agreements
    if !errorLevel! equ 0 (
        echo %WHITE%[+] %appid% успешно установлена.%RESET%
        echo [%date% %time%] %appid% - OK >> "%LOGFILE%"
    ) else (
        echo %RED%[-] Ошибка при установке %appid% ^(код: !errorLevel!^)%RESET%
        echo [%date% %time%] %appid% - ОШИБКА, код !errorLevel! >> "%LOGFILE%"
    )
)
echo.
echo %WHITE%Лог сохранён в: %RED%%LOGFILE%%RESET%
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
    echo        %RED%=========================================%RESET%
    echo        %WHITE%        Windows уже активирован!         %RESET%
    echo        %RED%=========================================%RESET%
    echo.
    echo        %WHITE%Повторная активация не требуется.%RESET%
    echo        %WHITE%Для проверки вручную: %RED%slmgr /xpr%RESET%
    echo.
    pause
    goto menu
)

echo        %RED%=========================================%RESET%
echo        %WHITE%       Активация Windows через KMS       %RESET%
echo        %RED%=========================================%RESET%
echo.
echo        %WHITE%Выберите версию Windows:%RESET%
echo.
echo        %RED%[1]%WHITE% Windows 11  (KMS: kms.msguides.com)%RESET%
echo        %RED%[2]%WHITE% Windows 10  (KMS: kms.digiboy.ir)%RESET%
echo        %RED%[0]%WHITE% Назад%RESET%
echo.
set /p wver=%WHITE%Выбери пункт: %RESET%

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
    echo        %RED%#%WHITE%  Этот пункт для Windows 11.                      %RED%#%RESET%
    echo        %RED%#%WHITE%  У вас обнаружена Windows %OSVER%.                      %RED%#%RESET%
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
echo        %RED%=========================================%RESET%
echo        %WHITE%         Активация: Windows 11           %RESET%
echo        %RED%=========================================%RESET%
echo.
echo        %WHITE%Выберите редакцию:%RESET%
echo.
echo        %RED%[1]%WHITE% Home%RESET%
echo        %RED%[2]%WHITE% Home N%RESET%
echo        %RED%[3]%WHITE% Pro%RESET%
echo        %RED%[4]%WHITE% Pro N%RESET%
echo        %RED%[5]%WHITE% Education%RESET%
echo        %RED%[6]%WHITE% Education N%RESET%
echo        %RED%[0]%WHITE% Назад%RESET%
echo.
set /p wchoice=%WHITE%Выбери пункт: %RESET%

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
    echo        %RED%#%WHITE%  Этот пункт для Windows 10.                      %RED%#%RESET%
    echo        %RED%#%WHITE%  У вас обнаружена Windows %OSVER%.                      %RED%#%RESET%
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
echo        %RED%=========================================%RESET%
echo        %WHITE%         Активация: Windows 10           %RESET%
echo        %RED%=========================================%RESET%
echo.
echo        %WHITE%Выберите редакцию:%RESET%
echo.
echo        %RED%[1]%WHITE% Home%RESET%
echo        %RED%[2]%WHITE% Home Single Language%RESET%
echo        %RED%[3]%WHITE% Pro%RESET%
echo        %RED%[4]%WHITE% Enterprise%RESET%
echo        %RED%[5]%WHITE% Education%RESET%
echo        %RED%[0]%WHITE% Назад%RESET%
echo.
set /p wchoice=%WHITE%Выбери пункт: %RESET%

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
echo        %WHITE%Активация: %RED%%WNAME%%RESET%
echo        %WHITE%KMS-сервер: %RED%%KSERVER%%RESET%
echo.

echo %RED%[*]%WHITE% Шаг 1/3 — Установка ключа...%RESET%
cscript //nologo %windir%\system32\slmgr.vbs /ipk %WKEY%
if !errorLevel! neq 0 (
    echo %RED%[-] Не удалось установить ключ (код: !errorLevel!)%RESET%
    echo [%date% %time%] Активация %WNAME% - ошибка установки ключа !errorLevel! >> "%LOGFILE%"
    echo.
    pause
    goto menu
)
echo %WHITE%[+] Ключ установлен.%RESET%
echo.

echo %RED%[*]%WHITE% Шаг 2/3 — Установка KMS-сервера...%RESET%
cscript //nologo %windir%\system32\slmgr.vbs /skms %KSERVER% >"%temp%\sp1rz_kms.txt" 2>&1
type "%temp%\sp1rz_kms.txt"
findstr /i /c:"error" /c:"ошибка" /c:"не удалось" "%temp%\sp1rz_kms.txt" >nul
if !errorLevel! neq 0 (
    echo %WHITE%[+] KMS-сервер: %RED%%KSERVER%%RESET%
) else (
    echo %RED%[!] %KSERVER% не сработал, пробую %KSERVER2% ...%RESET%
    cscript //nologo %windir%\system32\slmgr.vbs /skms %KSERVER2%
    echo %WHITE%[+] KMS-сервер: %RED%%KSERVER2%%RESET%
)
if exist "%temp%\sp1rz_kms.txt" del "%temp%\sp1rz_kms.txt" 2>nul
echo.

echo %RED%[*]%WHITE% Шаг 3/3 — Активация...%RESET%
cscript //nologo %windir%\system32\slmgr.vbs /ato
if !errorLevel! equ 0 (
    echo.
    echo %WHITE%[+] Команда активации выполнена.%RESET%
    echo [%date% %time%] Активация %WNAME% ^(%WKEY%^) через %KSERVER% - команда /ato выполнена >> "%LOGFILE%"
) else (
    echo.
    echo %RED%[-] Ошибка активации (код: !errorLevel!)%RESET%
    echo [%date% %time%] Активация %WNAME% ^(%WKEY%^) - ошибка /ato код !errorLevel! >> "%LOGFILE%"
)
echo.
echo %WHITE%Для проверки статуса: %RED%slmgr /xpr%RESET%
echo %WHITE%Лог: %RED%%LOGFILE%%RESET%
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
echo        %RED%=========================================%RESET%
echo        %WHITE%       Установка Microsoft Office        %RESET%
echo        %RED%=========================================%RESET%
echo.
echo        %WHITE%Выберите вариант:%RESET%
echo.
echo        %RED%[1]%WHITE% Microsoft 365 Apps for enterprise%RESET%
echo        %RED%[2]%WHITE% Office LTSC Professional Plus 2021%RESET%
echo        %RED%[3]%WHITE% Office Professional Plus 2019%RESET%
echo        %RED%[0]%WHITE% Назад%RESET%
echo.
set /p officechoice=%WHITE%Выбери пункт: %RESET%

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
echo %RED%[*]%WHITE% Установка: %OFFNAME%%RESET%
echo      %WHITE%Это может занять 10-30 минут, дождитесь завершения.%RESET%
echo.

:: --- Проверка: не установлен ли уже Office ---
reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" /v ProductReleaseIds >nul 2>&1
if !errorLevel! equ 0 (
    echo %RED%[=]%WHITE% Office уже установлен в системе, пропускаем.%RESET%
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
echo %RED%[*]%WHITE% Скачиваю установщик Office ^(setup.exe^)...%RESET%
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile '%ODTDIR%\setup.exe' -UseBasicParsing } catch { exit 1 }"

if not exist "%ODTDIR%\setup.exe" (
    echo %RED%[-] Не удалось скачать установщик.%RESET%
    echo [%date% %time%] %OFFNAME% - ошибка скачивания >> "%LOGFILE%"
    rmdir /s /q "%ODTDIR%" 2>nul
    echo.
    pause
    goto menu
)

:: --- Проверка размера ---
for %%F in ("%ODTDIR%\setup.exe") do set "ODTSIZE=%%~zF"
if !ODTSIZE! LSS 3000000 (
    echo %RED%[-] Файл слишком мал ^(!ODTSIZE! байт^), вероятно ошибка.%RESET%
    echo [%date% %time%] %OFFNAME% - setup.exe повреждён ^(!ODTSIZE!^) >> "%LOGFILE%"
    rmdir /s /q "%ODTDIR%" 2>nul
    echo.
    pause
    goto menu
)

:: --- Проверка MZ-заголовка (это .exe, а не HTML) ---
powershell -NoProfile -Command "$f=[IO.File]::ReadAllBytes('%ODTDIR%\setup.exe'); if ($f[0] -ne 77 -or $f[1] -ne 90) { exit 1 }"
if !errorLevel! neq 0 (
    echo %RED%[-] Скачался не EXE-файл ^(HTML/редирект^). Прерываю.%RESET%
    rmdir /s /q "%ODTDIR%" 2>nul
    echo.
    pause
    goto menu
)

:: --- Снимаем MOTW (Mark of the Web) ---
powershell -NoProfile -Command "Unblock-File -Path '%ODTDIR%\setup.exe' -ErrorAction SilentlyContinue" >nul 2>&1

echo %WHITE%[+] Установщик готов ^(!ODTSIZE! байт^).%RESET%
echo.

:: --- Создание configuration.xml ---
echo %RED%[*]%WHITE% Готовлю конфигурацию ^(канал: %OFFCHANNEL%^)...%RESET%
(
echo ^<Configuration^>
echo    ^<Add OfficeClientEdition="64" Channel="%OFFCHANNEL%"^>
echo      ^<Product ID="%OFFPROD%"^>
echo        ^<Language ID="ru-ru" /^>
echo        ^<Language ID="en-us" /^>
echo      ^</Product^>
echo    ^</Add^>
echo    ^<Property Name="AUTOACTIVATE" Value="0" /^>
echo    ^<Property Name="FORCEAPPSHUTDOWN" Value="TRUE" /^>
echo    ^<Display Level="Full" AcceptEULA="TRUE" /^>
echo    ^<Logging Level="Standard" Path="%ODTDIR%\log" /^>
echo ^</Configuration^>
) > "%ODTDIR%\configuration.xml"

:: --- Запуск установки ---
echo %RED%[*]%WHITE% Запускаю установщик Office...%RESET%
echo.
"%ODTDIR%\setup.exe" /configure "%ODTDIR%\configuration.xml"

if !errorLevel! equ 0 (
    echo.
    echo %WHITE%[+] %OFFNAME% успешно установлен.%RESET%
    echo [%date% %time%] %OFFNAME% - OK >> "%LOGFILE%"
) else (
    echo.
    echo %RED%[-] Установка завершилась с кодом !errorLevel!%RESET%
    echo      %WHITE%Подробный лог: %RED%%ODTDIR%\log%RESET%
    echo [%date% %time%] %OFFNAME% - ошибка, код !errorLevel! >> "%LOGFILE%"
)

echo.
echo %WHITE%Лог скрипта: %RED%%LOGFILE%%RESET%
echo.
pause
set "OFFPROD="
set "OFFNAME="
set "OFFCHANNEL="
set "ODTDIR="
set "ODTSIZE="
goto menu
