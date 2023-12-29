@echo off

:: version : v3
:: 请使用GBK 编码加载此文件和 import.conf文件

title %0

@setlocal
set ERROR_CODE=0

@REM ==== START configFile VALIDATION ====
set DIRNAME=%~dp0
if "%DIRNAME%" == "" set DIRNAME=.
set SCRIPT_HOME=%DIRNAME%
for %%i in ("%SCRIPT_HOME%") do set SCRIPT_HOME=%%~fi

SET CONFIG_FILE=%SCRIPT_HOME%import.conf
if exist "%CONFIG_FILE%" goto checkDm
echo [警告]您的配置文件import.conf不存在 >&2
goto error
@REM ==== END configFile VALIDATION ====

@rem ==== START CONFIG FORMAT VALIDATION ====
:checkDm
@setlocal EnableExtensions EnableDelayedExpansion
for /F "tokens=1 delims=:" %%a in ('findstr /n /x /c:[dm] "%CONFIG_FILE%"') do set dmLine=%%a
@endlocal & set dmLine=%dmLine%

if not "%dmLine%" == "" goto checkSettings
echo [警告]您的配置文件dm节点不存在，请检查dm节点 >&2
goto error

:checkSettings
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

if not "%datasourceLine%" == "" goto endConfigFormatValidation
echo [警告]您的配置文件datasource节点不存在，请检查datasource节点 >&2
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
echo [警告]您没有指定达梦主目录，请在环境变量中设置DM_HOME变量, 或者在"%CONFIG_FILE%"中设置dm-home >&2
goto error

:OkDmHome
if exist "%DM_HOME%\bin\dimp.exe" goto readHost
echo [警告]您的达梦主目录设置了一个错误的路径，请在环境变量中正确设置DM_HOME变量, 或者在import.conf中正确设置dm-home >&2
goto error

@rem :readParaller
@rem for /F "usebackq eol=# skip=%dmLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
@rem     if "%%A"=="paraller" set CPU_NUM=%%B& goto checkParaller
@rem )

@rem :checkParaller
@rem if not "%CPU_NUM%" == "" goto readHost
@rem set CPU_NUM=4

@rem ==== START READ datasource CONFIG ====
:readHost
@setlocal EnableExtensions EnableDelayedExpansion
for /F "usebackq eol=# skip=%datasourceLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="host" set host=%%B& goto checkHost
)
:checkHost
if not "%host%" == "" goto readPort
echo [警告]导入数据库host不能为空 >&2

goto error 

:readPort
for /F "usebackq eol=# skip=%datasourceLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="port" set port=%%B& goto checkPort
)
:checkPort
if not "%port%" == "" goto readUsername
echo [警告]导入数据库port不能为空 >&2
goto error 

:readUsername
for /F "usebackq eol=# skip=%datasourceLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="username" set username=%%B& goto checkUsername
)
:checkUsername
if not "%username%" == "" goto readPassword
echo [警告]导入数据库username不能为空 >&2
goto error

:readPassword
for /F "usebackq eol=# skip=%datasourceLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="password" set password=%%B& goto checkUsername
)
:checkUsername
if not "%password%" == "" goto endConfigValidation
echo [警告]导入数据库password不能为空 >&2
goto error

:endConfigValidation
@endlocal &set URL="""%username%"""/"""%password%"""@%host%:%port%
@rem ==== END READ datasource CONFIG ====

@rem ==== START READ settings CONFIG ====
@rem 从参数处读取一次
set directory=%1
if not "%directory%" == "" goto checkDirectoryExists

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
echo [警告]导入数据库directory配置不存在 >&2
goto error

:checkDirectory
@rem set a default dir
if not "%directory%" == "" goto checkDirectoryExists
echo [警告]请在%CONFIG_FILE%文件'directory'项中, 设置导入文件所在目录 >&2
goto error

:checkDirectoryExists
if exist "%directory%" goto checkDmp
echo [警告]导入文件所在目录"%DIRECTORY%"不存在 >&2
goto error

:checkDmp
@rem ==== END READ settings CONFIG ====
if exist "%directory%\imp_exp.dmp" goto readSchemas
echo [警告]"%DIRECTORY%"下没有发发现可导入的文件'imp_exp.dmp' >&2
goto error

:readSchemas
@setlocal EnableExtensions EnableDelayedExpansion
for /F "usebackq eol=# skip=%settingsLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="schemas" set schemas=%%B& goto checkSchemas
)

:checkSchemas
if not "%schemas%" == "" goto readAction
echo [警告]导入数据库schemas不能为空 >&2
goto error

:readAction
@setlocal EnableExtensions EnableDelayedExpansion
for /F "usebackq eol=# skip=%settingsLine% tokens=1,2 delims==" %%A in ("%CONFIG_FILE%") DO (
    if "%%A"=="table-exists-action" set ACTION=%%B& goto checkAction
)
:checkAction
if not "%ACTION%" == "" goto takeAction
set TABLE_EXISTS_ACTION_ARG=
goto buildImportArgs

:takeAction
set TABLE_EXISTS_ACTION_ARG=TABLE_EXISTS_ACTION=%ACTION%
goto buildImportArgs

:buildImportArgs
SET DIMP_EXE=%DM_HOME%\bin\dimp.exe
SET SCHEMAS=SCHEMAS=("""%schemas%""")
SET FILE=FILE=imp_exp.dmp
SET DIRECTORY_PATH=DIRECTORY=%DIRECTORY%
SET COMMON_ARGS=IGNORE=N COMPILE=Y INDEXFIRST=N TABLE_FIRST=N LOCAL=N COMMIT_ROWS=5000 FAST_LOAD=N 
@rem set OPTION_ARGS=PARALLEL=%CPU_NUM% TABLE_PARALLEL=%CPU_NUM%

@setlocal EnableExtensions EnableDelayedExpansion
for /f "tokens=2 delims==" %%G in ('wmic OS Get localdatetime /value') do set "dt=%%G"
set "year=%dt:~0,4%"
set "month=%dt:~4,2%"
set "day=%dt:~6,2%"
set "hour=%dt:~8,2%"
set "minute=%dt:~10,2%"
set "second=%dt:~12,2%"
@endlocal & set "NOW=%year%_%month%_%day%_%hour%_%minute%_%second%"
set IMPORT=imp_%NOW%
SET LOG=LOG=%IMPORT%.log LOG_WRITE=N

::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::
"%DIMP_EXE%"^
 %URL%^
 %DIRECTORY_PATH%^
 %FILE%^
 %SCHEMAS%^
 %COMMON_ARGS%^
 %TABLE_EXISTS_ACTION_ARG%^
 %LOG%

@rem explorer.exe "%DIRECTORY%"
goto end

:error 
set ERROR_CODE=1
echo [警告]导入执行中止 >&2

:end
@endlocal & set ERROR_CODE=%ERROR_CODE%

pause