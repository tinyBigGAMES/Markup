@echo off
setlocal

set SRC=c_demo.c
set OUT=..\..\..\bin\c_demo.exe
set INC=..\include

if "%~1"=="" (
    echo Compiling with: zig cc [default]
    zig cc %SRC% -I%INC% -O3 -o %OUT%
    del ..\..\..\bin\c_demo.pdb 2>nul
) else (
    echo Compiling with: %*
    %* %SRC% -I%INC% -o %OUT%
)
if errorlevel 1 (
    echo Compilation failed.
    exit /b 1
)
echo Built: %OUT%

pause
