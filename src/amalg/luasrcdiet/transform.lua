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
  return is_text and luasrcdiet.optimize( options, s ) or s, is_text
end

