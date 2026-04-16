@echo off
cd "%~dp0"
chcp 65001 >nul
setlocal enabledelayedexpansion

set APP=4129620
set "WorkingDir=%~dp0R5\Binaries\Win64\WindroseServer-Win64-Shipping.exe"

:MAIN

:CHECK_STEAMCMD
echo ==========CHECKING STEAMCMD=========
set "STEAMCMD_DIR=..\steamcmd"
set "STEAMCMD_EXE=%STEAMCMD_DIR%\steamcmd.exe"

if exist "%STEAMCMD_EXE%" (
    echo SteamCMD found: %STEAMCMD_EXE%
    goto skip_steam
)

echo SteamCMD not found!
echo Downloading SteamCMD...

:DOWNLOAD_STEAMCMD
set "STEAMCMD_ZIP=steamcmd.zip"
set "STEAMCMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

REM Создаем директорию если её нет
if not exist "%STEAMCMD_DIR%" mkdir "%STEAMCMD_DIR%"

REM Скачиваем SteamCMD используя PowerShell
echo Downloading from %STEAMCMD_URL%
powershell -Command "Invoke-WebRequest -Uri '%STEAMCMD_URL%' -OutFile '%STEAMCMD_ZIP%'"

if not exist "%STEAMCMD_ZIP%" (
    echo Failed to download SteamCMD!
    echo Trying with bitsadmin...
    bitsadmin /transfer "DownloadSteamCMD" /download /priority normal "%STEAMCMD_URL%" "%CD%\%STEAMCMD_ZIP%"
)

if not exist "%STEAMCMD_ZIP%" (
    echo ERROR: Cannot download SteamCMD!
    pause
    exit /b 1
)

echo Extracting SteamCMD...
powershell -Command "Expand-Archive -Path '%STEAMCMD_ZIP%' -DestinationPath '%STEAMCMD_DIR%' -Force"

if exist "%STEAMCMD_ZIP%" del "%STEAMCMD_ZIP%"

if exist "%STEAMCMD_EXE%" (
    echo SteamCMD successfully installed!
) else (
    echo ERROR: Failed to extract SteamCMD!
    pause
    exit /b 1
)
:skip_steam

:: WINDROUSE ADDITION
set "ServerDescription=%~dp0R5\ServerDescription.json"
if not exist "%~dp0R5" mkdir "%~dp0R5"
if not exist "%ServerDescription%" (
    (
        echo {
        echo     "Version": 1,
        echo     "DeploymentId": "",
        echo     "ServerDescription_Persistent":
        echo     {
        echo         "PersistentServerId": "",
        echo         "InviteCode": "",
        echo         "IsPasswordProtected": false,
        echo         "Password": "",
        echo         "ServerName": "My_Server_TEST",
        echo         "WorldIslandId": "",
        echo         "MaxPlayerCount": 8,
        echo         "P2pProxyAddress": "127.0.0.1"
        echo     }
        echo }
    ) > "%ServerDescription%"
    echo [OK] ServerDescription.json created
)

set "Server_Start=%~dp0Server_Start.cmd"
if not exist "%Server_Start%" (
    (
        echo @echo off
        echo cd "%%~dp0"
        echo chcp 65001 ^>nul
        echo setlocal enabledelayedexpansion
        echo.
        echo.
        echo pushd "%%~dp0"
        echo start WindroseServer.exe -log -MULTIHOME=0.0.0.0 -PORT=7000 -QUERYPORT=7003
        echo popd
        echo.
    ) > "%Server_Start%"
    echo [OK] Server_Start.cmd created
)

:: END WINDROSE


:recheck
:: READ VERSION FROM MANIFEST
set "MANIFEST_FILE=%~dp0steamapps\appmanifest_4129620.acf"
if not exist "%MANIFEST_FILE%" (
    echo Error: File %MANIFEST_FILE% not found!
	goto skip_manifest
)
echo Alternative way get build in %MANIFEST_FILE%
for /f "usebackq tokens=* delims=" %%a in ("%MANIFEST_FILE%") do (
	echo %%a | find "TargetBuildID" > nul && set installedVersion=%%a
)
for /f "tokens=2 delims=	" %%a in ("!installedVersion!") do (
	set installedVersion=%%a
	set "installedVersion=!installedVersion:"=!"
	echo Installed: in %MANIFEST_FILE% - !installedVersion!
)
:skip_manifest
set "URL=https://api.steamcmd.net/v1/info/%APP%"
for /f %%x in ('powershell -command "Get-Date -format 'dd.MM.yyyy HH:mm:ss'"') do set datetime=%%x
set "date_time=%datetime% %TIME%"
set oldsteamdate=!installedVersion!
echo Versions check %URL%
:: Используем PowerShell для загрузки JSON и извлечения buildid из branches.public
for /f "usebackq delims=" %%i in (`powershell -Command "& { try { $data = Invoke-RestMethod -Uri '%URL%' -ErrorAction Stop; $buildid = $data.data.'%APP%'.depots.branches.public.buildid; Write-Output $buildid } catch { Write-Error 'Failed' } }" 2^>nul`) do set "BUILD_ID=%%i"
if defined BUILD_ID (
	set newsteamdate=%BUILD_ID%
) else (
    echo Failed to retrieve Build ID. Check App ID and internet connection.
	timeout /t 3
)

echo OLD:%oldsteamdate%
echo NEW:%newsteamdate%
if "%newsteamdate%" == "Internal S" echo "%newsteamdate%" Error get version, check again & goto Offline
if not "%oldsteamdate%"=="" if not "%newsteamdate%"=="" if not "%newsteamdate%"=="%oldsteamdate%" goto startupdate

:: CHECK OFFLINE
:Offline
:: FIND PID Path
if not exist WindroseServer.exe (
    echo Not Found WindroseServer.exe
	goto KILL
)
set "ProcessId="
set "ProcessFound="
TITLE !WorkingDir!
for /f "delims=" %%i in ('powershell.exe -command "$Processes = Get-Process; $Processes | Where-Object { $_.Path -like '*!WorkingDir%!' } | Select-Object -ExpandProperty Id"') do (
    set "ProcessFound=1"
    set "ProcessId=%%i"
)
if not defined ProcessFound (
    echo Процесс не найден !WorkingDir!
    echo Выполняем перезапуск.
	echo ==========Start Server=========
	call Server_Start.cmd
	timeout /t 10
	goto MAIN
) else (
    echo Найден !WorkingDir! с ID: %ProcessId%
    goto get_invite
)
timeout /t 60
goto recheck

:: END SCRIPT =====================================================================================================

:startupdate
ECHO KILL SERVER
:KILL
set "ProcessId="
set "ProcessFound="
TITLE !WorkingDir!

for /f "delims=" %%i in ('powershell.exe -command "$Processes = Get-Process; $Processes | Where-Object { $_.Path -like '*!WorkingDir%!' } | Select-Object -ExpandProperty Id"') do (
    set "ProcessFound=1"
    set "ProcessId=%%i"
)
if not defined ProcessFound (
    echo Процесс не найден !WorkingDir!, обновляем
	goto UPDATE
) else (
    echo Найден !WorkingDir! с ID: %ProcessId% KILL
    powershell.exe -command "$Processes = Get-Process; $Processes | Where-Object { $_.Path -like '*!WorkingDir!*' } | ForEach-Object { Stop-Process -Id $_.Id }"
    goto UPDATE
)
timeout /t 5
goto MAIN

:UPDATE
echo.
echo ==========UPDATING SERVER=========
set "Installdir=%~dp0."
echo Installing to: !Installdir!
echo.
"%STEAMCMD_EXE%" +force_install_dir "!Installdir!" +login anonymous +app_update %APP% validate +quit
echo.
echo ==========UPDATE COMPLETED=========
timeout /t 3
goto Offline

:get_invite
cls
echo.
echo Version Build:%oldsteamdate%
set "INVITE_CODE="
if not exist "%ServerDescription%" (
    echo Error: File %ServerDescription% not found!
    goto recheck
)

for /f "usebackq delims=" %%i in (`powershell -Command "& { $json = Get-Content '%ServerDescription%' -Raw | ConvertFrom-Json; $json.ServerDescription_Persistent.InviteCode }" 2^>nul`) do set "INVITE_CODE=%%i"

if defined INVITE_CODE (
    ECHO.
    echo ========== INVITE CODE =========
    ECHO Code: %INVITE_CODE%
)
timeout /t 60
goto recheck
