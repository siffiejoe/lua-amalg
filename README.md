# Amalgamation of Lua Scripts for Redis

![Build Status](https://travis-ci.org/BixData/lua-amalg-redis.svg?branch=master)
[![License](http://img.shields.io/badge/Licence-MIT-blue.svg)](LICENSE)
[![Lua](https://img.shields.io/badge/Lua-5.1%20|%205.2%20|%205.3%20|%20JIT%202.0%20|%20JIT%202.1%20-blue.svg)]()

This is a fork of [siffiejoe/lua-amalg](https://github.com/siffiejoe/lua-amalg/blob/master/README.md) that is specific to performing Lua script amalgamation for scripts targeting Redis.

The Lua runtime in Redis doesn't support some of the optional Lua modules that are common to an operating system based Lua VM, and lua-amalg makes a few too many assumptions in that regard, causing it to generate amalgamated scripts that won't run in Redis.

## Differences with lua-amalg

* Support for C modules is dropped
* The vararg handling fix and `-a` CLI flag for 5.0 interop is dropped

## Installing

	$ luarocks install amalg-redis

## Getting Started

You can bundle a collection of modules in a single file by calling the
`amalg.lua` script and passing the module names on the commandline.

	$ amalg-redis.lua module1 module2

The modules are collected using `package.path`, so they have to be
available there. The resulting merged Lua code will be written to the
standard output stream. You have to run the code to make the embedded
Lua modules available for `require`.

You can specify an output file to use instead of the standard output
stream.

	$ amalg-redis.lua -o out.lua module1 module2

You can also embed the main script of your application in the merged
Lua code as well. Of course the embedded Lua modules can be
`require`'d in the main script.

	$ amalg-redis.lua -o out.lua -s main.lua module1 module2

If you want the original file names and line numbers to appear in
error messages, you have to activate debug mode. This will require
slightly more memory, however.

	$ amalg-redis.lua -o out.lua -d -s main.lua module1 module2

To collect all Lua (and C) modules used by a program, you can load the
`amalg.lua` script as a module, and it will intercept calls to
`require` and save the necessary Lua module names in a file
`amalg.cache` in the current directory.

	$ lua -lamalg-redis main.lua

Multiple calls will add to this module cache. But don't access it from
multiple concurrent processes!

You can use the cache (in addition to all module names given on the
commandline) using the `-c` flag.

	$ amalg-redis.lua -o out.lua -s main.lua -c

In some cases you may want to ignore automatically listed modules in
the cache without editing the cache file. Use the `-i` option for that
and specify a Lua pattern:

	$ amalg-redis.lua -o out.lua -s main.lua -c -i "^luarocks%."

The `-i` option can be used multiple times to specify multiple
patterns.

Usually, the amalgamated modules take precedence over locally
installed (possibly newer) versions of the same modules. If you want
to use local modules when available and only fall back to the
amalgamated code otherwise, you can specify the `-f` flag.

	$ amalg-redis.lua -o out.lua -s main.lua -c -f

This installs another searcher/loader function at the end of the
`package.searchers` (or `package.loaders` on Lua 5.1) and adds a new
table `package.postload` that serves the same purpose as the standard
`package.preload` table.
