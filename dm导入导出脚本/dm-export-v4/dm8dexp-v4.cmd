@echo off

:: version : v4
:: 请使用GBK 编码加载此文件和 export.conf文件

title %0

@setlocal
set ERROR_CODE=0

@REM ==== START configFile VALIDATION ====
set DIRNAME=%~dp0
if "%DIRNAME%" == "" set DIRNAME=.
set SCRIPT_HOME=%DIRNAME%
for %%i in ("%SCRIPT_HOME%") do set SCRIPT_HOME=%%~fi

SET CONFIG_FILE=%SCRIPT_HOME%export.conf
if exist "%CONFIG_FILE%" goto configFormatValidation
echo [警告]您的配置文件export.conf不存在 >&2
goto error
@REM ==== END configFile VALIDATION ====

@rem ==== START CONFIG FORMAT VALIDATION ====
:configFormatValidation
@setlocal EnableExtensions EnableDelayedExpansion
for /F "tokens=1 delims=:" %%a in ('findstr /n /x /c:[settings] "%CONFIG_FILE%"') do set settingsLine=%%a
@endlocal & set settingsLine=%settingsLine%

if not "%settingsLine%" == "" goto checkDatasource
echo [警告]您的配置文件settings节点不存在，请检查settings节点 >&2
goto error

:checkDatasource
@setlocal EnableExtensions EnableDelayedExpansion
for /F "tokens=1 delims=:" %%a in ('findstr /n /x /c:[datasource] "%CONFIG_FILE%"') do set datasourceLine=%%a
@endlocal & set datasourceLine=%datasourceLine%

if not "%datasourceLine%" == "" goto checkData
echo [警告]您的配置文件datasource节点不存在，请检查datasource节点 >&2
goto error

:checkData
@setlocal EnableExtensions EnableDelayedExpansion
for /F "tokens=1 delims=:" %%a in ('findstr /n /x /c:[data] "%CONFIG_FILE%"') do set dataLine=%%a
@endlocal & set dataLine=%dataLine%

if not "%dataLine%" == "" goto checkDm
echo [警告]您的配置文件data节点不存在，请检查data节点 >&2
goto error

:checkDm
@setlocal EnableExtensions EnableDelayedExpansion
for /F "tokens=1 delims=:" %%a in ('findstr /n /x /c:[dm] "%CONFIG_FILE%"') do set dmLine=%%a
@endlocal & set dmLine=%dmLine%

if not "%dmLine%" == "" goto endConfigFormatValidation
echo [警告]您的配置文件dm节点不存在，请检查dm节点 >&2
goto error

:endConfigFormatValidation
@rem ==== END CONFIG FORMAT VALIDATION ====
@setlocal EnableExtensions EnableDelayedExpansion
for /F "usebackq eol=# skip=%dmLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="dm-home" set DM_HOME_SETTINGS=%%B& goto checkDmHome
)

:checkDmHome
if not "%DM_HOME_SETTINGS%" == "" set DM_HOME=%DM_HOME_SETTINGS%& goto OkDmHome
if not "%DM_HOME%" == "" goto OkDmHome
echo [警告]您没有指定达梦主目录，请在环境变量中设置DM_HOME变量, 或者在export.conf中设置dm-home >&2
goto error

:OkDmHome
if exist "%DM_HOME%\bin\dexp.exe" goto OkDmExe
echo [警告]您的达梦主目录设置了一个错误的路径，请在环境变量中正确设置DM_HOME变量, 或者在export.conf中正确设置dm-home >&2
goto error

:OkDmExe
SET DEXP_EXE=%DM_HOME%\bin\dexp.exe
for /F "usebackq eol=# skip=%dmLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="paraller" set CPU_NUM=%%B& goto readCupNum
)

:readCupNum
if not "%CPU_NUM%" == "" goto readHost
set CPU_NUM=4

@rem ==== START READ datasource CONFIG ====
:readHost
@setlocal EnableExtensions EnableDelayedExpansion
for /F "usebackq eol=# skip=%datasourceLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="host" set host=%%B& goto checkHost
)
:checkHost
if not "%host%" == "" goto readPort
echo [警告]导出数据库host不能为空 >&2

goto error 

:readPort
for /F "usebackq eol=# skip=%datasourceLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="port" set port=%%B& goto checkPort
)
:checkPort
if not "%port%" == "" goto readUsername
echo [警告]导出数据库port不能为空 >&2

goto error 

:readUsername
for /F "usebackq eol=# skip=%datasourceLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="username" set username=%%B& goto checkUsername
)
:checkUsername
if not "%username%" == "" goto readPassword
echo [警告]导出数据库username不能为空 >&2

goto error

:readPassword
for /F "usebackq eol=# skip=%datasourceLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="password" set password=%%B& goto checkUsername
)
:checkUsername
if not "%password%" == "" goto endConfigValidation
echo [警告]导出数据库password不能为空 >&2

goto error

:endConfigValidation
@endlocal &set URL="""%username%"""/"""%password%"""@%host%:%port%
@rem ==== END READ datasource CONFIG ====

@rem ==== START BUILD now FORMAT ====
@setlocal EnableExtensions EnableDelayedExpansion
for /f "tokens=2 delims==" %%G in ('wmic OS Get localdatetime /value') do set "dt=%%G"
set "year=%dt:~0,4%"
set "month=%dt:~4,2%"
set "day=%dt:~6,2%"
set "hour=%dt:~8,2%"
set "minute=%dt:~10,2%"
set "second=%dt:~12,2%"
@endlocal & set "NOW=%year%_%month%_%day%_%hour%_%minute%_%second%"
@rem ==== END BUILD now FORMAT ====

@rem BUILD a str EXPORT
set EXPORT=exp_%NOW%

@rem ==== START READ settings CONFIG ====
@setlocal EnableExtensions EnableDelayedExpansion
set /A settingsStartLine=%settingsLine%
set /A settingsEndLine=%datasourceLine%
set /A currentLine=%settingsLine%
for /F "usebackq eol=# skip=%settingsStartLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
	set /A currentLine+=1
	if "%%A"=="directory" set directory=%%B& goto checkDirectory
	if "!currentLine!" == "%settingsEndLine%" goto directoryNotFind
)

:directoryNotFind
echo [警告]导出数据库directory配置不存在 >&2
goto error

:checkDirectory
@rem set a default dir
if "%directory%" == "" set directory=%userprofile%\Desktop\
@rem set user dir with a timestamp dir
@rem for %%i in ("%directory%") do set directory=%%~fi\%EXPORT%
for %%I in ("%directory%") do set directory_home=%%~dpI
for %%I in ("%directory_home%.") do set directory_home=%%~dpfI
set directory=%directory_home%\%EXPORT%
@endlocal & set DIRECTORY=%directory%
@rem ==== END READ settings CONFIG ====

@rem ==== START READ data CONFIG ====
@setlocal EnableExtensions EnableDelayedExpansion
for /F "usebackq eol=# skip=%dataLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="schemas" set schemas=%%B& goto checkSchema
)
:checkSchema
if not "%schemas%" == "" goto readTables
echo [警告]导出数据库schemas不能为空 >&2

goto error

:readTables
for /F "tokens=1 delims=:" %%a in ('findstr /n /x /c:"tables=" "%CONFIG_FILE%"') do set tablesLine=%%a

@rem 没有定义tables 直接读取schema 
if "%tablesLine%" == "" SET mode=SCHEMAS=("""%schemas%""")& goto endReadTables

for /F "usebackq eol=# skip=%tablesLine%" %%a in ("%CONFIG_FILE%") do (
	if defined tables (
		set tables=!tables!,"""%schemas%"""."""%%a"""
	) else (
		set tables="""%schemas%"""."""%%a"""
	)
)
@rem 这里有版本区别
set mode=TABLES=(%tables%)
:endReadTables
@endlocal & set MODE=%mode%
@rem ==== END READ data CONFIG ====

@rem ==== START BUILD dxep args  ====
@rem 可以通过配置文件继续配置，然后读取，懒的做了
SET FILE=FILE=imp_exp.dmp
SET LOG=LOG=%EXPORT%.log
SET DIRECTORY_PATH=DIRECTORY=%DIRECTORY%
SET TABLESPACE=TABLESPACE=N
SET DROP=DROP=N
SET LOG_WRITE=LOG_WRITE=N
@rem ==== END BUILD dxep args  ====

@rem  ====options settings 
set OPTIONS_ARG=PARALLEL=%CPU_NUM% TABLE_PARALLEL=%CPU_NUM% TABLE_POOL=%CPU_NUM%

@rem ==== START CREATE DIRECTORY ====
if not exist "%DIRECTORY%" mkdir "%DIRECTORY%" 2>nul
if not ERRORLEVEL 1 goto createSuccess
echo [警告]创建"%DIRECTORY%"文件夹失败，系统找不到指定的驱动器 >&2
goto error

:createSuccess
@rem ==== END CREATE DIRECTORY  ====

::::::::::::::::::::::::::::::::::::::::::
@rem echo ===================================
@rem echo %URL% %DIRECTORY_PATH% %FILE% %MODE% %TABLESPACE% %DROP% %LOG% %LOG_WRITE%
::::::::::::::::::::::::::::::::::::::::::
"%DEXP_EXE%"^
 %URL%^
 "%DIRECTORY_PATH%"^
 %FILE%^
 %MODE%^
 %TABLESPACE%^
 %DROP%^
 %LOG%^
 %LOG_WRITE%^
 %OPTIONS_ARG%

@rem explorer.exe "%DIRECTORY%"

goto end

:error 
set ERROR_CODE=1
echo [警告]导出执行中止 >&2

:end
@endlocal & set ERROR_CODE=%ERROR_CODE%

cmd /C pause