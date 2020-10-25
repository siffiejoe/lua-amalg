local zlib_ok, zlib = pcall( require, "zlib" )
if zlib_ok and zlib.compress then -- lzlib interface
  return function( s )
    return zlib.compress( s, 9 ), false
  end
end

if zlib_ok and not zlib.compress then -- lua-zlib interface
  return function( s )
    return zlib.deflate( 9 )( s, "finish" ), false
  end
end


local ezlib_ok, ezlib = pcall( require, "ezlib" )
if ezlib_ok then
  return function( s )
    return ezlib.deflate( s, "zlib", 9 ), false
  end
end


local libdeflate_ok, libdeflate = pcall( require, "LibDeflate" )
if libdeflate_ok then
  return function( s )
    return libdeflate:CompressDeflate( s )
  end
end


error( "no zlib module installed (none of lua-zlib, lzlib, lua-ezlib, libdeflate)\n  "..zlib.. "\n  "..ezlib.."\n  "..libdeflate )

