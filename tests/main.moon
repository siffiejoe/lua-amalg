#!/usr/bin/env moon
module1 = require "module1"
module2 = require "module2"
module3 = require "cmod"
module4 = require "aiomod.a"
module5 = require "aiomod.b"

assert module1.func! == "module1"
assert module2.func! == "module2"
assert module1.func2! == "module2"
assert module3.func! == "cmodule"
assert module4.func! == "aiomodule1"
assert module5.func! == "aiomodule2"

print "ok"

