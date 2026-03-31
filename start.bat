@echo off
setlocal

:: --- Настройки ---
set "VIENNA_DIR=."
set "EVENTBUS_PORT=5532"
set "OBJECTSTORE_PORT=5396"
set "DATA_DIR=%VIENNA_DIR%\data"

:: --- Функция ожидания порта ---
:WaitForPort
set "host=%1"
set "port=%2"
echo Ожидание %host%:%port%...
:CheckPort
powershell -Command "try { \$tcp = New-Object System.Net.Sockets.TcpClient('%host%', %port%); \$tcp.Close(); exit 0 } catch { exit 1 }"
if errorlevel 1 (
    timeout /t 1 >nul
    goto CheckPort
)
echo %host%:%port% доступен!
goto :eof

:: --- Функция запуска JAR с логом ---
:RunJar
set "jar_path=%1"
shift
echo Запускаем %jar_path% %* ...
start "" java -jar "%jar_path%" %* > "%jar_path%.log" 2>&1
goto :eof

:: --- 1. Event Bus ---
set "EVENTBUS_SERVER=%VIENNA_DIR%\eventbus-server-0.0.1-SNAPSHOT-jar-with-dependencies.jar"
call :RunJar "%EVENTBUS_SERVER%"
call :WaitForPort "localhost" %EVENTBUS_PORT%

:: --- 2. Object Store ---
set "OBJECTSTORE_SERVER=%VIENNA_DIR%\objectstore-server-0.0.1-SNAPSHOT-jar-with-dependencies.jar"
call :RunJar "%OBJECTSTORE_SERVER%" -dataDir "%DATA_DIR%" -port %OBJECTSTORE_PORT%
call :WaitForPort "localhost" %OBJECTSTORE_PORT%

:: --- 3. Остальные JAR ---
for %%F in (%VIENNA_DIR%\*.jar) do (
    if /I not "%%F"=="%EVENTBUS_SERVER%" if /I not "%%F"=="%OBJECTSTORE_SERVER%" if /I not "%%F"=="apiserver.jar" (
        call :RunJar "%%F"
    )
)

:: --- 4. API Server ---
start "" java -jar apiserver.jar --db "%VIENNA_DIR%\earth.db" --staticData "%DATA_DIR%"

echo Все JAR файлы Vienna запущены!

endlocal
pause

start "%VIENNA_DIR%\stop.bat"