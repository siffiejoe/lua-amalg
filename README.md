#            Amalg -- Amalgamation of Lua Modules/Scripts            #

[![Test Status](https://github.com/siffiejoe/lua-amalg/workflows/run-tests/badge.svg)](https://github.com/siffiejoe/lua-amalg/actions?workflow=run-tests)
[![Linter Status](https://github.com/siffiejoe/lua-amalg/workflows/run-linters/badge.svg)](https://github.com/siffiejoe/lua-amalg/actions?workflow=run-linters)


##                           Introduction                           ##

Deploying a Lua application that is split among multiple modules is a
challenge. A tool that can package a Lua script and its modules into
a single file is a valuable help. This is such a tool.

Features:

*   Pure Lua (compatible with Lua 5.1 and up), no other external
    dependencies.
*   Even works for modules using the deprecated `module` function.
*   You don't have to take care of the order in which the modules are
    `require`'d.
*   Can embed compiled C modules.
*   Can collect `require`'d Lua (and C) modules automatically.
*   Can compress/decompress or precompile using plugin modules.
    (Plugin modules may have dependencies to external Lua modules!)

What it doesn't do:

*   It doesn't do static analysis of Lua code to collect `require`'d
    modules. That won't work reliably anyway. You can write your own
    program for that (using the output of `luac -p -l`), or use
    [squish][1], or [soar][3] instead.
*   It doesn't handle the dependencies of C modules, so it is best
    used on C modules without dependencies (e.g. LuaSocket, LFS,
    etc.).

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

To use a custom file as cache specify `-C <file>`:

    ./amalg.lua -o out.lua -s main.lua -C myamalg.cache

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

Usually, the amalgamated modules take precedence over locally
installed (possibly newer) versions of the same modules. If you want
to use local modules when available and only fall back to the
amalgamated code otherwise, you can specify the `-f` flag.

    ./amalg.lua -o out.lua -s main.lua -c -f

This installs another searcher/loader function at the end of the
`package.searchers` (or `package.loaders` on Lua 5.1) and adds a new
table `package.postload` that serves the same purpose as the standard
`package.preload` table.

To fix a compatibility issue with Lua 5.1's vararg handling,
`amalg.lua` by default adds a local alias to the global `arg` table to
every loaded module. If for some reason you don't want that, use the
`-a` flag (but be aware that in Lua 5.1 with `LUA_COMPAT_VARARG`
defined (the default) your modules can only access the global `arg`
table as `_G.arg`).

    ./amalg.lua -o out.lua -a -s main.lua -c

There is also some compression/decompression support handled via
plugins to amalg. To select a transformation us the `-z` option.
Multiple compression/transformation steps are possible, and they are
executed in the given order. The necessary decompression code is
embedded in the result and executed automatically.

    ./amalg.lua -o out.lua -s main.lua -c -z luac -z brieflz

Some plugin generate valid Lua code (text or binary) and thus don't
need a decompression step. For those modules the `-t` option should be
used instead to avoid embedding no-op decompression code in the final
amalgamation file.

    ./amalg.lua -o out.lua -s main.lua -c -t luasrcdiet -t luac -z brieflz

Note that compression is usually most effective when applied to the
complete amalgamation script instead of just individual modules:

    ./amalg.lua -s main.lua -c | ./amalg.lua -o out.lua -s- -t luasrcdiet -z brieflz

That's it. For further info consult the source (there's a nice
[annotated HTML file][6] rendered with [Docco][7] on the GitHub
pages). Have fun!

  [6]: http://siffiejoe.github.io/lua-amalg/
  [7]: http://jashkenas.github.io/docco/


##                              Plugins                             ##

`amalg.lua` uses two kinds of plugins: transformation plugins and
compression plugins. Transformation plugins are Lua modules that are
called only during amalgamation. Compression plugins consist of two
separate Lua modules that are called during amalgamation and at
runtime to undo the modifications made during amalgamation,
respectively. Since transformation plugins don't have a reverse
transformation step, they are expected to produce valid Lua code (or
Lua binary code). They are used only on pure Lua files (modules or
main script). Compression plugins on the other hand are used on both
Lua files and compiled C modules.

A transformation plugin (used with the command line option `-t
<name>`) is implemented as a Lua module `amalg.<name>.transform`. The
module exports a function that takes a string (the input source), a
boolean (whether the input source is in Lua source code format), and
the original file path as arguments. It must return a string (the
transformed input) and a boolean indicating whether the result is Lua
source code. It is good practice to handle the case where the input is
not in Lua source code format (but Lua binary code) by skipping the
transformation in this case.

A compression plugin (used with the command line option `-z <name>`)
is implemented as two separate Lua modules `amalg.<name>.deflate` and
`amalg.<name>.inflate`. The deflate part of the plugin works exactly
like a transformation plugin module. It is called during amalgamation
and may freely use external dependencies. The inflate module should be
implemented as a self-contained pure Lua module as it is embedded into
the amalgamation for the decompression step during runtime. This
module exports a function taking the compressed input as a string and
returning the decompressed output as string as well.

There are currently three predefined plugins available:

###                           luac Plugin                          ###

The `luac` plugin is a transformation plugin that compiles Lua source
code into stripped Lua binary code. It doesn't have any external
dependencies and passes through binary input (i.e. already compiled
Lua code) unmodified. Note that binary Lua code may be larger than Lua
source code, especially when encoded in Lua's decimal escape notation.
Binary Lua code is also platform dependent. It may or may not load
faster than regular Lua source code.

###                        luasrcdiet Plugin                       ###

The `luasrcdiet` plugin is a transformation plugin that minifies Lua
source code by replacing names of local variables, stripping white
space, removing comments, etc. It passes through binary input (i.e.
already compiled Lua code) unmodified. You need to install the
[luasrcdiet][8] module for the amalgamation step. The amalgamated
script doesn't have any extra dependencies. This transformation is a
good choice for reducing the size of the resulting amalgamated Lua
script.

  [8]: https://luarocks.org/modules/jirutka/luasrcdiet

###                         brieflz Plugin                         ###

The `brieflz` plugin is a compression plugin that compresses its input
during amalgamation and decompresses it on the fly during runtime. The
compression step relies on the [brieflz][9] module which must be
installed during amalgamation. The decompression step is performed by
a pure Lua port of the `blz_depack_safe` function from the
[original C code][10] by Jørgen Ibsen (@jibsen). The decompression
code is embedded into the resulting amalgamation script, so no extra
dependency is needed at runtime, but it adds about 2kB (1kB when
minified with `luasrcdiet`) size overhead. Note that binary data in
the amalgamation is stored in standard Lua decimal escape notation, so
it may be larger than usual. However, brieflz compression still
reduces the size of the resulting amalgamation script in many cases.

  [9]: https://luarocks.org/modules/jirutka/brieflz
  [10]: https://github.com/jibsen/brieflz


##                              Contact                             ##

Philipp Janda, siffiejoe(a)gmx.net

Comments and feedback are always welcome.


##                              License                             ##

`amalg` is *copyrighted free software* distributed under the MIT
license (the same license as Lua 5.1). The full license text follows:

    amalg (c) 2013-2020 Philipp Janda

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

