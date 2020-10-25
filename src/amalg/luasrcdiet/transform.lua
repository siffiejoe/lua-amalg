local luasrcdiet = require( "luasrcdiet" )
local options = {
  comments = true,
  emptylines = true,
  whitespace = true,
  locals = true,
  numbers = true,
  --[[
  entropy = true,
  eols = true,
  strings = true,
  --]]
}

return function( s, is_text )
  assert( is_text, "amalg.luasrcdiet.deflate requires Lua code as input" )
  return luasrcdiet.optimize( options, s ), true
end

