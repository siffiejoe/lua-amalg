local parser = require( "dumbParser" )

return function( s, is_text, path )
  if is_text then
    local tokens = assert( parser.tokenize( s, path ) )
    local ast = assert( parser.parse( tokens ) )
    parser.minify( ast, true )
    return assert( parser.toLua( ast ) ), true
  else
    return s, false
  end
end

