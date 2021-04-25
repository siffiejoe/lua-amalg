local tl = require( "tl" )

local patterns = {}
for pattern in package.path:gmatch( "[^;]+" ) do
  if pattern:match( "%.lua$" ) then
    patterns[ #patterns+1 ] = pattern:gsub( "lua$", "tl" )
  end
end
patterns[ #patterns+1 ] = package.path
package.path = table.concat( patterns, ";" ) -- luacheck: ignore package

return function( s, is_text, path )
  if is_text and path:match( "%.tl$" ) then
    local code, result = tl.gen( s )
    if code then
      return code, true
    else
      if #result.syntax_errors > 0 then
        local err = result.syntax_errors[ 1 ]
        error( path..":"..err.y..":"..err.x..": "..err.msg )
      else
        error( path..": unknown error" )
      end
    end
  else
    return s, is_text
  end
end

