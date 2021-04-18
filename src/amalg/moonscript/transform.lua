local moonscript = require( "moonscript.base" )
local moonpath = moonscript.create_moonpath( package.path )
local delimiter = moonpath:match( ";$" ) and "" or ";"
package.path = moonpath..delimiter..package.path -- luacheck: ignore package

return function( s, is_text, path )
  if is_text and path:match( "%.moon$" ) then
    return assert( moonscript.to_lua( s ) ), true
  else
    return s, is_text
  end
end

