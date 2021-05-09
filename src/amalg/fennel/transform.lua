local fennel = require( "fennel" )

local patterns = {}
for pattern in package.path:gmatch( "[^;]+" ) do
  if pattern:match( "%.lua$" ) then
    patterns[ #patterns+1 ] = pattern:gsub( "lua$", "fnl" )
  end
end
patterns[ #patterns+1 ] = package.path
package.path = table.concat( patterns, ";" ) -- luacheck: ignore package

local options = {
  allowedGlobals = false,
  correlate = true,
}

return function( s, is_text, path )
  if is_text and path:match( "%.fnl$" ) then
    return fennel.compileString( s, options ), true
  else
    return s, is_text
  end
end

