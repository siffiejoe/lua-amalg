@echo off & setlocal

set LR4WIN=C:\LR4Win

if [%1]==[51] (
  call :runtest 51
) else if [%1]==[52] (
  call :runtest 52
) else if [%1]==[53] (
  call :runtest 53
) else if [%1]==[54] (
  call :runtest 54
) else (
  call :runtest 51
)
goto :eof

:R
setlocal
echo %*
%*
endlocal
goto :eof

:runtest
setlocal
set _version=%1
set _dll=%LR4WIN%\lua\lua%_version%.dll
set _inc=%LR4WIN%\lua\include\lua%_version%
set _lua=lua%_version%
set _luac=luac%_version%

:: compile C modules
mingw32-gcc -O2 -I%_inc% -shared -o cmod.dll cmod.c %_dll% -lm
if errorlevel 1 goto :eof
mingw32-gcc -O2 -I%_inc% -shared -o aiomod.dll aiomod.c %_dll% -lm
if errorlevel 1 goto :eof

:: precompile lua code
%_luac% -o module1.luac module1.lua
if errorlevel 1 goto :eof
%_luac% -o module2.luac module2.lua
if errorlevel 1 goto :eof

echo Using Lua %_version% ...

echo amalgamate modules only ...
%_lua% ..\src\amalg.lua -o modules.lua module1 module2
%_lua% -l modules main.lua
if errorlevel 1 goto :eof

echo amalgamate modules as fallbacks[1] ...
%_lua% ..\src\amalg.lua -f -o fallbacks.lua module1 module2
%_lua% -l fallbacks main.lua
if errorlevel 1 goto :eof
echo amalgamate modules as fallbacks[2] ...
%_lua% -l fallbacks -e "package.path=''" main.lua
if errorlevel 1 goto :eof

echo amalgamate modules and script in text form ...
%_lua% ..\src\amalg.lua -o textout.lua -s main.lua module1 module2
%_lua% textout.lua
if errorlevel 1 goto :eof

echo amalgamate modules and script in binary form ...
%_lua% -e package.path='.\\?.luac;'..package.path ..\src\amalg.lua -o binout.lua -s main.lua module1 module2
%_lua% binout.lua
if errorlevel 1 goto :eof

echo amalgamate modules and script without arg fix ...
%_lua% ..\src\amalg.lua -o afixout.lua -a -s main.lua module1 module2
%_lua% afixout.lua
if errorlevel 1 goto :eof

echo amalgamate modules and script with debug info ...
%_lua% ..\src\amalg.lua -o debugout.lua -d -s main.lua module1 module2
%_lua% debugout.lua
if errorlevel 1 goto :eof

echo collect module names using amalg.lua as a module ...
%_lua% -e package.path='..\\src\\?.lua;'..package.path -l amalg main.lua
echo amalgamate modules and script using amalg.cache ...
%_lua% ..\src\amalg.lua -o cacheout.lua -s main.lua -c
%_lua% cacheout.lua
if errorlevel 1 goto :eof

echo amalgamate Lua modules, Lua script, and C modules ...
%_lua% ..\src\amalg.lua -o cmodout.lua -s main.lua -c -x
%_lua% -e package.cpath='' cmodout.lua
if errorlevel 1 goto :eof

echo amalgamate Lua modules, but ignore C modules ... "
%_lua% ..\src\amalg.lua -o ignout.lua -s main.lua -c -x -i ^^cmod -i ^^aiomod
%_lua% ignout.lua
if errorlevel 1 goto :eof

endlocal
goto :eof

