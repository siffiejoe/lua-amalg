return function( s, is_text, path )
  assert( is_text, "amalg.luac.deflate requires Lua code as input" )
  local chunk = assert( (loadstring or load)( s, '@' .. path ) )
  return string.dump( chunk, true ), false
end

