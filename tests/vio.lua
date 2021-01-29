#!/usr/bin/lua

local contents = [[
hello world
hello world
+1 -2.5 0xdeadbeef 1.5e1 1e1
12345678
]]

local file = assert( io.open( "data.txt", "r" ) )

assert( "hello world" == file:read( "*l" ) )
assert( "hello world\n" == file:read( "*L" ) )
assert( 1 == file:read( "*n" ) )
assert( -2.5 == file:read( "*n" ) )
assert( 3735928559 == file:read( "*n" ) )
assert( 15 == file:read( "*n" ) )
assert( 10 == file:read( "*n" ) )
assert( 0 == file:seek( "set" ) )
assert( contents == file:read( "*a" ) )
assert( 0 == file:seek( "set" ) )
local a, b, c, d, e, f, g = file:read( "l", "L", "n", "n", "n", "n", "n" )
assert( a == "hello world" )
assert( b == "hello world\n" )
assert( c == 1 )
assert( d == -2.5 )
assert( e == 3735928559 )
assert( f == 15 )
assert( g == 10 )
assert( 0 == file:seek( "set" ) )
local looped = false
for a, b, c, d, e, f, g in file:lines( "l", "L", "n", "n", "n", "n", "n" ) do
  assert( a == "hello world" )
  assert( b == "hello world\n" )
  assert( c == 1 )
  assert( d == -2.5 )
  assert( e == 3735928559 )
  assert( f == 15 )
  assert( g == 10 )
  looped = true
  break
end
assert( looped )
looped = false
for a, b, c, d, e, f, g in io.lines( "data.txt", "l", "L", "n", "n", "n", "n", "n" ) do
  assert( a == "hello world" )
  assert( b == "hello world\n" )
  assert( c == 1 )
  assert( d == -2.5 )
  assert( e == 3735928559 )
  assert( f == 15 )
  assert( g == 10 )
  looped = true
  break
end
assert( looped )
assert( #contents == file:seek( "end" ) )

assert( dofile( "vscript.lua" ) == 123 )
assert( loadfile( "vscript.lua" )() == 123 )

print( "ok" )

