#            Amalg -- Amalgamation of Lua Modules/Scripts            #

##                           Introduction                           ##

Deploying a Lua application that is split among multiple modules is a
challenge. A tool that can package a Lua script and its modules into
a single file is a valuable help. This is such a tool.

Features:

*   Pure Lua (compatible with Lua 5.1 and up), no other external
    dependencies. (Even works for modules using the deprecated
    `module` function.)
*   You don't have to take care of the order in which the modules are
    `require`'d.
*   Can embed compiled C modules.
*   Can collect `require`'d Lua (and C) modules automatically.

What it doesn't do:

*   It does not compile to bytecode. Use `luac` for that yourself, or
    take a look at [squish][1], or [luac.lua][4].
*   It doesn't do static analysis of Lua code to collect `require`'d
    modules. That won't work reliably anyway. You can write your own
    program for that (using the output of `luac -p -l`), or use
    [squish][1], or [soar][3] instead.
*   It will not compress, minify, obfuscate your Lua source code, or
    any of the other things [squish][1] can do.
*   It doesn't handle the dependencies of C modules.

There are alternatives to this program: See [squish][1], [LOOP][2],
[soar][3], [luac.lua][4], and [bundle.lua][5] (and probably some
more).

  [1]: http://matthewwild.co.uk/projects/squish/home
  [2]: http://loop.luaforge.net/release/preload.html
  [3]: http://lua-users.org/lists/lua-l/2012-02/msg00609.html
  [4]: http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/5.1/luac.lua
  [5]: https://github.com/akavel/scissors/blob/master/tools/bundle/bundle.lua


##                          Getting Started                         ##

You can bundle a collection of modules in a single file by calling the
`amalg.lua` script and passing the module names on the commandline.

    ./amalg.lua module1 module2

The modules are collected using `package.path`, so they have to be
available there. The resulting merged Lua code will be written to the
standard output stream. You have to run the code to make the embedded
Lua modules available for `require`.

You can specify an output file to use instead of the standard output
stream.

    ./amalg.lua -o out.lua module1 module2

You can also embed the main script of your application in the merged
Lua code as well. Of course the embedded Lua modules can be
`require`'d in the main script.

    ./amalg.lua -o out.lua -s main.lua module1 module2

If you want the original file names and line numbers to appear in
error messages, you have to activate debug mode. This will require
slightly more memory, however.

    ./amalg.lua -o out.lua -d -s main.lua module1 module2

To collect all Lua (and C) modules used by a program, you can load the
`amalg.lua` script as a module, and it will intercept calls to
`require` and save the necessary Lua module names in a file
`amalg.cache` in the current directory.

    lua -lamalg main.lua

Multiple calls will add to this module cache. But don't access it from
multiple concurrent processes!

You can use the cache (in addition to all module names given on the
commandline) using the `-c` flag.

    ./amalg.lua -o out.lua -s main.lua -c

However, this will only embed the Lua modules. To also embed C modules
(both from the cache and from the command line), you have to specify
the `-x` flag:

    ./amalg.lua -o out.lua -s main.lua -c -x

This will make the amalgamated script platform-dependent, obviously!

In some cases you may want to ignore automatically listed modules in
the cache without editing the cache file. Use the `-i` option for that
and specify a Lua pattern:

    ./amalg.lua -o out.lua -s main.lua -c -i "^luarocks%."

The `-i` option can be used multiple times to specify multiple
patterns.

To fix a compatibility issue with Lua 5.1's vararg handling,
`amalg.lua` by default adds a local alias to the global `arg` table to
every loaded module. If for some reason you don't want that, use the
`-a` flag (but be aware that in Lua 5.1 with `LUA_COMPAT_VARARG`
defined (the default) your modules can only access the global `arg`
table as `_G.arg`).

    ./amalg.lua -o out.lua -a -s main.lua -c

That's it. For further info consult the source (there's a nice
[annotated HTML file][6] rendered with [Docco][7] on the GitHub
pages). Have fun!

  [6]: http://siffiejoe.github.io/lua-amalg/
  [7]: http://jashkenas.github.io/docco/


##                              Contact                             ##

Philipp Janda, siffiejoe(a)gmx.net

Comments and feedback are always welcome.


##                              License                             ##

`amalg` is *copyrighted free software* distributed under the MIT
license (the same license as Lua 5.1). The full license text follows:

    amalg (c) 2013-2016 Philipp Janda

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHOR OR COPYRIGHT HOLDER BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

