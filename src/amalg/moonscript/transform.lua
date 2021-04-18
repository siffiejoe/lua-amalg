local moonscript = require( "moonscript.base" )
return function( s, is_text, path )
  if is_text and path:match( "%.moon$" ) then
    return assert( moonscript.to_lua( s ) ), true
  else
    return s, is_text
  end
end

