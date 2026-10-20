@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title 亚马逊商品视频 AI 标记工具

rem ============================================================
rem   在视频文件 XMP 元数据的 dc:subject 字段写入标签
rem   contains-synthetic-performer
rem   亚马逊读取到后会自动在详情页显示 AI 生成人物提示
rem
rem   用法:
rem     方式1 - 把视频文件夹拖到本 bat 文件上
rem     方式2 - 在目标文件夹地址栏输入 cmd, 然后执行本 bat
rem     方式3 - 双击运行, 默认处理 bat 所在目录
rem
rem   开关:
rem     /check    - 只体检不修改, 列出哪些文件缺少标签, 并生成待补标清单
rem     /nopause  - 执行完不暂停, 适合自动化
rem     两个开关可组合, 顺序任意, 例如 /check /nopause
rem ============================================================

set "KEYWORD=contains-synthetic-performer"
set "NOPAUSE="
set "CHECK="
set "RAWPATH="

rem ---------- 0. 解析命令行参数 ----------
if /i "%~1"=="/nopause" set "NOPAUSE=1"
if /i "%~1"=="/check" set "CHECK=1"
if /i "%~2"=="/nopause" set "NOPAUSE=1"
if /i "%~2"=="/check" set "CHECK=1"
if /i "%~3"=="/nopause" set "NOPAUSE=1"
if /i "%~3"=="/check" set "CHECK=1"

rem 目标路径取第一个不是开关的参数
if not "%~1"=="/nopause" if not "%~1"=="/check" if not defined RAWPATH set "RAWPATH=%~1"
if not "%~2"=="/nopause" if not "%~2"=="/check" if not defined RAWPATH set "RAWPATH=%~2"
if not "%~3"=="/nopause" if not "%~3"=="/check" if not defined RAWPATH set "RAWPATH=%~3"

echo ============================================================
echo    亚马逊商品视频 AI 标记工具
echo    标签内容: contains-synthetic-performer
echo    写入位置: XMP  -  dc:subject
echo ============================================================
echo.

rem ---------- 1. 定位 exiftool ----------
set "EXIFTOOL="
for /f "delims=" %%i in ('where exiftool 2^>nul') do if not defined EXIFTOOL set "EXIFTOOL=%%i"
if not defined EXIFTOOL if exist "%~dp0exiftool.exe" set "EXIFTOOL=%~dp0exiftool.exe"
if not defined EXIFTOOL if exist "%~dp0exiftool.cmd" set "EXIFTOOL=%~dp0exiftool.cmd"
if not defined EXIFTOOL if exist "%~dp0exiftool\exiftool.exe" set "EXIFTOOL=%~dp0exiftool\exiftool.exe"
if not defined EXIFTOOL if exist "C:\exiftool\exiftool.exe" set "EXIFTOOL=C:\exiftool\exiftool.exe"
if not defined EXIFTOOL if exist "D:\exiftool\exiftool.exe" set "EXIFTOOL=D:\exiftool\exiftool.exe"
if not defined EXIFTOOL if exist "%LOCALAPPDATA%\exiftool\exiftool.exe" set "EXIFTOOL=%LOCALAPPDATA%\exiftool\exiftool.exe"
if not defined EXIFTOOL if exist "%ProgramFiles%\exiftool\exiftool.exe" set "EXIFTOOL=%ProgramFiles%\exiftool\exiftool.exe"
if not defined EXIFTOOL if exist "%ProgramFiles(x86)%\exiftool\exiftool.exe" set "EXIFTOOL=%ProgramFiles(x86)%\exiftool\exiftool.exe"

if not defined EXIFTOOL (
  echo [错误] 没有找到 exiftool
  echo.
  echo   请任选一种方式放置 exiftool:
  echo     1 - 放到本脚本同目录下, 文件名 exiftool.exe
  echo     2 - 放到本脚本同目录的 exiftool 子目录下
  echo     3 - 放到 C:\exiftool\ 或 D:\exiftool\
  echo     4 - 加进系统 PATH 后重新打开命令行
  echo.
  echo   官方下载: https://exiftool.org
  echo.
  if not defined NOPAUSE pause
  exit /b 1
)
echo [OK] exiftool: !EXIFTOOL!
echo.

rem ---------- 2. 解析目标目录 ----------
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
echo [OK] 目标目录: !TARGET!
echo.

rem ---------- 3. 准备报告文件 ----------
if defined CHECK (
  set "LOG=!TARGET!\AI标记检查结果.txt"
) else (
  set "LOG=!TARGET!\AI标记结果.txt"
)
echo. > "!LOG!" 2>nul
if errorlevel 1 set "LOG=%~dp0AI标记结果.txt"
if defined CHECK (
  > "!LOG!" echo 亚马逊商品视频 AI 标记检查报告
  set "MISS=!TARGET!\AI待补标清单.txt"
  echo. > "!MISS!" 2>nul
  if errorlevel 1 set "MISS=!LOG!"
) else (
  > "!LOG!" echo 亚马逊商品视频 AI 标记报告
)
>>"!LOG!" echo 生成时间: %DATE% %TIME%
>>"!LOG!" echo 目标目录: !TARGET!
>>"!LOG!" echo 标签: contains-synthetic-performer
>>"!LOG!" echo 模式: %KEYWORD% 存在即已标记
>>"!LOG!" echo.

set "CNT_NEW=0"
set "CNT_SKIP=0"
set "CNT_FAIL=0"

rem ---------- 4. 扫描并标记 ----------
rem    注意: for /r 的路径参数不能用 !TARGET!, 必须用 %TARGET%
echo [扫描中] 正在处理 mp4 / mov / m4v 视频, 包含子目录...
echo.
for /r "%TARGET%" %%F in (*.mp4 *.mov *.m4v) do call :doFile "%%F"

rem ---------- 5. 汇总 ----------
echo.
if !CNT_NEW! EQU 0 if !CNT_SKIP! EQU 0 if !CNT_FAIL! EQU 0 (
  echo [提示] 没有找到 mp4 / mov / m4v 视频文件
) else (
  echo --------------------------------------------------------
  if defined CHECK (
    echo    已有标签: !CNT_SKIP!     缺少标签: !CNT_FAIL!
  ) else (
    echo    新标记: !CNT_NEW!     已存在跳过: !CNT_SKIP!     失败: !CNT_FAIL!
  )
  echo    报告文件: !LOG!
  echo --------------------------------------------------------
)
if defined CHECK (
  if !CNT_FAIL! GTR 0 (
    echo.
    echo [注意] 有 !CNT_FAIL! 个文件缺少标签, 清单见: !MISS!
    echo 去掉 /check 再跑一次即可自动补上
  )
  echo.
  echo 检查模式未修改任何文件
) else (
  if !CNT_FAIL! GTR 0 (
    echo.
    echo [注意] 有 !CNT_FAIL! 个文件未能写入标签, 请查看报告中的 失败 行
  )
  echo.
  echo 标记完成后按正常流程上传视频即可
  echo 后台 账户状况 - 商品合规与真实性 若出现 Synthetic performer metadata missing 警示, 说明该素材漏标
)
echo.
if not defined NOPAUSE pause
exit /b 0


rem ==================== 子程序 ====================
:doFile
set "F=%~1"
set "NAME=%~nx1"

rem 先查是否已经带标签
rem 用 call 包裹, 避免被调用的程序污染当前批处理上下文
call "!EXIFTOOL!" -G1 -XMP-dc:Subject "!F!" 2>nul | findstr /i /c:"contains-synthetic-performer" >nul
if not errorlevel 1 (
  set /a CNT_SKIP+=1
  >>"!LOG!" echo [已标记] !NAME!
  echo   [已标记] !NAME!
  goto :eof
)

rem 检查模式: 只记录缺失, 不做任何修改
if defined CHECK (
  set /a CNT_FAIL+=1
  >>"!LOG!" echo [未标记] !NAME!
  >>"!MISS!" echo !NAME!
  echo   [未标记] !NAME!
  goto :eof
)

rem 写入标签, 加号是追加, 不会清掉原有关键词
call "!EXIFTOOL!" -overwrite_original -m -XMP-dc:Subject+=contains-synthetic-performer "!F!" >nul 2>&1

rem 写完立刻复检, 复检不通过才算失败
call "!EXIFTOOL!" -G1 -XMP-dc:Subject "!F!" 2>nul | findstr /i /c:"contains-synthetic-performer" >nul
if errorlevel 1 (
  set /a CNT_FAIL+=1
  >>"!LOG!" echo [失败] !NAME!
  echo   [失败] !NAME!
) else (
  set /a CNT_NEW+=1
  >>"!LOG!" echo [已标记] !NAME!
  echo   [已标记] !NAME!
)
goto :eof
