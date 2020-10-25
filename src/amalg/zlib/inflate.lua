local zlib_ok, zlib = pcall( require, "zlib" )
if zlib_ok and zlib.decompress then -- lzlib interface
  return function( s )
    return (zlib.decompress( s ))
  end
end

if zlib_ok and not zlib.decompress then -- lua-zlib interface
  return function( s )
    return (zlib.inflate()( s ))
  end
end


local ezlib_ok, ezlib = pcall( require, "ezlib" )
if ezlib_ok then
  return function( s )
    return (ezlib.inflate( s ))
  end
end


local libdeflate_ok, libdeflate = pcall( require, "LibDeflate" )
if libdeflate_ok then
  return function( s )
    return (libdeflate:DecompressDeflate( s ))
  end
end


-- TODO: implement self-contained pure-lua version that is portable to all Lua 5.x versions
error( "no zlib module installed (none of lua-zlib, lzlib, lua-ezlib, libdeflate)\n  "..zlib.. "\n  "..ezlib.."\n  "..libdeflate )

