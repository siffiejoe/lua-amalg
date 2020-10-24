local zlib_ok, zlib = pcall( require, "zlib" )
if zlib_ok and zlib.decompress then -- lzlib interface
  local decompress = zlib.decompress
  return function( s )
    return (decompress( s ))
  end
end

if zlib_ok and not zlib.decompress then -- lua-zlib interface
  local inflate = zlib.inflate
  return function( s )
    return (inflate()( s ))
  end
end


local ezlib_ok, ezlib = pcall( require, "ezlib" )
if ezlib_ok then
  local inflate = ezlib.inflate
  return function( s )
    return (inflate( s ))
  end
end


-- TODO: implement self-contained pure-lua version that is portable to all Lua 5.x versions
error( "no zlib module installed (none of lua-zlib, lzlib, ezlib)\n  " .. zlib .. "\n  " .. ezlib )

