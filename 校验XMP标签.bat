@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title 亚马逊视频 AI 标记校验工具

rem ============================================================
rem   校验视频文件 XMP 元数据 dc:subject 字段里
rem   是否含有 contains-synthetic-performer
rem
rem   本脚本只读, 绝不修改任何视频文件
rem
rem   用法:
rem     方式1 - 把视频文件夹拖到本 bat 文件上
rem     方式2 - 在目标文件夹地址栏输入 cmd, 然后执行本 bat
rem     方式3 - 双击运行, 默认处理 bat 所在目录
rem
rem   开关:
rem     /exiftool - 强制用 exiftool 校验, 不走 Python 引擎
rem     /nopause  - 执行完不暂停, 适合自动化
rem
rem   引擎优先级:
rem     1 - Python + 校验XMP标签.py  (零额外安装, 诊断最细)
rem     2 - exiftool                (亚马逊官方推荐工具)
rem ============================================================

set "KEYWORD=contains-synthetic-performer"
set "NOPAUSE="
set "FORCE_EXIF="
set "RAWPATH="

rem ---------- 0. 解析命令行参数 ----------
if /i "%~1"=="/nopause" set "NOPAUSE=1"
if /i "%~1"=="/exiftool" set "FORCE_EXIF=1"
if /i "%~2"=="/nopause" set "NOPAUSE=1"
if /i "%~2"=="/exiftool" set "FORCE_EXIF=1"
if not "%~1"=="/nopause" if not "%~1"=="/exiftool" if not defined RAWPATH set "RAWPATH=%~1"
if not "%~2"=="/nopause" if not "%~2"=="/exiftool" if not defined RAWPATH set "RAWPATH=%~2"

rem ---------- 1. 解析目标目录 ----------
if not defined RAWPATH set "RAWPATH=%cd%"
if exist "!RAWPATH!\" (
  for %%I in ("!RAWPATH!") do set "TARGET=%%~fI"
) else (
  for %%I in ("!RAWPATH!") do set "TARGET=%%~dpI"
)
if "!TARGET:~-1!"=="\" set "TARGET=!TARGET:~0,-1!"
if not exist "!TARGET!\" (
  echo [错误] 目标路径不存在: !TARGET!
  echo.
  if not defined NOPAUSE pause
  exit /b 1
)

rem ---------- 2. 准备报告文件 ----------
set "REPORT=!TARGET!\AI标记检查结果.txt"
set "WORKLIST=!TARGET!\AI待补标清单.txt"
echo. > "!REPORT!" 2>nul
if errorlevel 1 (
  set "REPORT=%~dp0AI标记检查结果.txt"
  set "WORKLIST=%~dp0AI待补标清单.txt"
)

rem ---------- 3. 定位可用引擎 ----------
set "EXIFTOOL="
for /f "delims=" %%i in ('where exiftool 2^>nul') do if not defined EXIFTOOL set "EXIFTOOL=%%i"
if not defined EXIFTOOL if exist "%~dp0exiftool.exe" set "EXIFTOOL=%~dp0exiftool.exe"
if not defined EXIFTOOL if exist "%~dp0exiftool.cmd" set "EXIFTOOL=%~dp0exiftool.cmd"
if not defined EXIFTOOL if exist "%~dp0exiftool\exiftool.exe" set "EXIFTOOL=%~dp0exiftool\exiftool.exe"
if not defined EXIFTOOL if exist "C:\exiftool\exiftool.exe" set "EXIFTOOL=C:\exiftool\exiftool.exe"
if not defined EXIFTOOL if exist "D:\exiftool\exiftool.exe" set "EXIFTOOL=D:\exiftool\exiftool.exe"

set "PYEXE="
set "PYARG="
for /f "delims=" %%i in ('where python 2^>nul') do if not defined PYEXE set "PYEXE=%%i"
if not defined PYEXE for /f "delims=" %%i in ('where py 2^>nul') do (
  set "PYEXE=%%i"
  set "PYARG=-3"
)
set "SCRIPT=%~dp0校验XMP标签.py"

set "ENGINE="
if defined FORCE_EXIF if defined EXIFTOOL set "ENGINE=EXIF"
if not defined ENGINE if defined PYEXE if exist "!SCRIPT!" set "ENGINE=PY"
if not defined ENGINE if defined EXIFTOOL set "ENGINE=EXIF"

if not defined ENGINE (
  echo [错误] 找不到可用的校验引擎
  echo.
  echo   本工具需要下面任意一个:
  echo     1 - Python 3, 并把 校验XMP标签.py 放在本脚本同目录下
  echo     2 - exiftool, 放在本脚本同目录 或 C:\exiftool\ 或 D:\exiftool\
  echo.
  echo   exiftool 官方下载: https://exiftool.org
  echo.
  if not defined NOPAUSE pause
  exit /b 1
)
if defined FORCE_EXIF if not defined EXIFTOOL (
  echo [错误] 指定了 /exiftool, 但没有找到 exiftool
  echo.
  if not defined NOPAUSE pause
  exit /b 1
)

echo ============================================================
echo    亚马逊商品视频 AI 标记校验工具
echo    目标字段: XMP  -  dc:subject
echo    目标关键词: contains-synthetic-performer
echo ============================================================
echo [OK] 目标目录: !TARGET!
if "!ENGINE!"=="PY" (
  echo [OK] 校验引擎: Python  -  !PYEXE!
) else (
  echo [OK] 校验引擎: exiftool  -  !EXIFTOOL!
)
echo.

rem ---------- 4. 执行校验 ----------
if "!ENGINE!"=="PY" goto :pyEngine

rem exiftool 引擎
> "!REPORT!" echo 亚马逊视频 AI 标记检查报告
>>"!REPORT!" echo 检查时间: %DATE% %TIME%
>>"!REPORT!" echo 目标目录: !TARGET!
>>"!REPORT!" echo 校验字段: XMP-dc:Subject
>>"!REPORT!" echo 目标关键词: contains-synthetic-performer
>>"!REPORT!" echo.
> "!WORKLIST!" echo # 缺少 contains-synthetic-performer 标签的视频

set "CNT_OK=0"
set "CNT_MISS=0"
echo [扫描中] 正在校验 mp4 / mov / m4v 视频, 包含子目录...
echo.
for /r "%TARGET%" %%F in (*.mp4 *.mov *.m4v) do call :checkFile "%%F"

echo.
echo --------------------------------------------------------
echo    已标记: !CNT_OK!     未标记: !CNT_MISS!
echo    报告文件: !REPORT!
echo    待补标清单: !WORKLIST!
echo --------------------------------------------------------
if !CNT_MISS! GTR 0 (
  echo.
  echo [注意] 有 !CNT_MISS! 个文件缺少标签, 用 亚马逊视频AI标记.bat 跑一次即可补上
)
echo.
if not defined NOPAUSE pause
exit /b 0


rem ==================== 子程序 ====================
:checkFile
set "F=%~1"
set "NAME=%~nx1"
set "HIT="
rem 只查 XMP-dc:Subject 这一个标签, -s3 直接输出值
rem 若关键词被误写到 photoshop:Keywords 等其它字段, 这里查不到
for /f "usebackq delims=" %%L in (`call "!EXIFTOOL!" -XMP-dc:Subject -s3 "!F!" 2^>nul`) do (
  set "LN=%%L"
  if not "!LN!"=="!LN:contains-synthetic-performer=!" set "HIT=1"
)
if defined HIT (
  set /a CNT_OK+=1
  >>"!REPORT!" echo [已标记] !NAME!
  echo   [已标记] !NAME!
) else (
  set /a CNT_MISS+=1
  >>"!REPORT!" echo [未标记] !NAME!
  >>"!WORKLIST!" echo "!F!"
  echo   [未标记] !NAME!
)
goto :eof


rem ==================== Python 引擎 ====================
:pyEngine
set "PYTHONIOENCODING=utf-8"
"!PYEXE!" !PYARG! "!SCRIPT!" "!TARGET!" --quiet --report "!REPORT!" --worklist "!WORKLIST!"
set "RC=!errorlevel!"
echo.
if not defined NOPAUSE pause
exit /b !RC!
