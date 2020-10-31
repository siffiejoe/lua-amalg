return function( s, is_text, path )
  if is_text then
    local chunk = assert( (loadstring or load)( s, '@' .. path ) )
    return string.dump( chunk, true ), false
  else
    return s, false
  end
end

