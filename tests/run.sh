#!/bin/bash

case "$1" in
  5.[0123456789]*|github)
    LUAV="$1"; shift ;;
  *)
    LUAV="5.1" ;;
esac

if [ "$LUAV" = "github" ]; then
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

cat > data.txt <<'EOF'
hello world
hello world
+1 -2.5 0xdeadbeef 1.5e1 1e1
12345678
EOF

cat > vscript.lua <<'EOF'
#!/usr/bin/env lua
return 123
EOF

cat > require-stub.lua <<'EOF'
do
  local builtin_require = require
  function require( ... )
    io.stdout:write( "r " )
    return builtin_require( ... )
  end
end
EOF


echo -n "amalgamate modules only ... "
"$LUA" ../src/amalg.lua -o modules-only.lua module1 module2
"$LUA" -l modules-only -e 'package.path=""' main.lua

echo -n "amalgamate modules with require stub ... "
"$LUA" ../src/amalg.lua --output=modules-with-stubbed-require.lua --prefix=require-stub.lua module1 module2
rm -f require-stub.lua
"$LUA" -l modules-with-stubbed-require -e 'package.path=""' main.lua

echo -n "amalgamate modules as fallbacks(1) ... "
"$LUA" ../src/amalg.lua --fallback --output modules-as-fallbacks.lua module1 module2
"$LUA" -l modules-as-fallbacks main.lua
echo -n "amalgamate modules as fallbacks(2) ... "
"$LUA" -l modules-as-fallbacks -e 'package.path=""' main.lua

echo -n "amalgamate modules and script in text form ... "
"$LUA" ../src/amalg.lua -o modules-and-script.lua -s main.lua module1 module2
"$LUA" -e 'package.path=""' modules-and-script.lua

echo -n "amalgamate modules and script in binary form ... "
"$LUA" -e 'package.path="./?.luac;"..package.path' ../src/amalg.lua -o binary-modules-and-script.lua --script main.lua --shebang="" module1 module2
"$LUA" -e 'package.path=""' binary-modules-and-script.lua

echo -n "amalgamate and transform modules and script(1) ... "
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o compiled-and-zipped.lua -s main.lua -t luac -z brieflz module1 module2 && \
"$LUA" -e 'package.path=""' compiled-and-zipped.lua

echo -n "amalgamate and transform modules and script(2) ... "
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o script-on-diet1.lua -s main.lua -t luasrcdiet module1 module2 && \
"$LUA" -e 'package.path=""' script-on-diet1.lua

echo -n "amalgamate and transform modules and script(3) ... "
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o script-on-diet2.lua -s main.lua -t dumbluaparser module1 module2 && \
"$LUA" -e 'package.path=""' script-on-diet2.lua

echo -n "amalgamate and transform in two steps ... "
"$LUA" ../src/amalg.lua -o- -s main.lua module1 module2 | \
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o amalgamated-then-zipped.lua -s- --transform=luasrcdiet --zip=brieflz && \
"$LUA" -e 'package.path=""' amalgamated-then-zipped.lua

echo -n "amalgamate modules and script without arg fix ... "
"$LUA" ../src/amalg.lua -o no-arg-fix.lua --no-argfix -s main.lua module1 module2
"$LUA" -e 'package.path=""' no-arg-fix.lua

echo -n "amalgamate modules and script with debug info ... "
"$LUA" ../src/amalg.lua -o with-debug-mode.lua --debug -s main.lua module1 module2
"$LUA" -e 'package.path=""' with-debug-mode.lua

echo -n "collect module names using amalg.lua as a module ... "
"$LUA" -e 'package.path="../src/?.lua;"..package.path' -l amalg main.lua
echo -n "amalgamate modules only using amalg.cache ... "
"$LUA" ../src/amalg.lua -o modules-only-from-cache.lua -s "" -c
"$LUA" -l modules-only-from-cache -e 'package.path=""' main.lua
echo -n "amalgamate modules and script using amalg.cache ... "
"$LUA" ../src/amalg.lua -o modules-and-script-from-cache.lua --cache-file=amalg.cache
"$LUA" -e 'package.path=""' modules-and-script-from-cache.lua

echo -n "amalgamate Lua modules, Lua script and C modules ... "
"$LUA" ../src/amalg.lua -o lua-and-c-modules.lua -s main.lua --use-cache --c-libs
"$LUA" -e 'package.path,package.cpath="",""' lua-and-c-modules.lua

echo -n "amalgamate Lua and MoonScript modules ... "
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o lua-and-moonscript-modules.lua -s main.moon -S "/usr/bin/env lua" -c -t moonscript && \
"$LUA" -e 'package.path=""' lua-and-moonscript-modules.lua

echo -n "amalgamate Lua and Teal modules ... "
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o lua-and-teal-modules.lua -s main.tl -c -t teal && \
"$LUA" -e 'package.path=""' lua-and-teal-modules.lua

echo -n "amalgamate Lua and Fennel modules ... "
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o lua-and-fennel-modules.lua -s main.fnl -c -t fennel && \
"$LUA" -e 'package.path=""' lua-and-fennel-modules.lua

echo -n "amalgamate Lua modules, Lua script and C modules compressed ... "
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o lua-and-c-modules-zipped.lua -s main.lua -c -x -t luasrcdiet -z brieflz && \
"$LUA" -e 'package.path,package.cpath="",""' lua-and-c-modules-zipped.lua

echo -n "amalgamate Lua modules, Lua script and C modules in two steps ... "
"$LUA" ../src/amalg.lua -o- -s main.lua -c -x | \
"$LUA" -e 'package.path="../src/?.lua;"..package.path' ../src/amalg.lua -o lua-and-c-modules-amalgamated-then-zipped.lua -s- -t luasrcdiet -z brieflz && \
"$LUA" -e 'package.path,package.cpath="",""' lua-and-c-modules-amalgamated-then-zipped.lua

echo -n "amalgamate Lua modules, but ignore C modules ... "
"$LUA" ../src/amalg.lua -o with-ignored-modules.lua -s main.lua -c -x --ignore='^cmod' -i '^aiomod'
"$LUA" -e 'package.path=""' with-ignored-modules.lua

echo -n "amalgamate with virtual IO ... "
"$LUA" ../src/amalg.lua -o with-virtual-io.lua -s vio.lua --virtual-io data.txt -v vscript.lua
rm -f data.txt vscript.lua
"$LUA" with-virtual-io.lua


if [ "$1" != keep ]; then
  rm -f module1.luac \
        module2.luac \
        modules-only.lua \
        modules-with-stubbed-require.lua \
        modules-as-fallbacks.lua \
        modules-and-script.lua \
        binary-modules-and-script.lua \
        compiled-and-zipped.lua \
        amalgamated-then-zipped.lua \
        script-on-diet1.lua \
        script-on-diet2.lua \
        no-arg-fix.lua \
        with-debug-mode.lua \
        modules-only-from-cache.lua \
        modules-and-script-from-cache.lua \
        lua-and-c-modules.lua \
        lua-and-moonscript-modules.lua \
        lua-and-teal-modules.lua \
        lua-and-fennel-modules.lua \
        lua-and-c-modules-zipped.lua \
        lua-and-c-modules-amalgamated-then-zipped.lua \
        with-ignored-modules.lua \
        with-virtual-io.lua \
        amalg.cache \
        cmod.so \
        aiomod.so
fi

