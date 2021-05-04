local module1 = require( "module1" )
local module2 = require( "module2" )
local module3 = require( "cmod" )
local module4 = require( "aiomod.a" )
local module5 = require( "aiomod.b" )

local function sub( a : number, b : number ) : number
  return a - b
end

assert( sub( 3, 1 ) == 2 )
assert( module1.func() == "module1" )
assert( module2.func() == "module2" )
assert( module1.func2() == "module2" )
assert( module3.func() == "cmodule" )
assert( module4.func() == "aiomodule1" )
assert( module5.func() == "aiomodule2" )

print( "ok" )

