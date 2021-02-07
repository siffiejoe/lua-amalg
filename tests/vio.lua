#!/usr/bin/lua

local contents = [[
hello world
hello world
+1 -2.5 0xdeadbeef 1.5e1 1e1
12345678
]]

local file = assert( io.open( "data.txt", "r" ) )

assert( "hello " == file:read( 6 ) )
assert( "world" == file:read( "*l" ) )
assert( "hello world\n" == file:read( "*L" ) )
assert( 1 == file:read( "*n" ) )
assert( -2.5 == file:read( "*n" ) )
assert( 3735928559 == file:read( "*n" ) )
assert( 15 == file:read( "*n" ) )
assert( 10 == file:read( "*n" ) )
assert( 0 == file:seek( "set" ) )
assert( contents == file:read( "*a" ) )
assert( 0 == file:seek( "set" ) )
local function checkvalues( a, b, c, d, e, f, g, h )
  assert( a == "hello " )
  assert( b == "world" )
  assert( c == "hello world\n" )
  assert( d == 1 )
  assert( e == -2.5 )
  assert( f == 3735928559 )
  assert( g == 15 )
  assert( h == 10 )
  return true
end
local a1, b1, c1, d1, e1, f1, g1, h1 = file:read( 6, "l", "L", "n", "n", "n", "n", "n" )
checkvalues( a1, b1, c1, d1, e1, f1, g1, h1 )
assert( 0 == file:seek( "set" ) )
local looped = false
for a2, b2, c2, d2, e2, f2, g2, h2 in file:lines( 6, "l", "L", "n", "n", "n", "n", "n" ) do
  if checkvalues( a2, b2, c2, d2, e2, f2, g2, h2 ) then
    looped = true
    break
  end
end
assert( looped )
looped = false
for a2, b2, c2, d2, e2, f2, g2, h2 in io.lines( "data.txt", 6, "l", "L", "n", "n", "n", "n", "n" ) do
  if checkvalues( a2, b2, c2, d2, e2, f2, g2, h2 ) then
    looped = true
    break
  end
end
assert( looped )
assert( #contents == file:seek( "end" ) )

assert( dofile( "vscript.lua" ) == 123 )
assert( loadfile( "vscript.lua" )() == 123 )

print( "ok" )

