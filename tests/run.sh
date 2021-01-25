#!/bin/bash

case "$1" in
  5.[0123456789]*|gh)
    LUAV="$1"; shift ;;
  *)
    LUAV="5.1" ;;
esac

if [ "$LUAV" = "gh" ]; then
  LUA=lua
  LUAC=luac
  INC=../.lua/include
  set -e
else
  LUA="lua$LUAV"
  LUAC="luac$LUAV"
  INC="/usr/include/lua$LUAV"
  if [ ! -d "$INC" ]; then
    INC="/home/siffiejoe/.self/programs/lua$LUAV"
  fi
fi

echo -n "Using "
"$LUA" -v

gcc -Wall -Wextra -Os -fpic -I"$INC" -shared -o cmod.so cmod.c
gcc -Wall -Wextra -Os -fpic -I"$INC" -shared -o aiomod.so aiomod.c

"$LUAC" -o module1.luac module1.lua
"$LUAC" -o module2.luac module2.lua

echo -n "amalgamate modules only ... "
"$LUA" ../src/amalg.lua -o modules.lua module1 module2
"$LUA" -l modules main.lua

echo -n "amalgamate modules as fallbacks(1) ... "
"$LUA" ../src/amalg.lua -f -o fallbacks.lua module1 module2
"$LUA" -l fallbacks main.lua
echo -n "amalgamate modules as fallbacks(2) ... "
"$LUA" -l fallbacks -e "package.path=''" main.lua

echo -n "amalgamate modules and script in text form ... "
"$LUA" ../src/amalg.lua -o textout.lua -s main.lua module1 module2
"$LUA" -e 'package.path=""' textout.lua

echo -n "amalgamate modules and script in binary form ... "
"$LUA" -e 'package.path = "./?.luac;"..package.path' ../src/amalg.lua -o binout.lua -s main.lua module1 module2
"$LUA" -e 'package.path=""' binout.lua

echo -n "amalgamate and transform modules and script(1) ... "
"$LUA" -e 'package.path = "../src/?.lua;"..package.path' ../src/amalg.lua -o zippedout.lua -s main.lua -t luac -z brieflz module1 module2 && \
"$LUA" -e 'package.path=""' zippedout.lua

echo -n "amalgamate and transform modules and script(2) ... "
"$LUA" -e 'package.path = "../src/?.lua;"..package.path' ../src/amalg.lua -o dietout.lua -s main.lua -t luasrcdiet module1 module2 && \
"$LUA" -e 'package.path=""' dietout.lua

echo -n "amalgamate and transform in two steps ... "
"$LUA" ../src/amalg.lua -o- -s main.lua module1 module2 | \
"$LUA" -e 'package.path = "../src/?.lua;"..package.path' ../src/amalg.lua -o twosteps.lua -s- -t luasrcdiet -z brieflz && \
"$LUA" -e 'package.path=""' twosteps.lua

echo -n "amalgamate modules and script without arg fix ... "
"$LUA" ../src/amalg.lua -o afixout.lua -a -s main.lua module1 module2
"$LUA" -e 'package.path=""' afixout.lua

echo -n "amalgamate modules and script with debug info ... "
"$LUA" ../src/amalg.lua -o debugout.lua -d -s main.lua module1 module2
"$LUA" -e 'package.path=""' debugout.lua

echo -n "collect module names using amalg.lua as a module ... "
"$LUA" -e 'package.path = "../src/?.lua;"..package.path' -l amalg main.lua
echo -n "amalgamate modules and script using amalg.cache ... "
"$LUA" ../src/amalg.lua -o cacheout.lua -s main.lua -C amalg.cache
"$LUA" -e 'package.path=""' cacheout.lua

echo -n "amalgamate Lua modules, Lua script and C modules ... "
"$LUA" ../src/amalg.lua -o cmodout.lua -s main.lua -c -x
"$LUA" -e 'package.path,package.cpath="",""' cmodout.lua

echo -n "amalgamate Lua modules, Lua script and C modules compressed ... "
"$LUA" -e 'package.path = "../src/?.lua;"..package.path' ../src/amalg.lua -o zipcmodout.lua -s main.lua -c -x -t luasrcdiet -z brieflz && \
"$LUA" -e 'package.path,package.cpath="",""' zipcmodout.lua

echo -n "amalgamate Lua modules, Lua script and C modules in two steps ... "
"$LUA" ../src/amalg.lua -o- -s main.lua -c -x | \
"$LUA" -e 'package.path = "../src/?.lua;"..package.path' ../src/amalg.lua -o ctwosteps.lua -s- -t luasrcdiet -z brieflz && \
"$LUA" -e 'package.path,package.cpath="",""' ctwosteps.lua

echo -n "amalgamate Lua modules, but ignore C modules ... "
"$LUA" ../src/amalg.lua -o ignout.lua -s main.lua -c -x -i '^cmod' -i '^aiomod'
"$LUA" -e 'package.path=""' ignout.lua


if [ "$1" != keep ]; then
  rm -f module1.luac \
        module2.luac \
        modules.lua \
        fallbacks.lua \
        textout.lua \
        binout.lua \
        zippedout.lua \
        twosteps.lua \
        dietout.lua \
        afixout.lua \
        debugout.lua \
        cacheout.lua \
        cmodout.lua \
        zipcmodout.lua \
        ctwosteps.lua \
        ignout.lua \
        amalg.cache \
        cmod.so \
        aiomod.so
fi

