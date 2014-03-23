#!/usr/bin/env lua

local module1 = require( "module1" )
local module2 = require( "module2" )

assert( module1.func() == "module1" )
assert( module2.func() == "module2" )
assert( module1.func2() == "module2" )

print( "ok" )

