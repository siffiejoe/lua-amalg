local brieflz = require( "brieflz" )
return function( s )
  return brieflz.pack( s ), false
end

