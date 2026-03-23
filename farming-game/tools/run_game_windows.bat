@echo off
setlocal EnableDelayedExpansion
REM Run the project from a visible console (like Godot MCP does).
REM Double-click this file, or run from cmd from anywhere.
REM
REM Option A — folder that contains the Godot *console* build:
REM   set GODOT=C:\Apps\Godot\Godot_v4.6.1-stable_win64
REM   tools\run_game_windows.bat
REM
REM Option B — full path to the *console* build (shows log window):
REM   set GODOT_EXE=C:\Program Files\Godot\godot_console.exe
REM   tools\run_game_windows.bat
REM
REM Optional GPU fallback:
REM   set EXTRA_ARGS=--rendering-driver opengl3

cd /d "%~dp0.."
if not exist "project.godot" (
  echo ERROR: project.godot not found in "%CD%"
  echo This script must live in farming-game\tools\
  pause
  exit /b 1
)

set "GODOT_EXE_RESOLVED="

if defined GODOT_EXE (
  if exist "%GODOT_EXE%" set "GODOT_EXE_RESOLVED=%GODOT_EXE%"
)

if not defined GODOT_EXE_RESOLVED if defined GODOT (
  if exist "%GODOT%\godot_console.exe" set "GODOT_EXE_RESOLVED=%GODOT%\godot_console.exe"
)
if not defined GODOT_EXE_RESOLVED if defined GODOT (
  if exist "%GODOT%\godot-console.exe" set "GODOT_EXE_RESOLVED=%GODOT%\godot-console.exe"
)
if not defined GODOT_EXE_RESOLVED if defined GODOT (
  if exist "%GODOT%\Godot_console.exe" set "GODOT_EXE_RESOLVED=%GODOT%\Godot_console.exe"
)
if not defined GODOT_EXE_RESOLVED if defined GODOT (
  for %%F in ("%GODOT%\Godot_*win64_console.exe") do (
    if exist "%%~fF" set "GODOT_EXE_RESOLVED=%%~fF"
  )
)
if not defined GODOT_EXE_RESOLVED if defined GODOT (
  for %%F in ("%GODOT%\Godot_*_console.exe") do (
    if exist "%%~fF" set "GODOT_EXE_RESOLVED=%%~fF"
  )
)

REM Common install: C:\Program Files\Godot\ (you renamed to godot.exe / godot-console.exe)
if not defined GODOT_EXE_RESOLVED if exist "%ProgramFiles%\Godot\godot_console.exe" (
  set "GODOT_EXE_RESOLVED=%ProgramFiles%\Godot\godot_console.exe"
)
if not defined GODOT_EXE_RESOLVED if exist "%ProgramFiles%\Godot\godot-console.exe" (
  set "GODOT_EXE_RESOLVED=%ProgramFiles%\Godot\godot-console.exe"
)
if not defined GODOT_EXE_RESOLVED if exist "%ProgramFiles(x86)%\Godot\godot_console.exe" (
  set "GODOT_EXE_RESOLVED=%ProgramFiles(x86)%\Godot\godot_console.exe"
)
if not defined GODOT_EXE_RESOLVED if exist "%ProgramFiles(x86)%\Godot\godot-console.exe" (
  set "GODOT_EXE_RESOLVED=%ProgramFiles(x86)%\Godot\godot-console.exe"
)

REM On PATH (rare, but helpful): "where" prints nothing if not found — loop simply does not run.
if not defined GODOT_EXE_RESOLVED (
  for /f "delims=" %%i in ('where Godot_v4.6.1-stable_win64_console.exe 2^>nul') do (
    set "GODOT_EXE_RESOLVED=%%i"
    goto :have_exe
  )
)
if not defined GODOT_EXE_RESOLVED (
  for /f "delims=" %%i in ('where godot_console.exe 2^>nul') do (
    set "GODOT_EXE_RESOLVED=%%i"
    goto :have_exe
  )
)
if not defined GODOT_EXE_RESOLVED (
  for /f "delims=" %%i in ('where godot-console.exe 2^>nul') do (
    set "GODOT_EXE_RESOLVED=%%i"
    goto :have_exe
  )
)
if not defined GODOT_EXE_RESOLVED (
  for /f "delims=" %%i in ('where Godot_console.exe 2^>nul') do (
    set "GODOT_EXE_RESOLVED=%%i"
    goto :have_exe
  )
)

:have_exe
if not defined GODOT_EXE_RESOLVED (
  echo Could not find a Godot *console* executable.
  echo.
  echo Look for the build that shows a black console window, e.g.:
  echo   godot_console.exe   ^(your current name^)
  echo   godot-console.exe   ^(your rename^)
  echo   Godot_*_win64_console.exe   ^(official zip name^)
  echo.
  echo Fix one of these:
  echo   1^) set GODOT=C:\Program Files\Godot   ^(folder with godot_console.exe^)
  echo   2^) set GODOT_EXE=full\path\to\godot_console.exe
  echo   3^) Add that folder to PATH
  echo.
  pause
  exit /b 1
)

echo Project:  "%CD%"
echo Godot:    "!GODOT_EXE_RESOLVED!"
for %%F in ("!GODOT_EXE_RESOLVED!") do echo Exe name: %%~nxF
echo Extra:    %EXTRA_ARGS%
echo.

"!GODOT_EXE_RESOLVED!" --path "%CD%" %EXTRA_ARGS%
set ERR=!ERRORLEVEL!
echo.
echo Exit code: !ERR!
pause
exit /b !ERR!
