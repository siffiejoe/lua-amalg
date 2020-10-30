local assert = assert -- cached for efficiency reasons
local errormsg = "brieflz decompression error"

local MAX = 32

local function compact( buffer, n, max )
  if n > (max or 1) then
    buffer[ 1 ], n = table.concat( buffer, "", 1, n ), 1
  end
  return buffer, n
end

local function append( buffer, n, s )
  n = n + 1
  buffer[ n ] = s
  return compact( buffer, n, MAX )
end

local function getbit( s, index, tag, bits )
  if bits == 0 then
    local byte0, byte1 = s:byte(index, index + 1)
    assert( byte1, errormsg )
    tag, bits = byte1 * 256 + byte0, 16
    index = index + 2
  end
  local bit = tag > 32767 and 1 or 0
  return bit, index, 2 * tag - 65536 * bit, bits - 1
end

local function getgamma( s, index, tag, bits )
  local v, bit = 1, nil
  repeat
    bit, index, tag, bits = getbit( s, index, tag, bits )
    assert( v < 2147483648, errormsg )
    v = v * 2 + bit
    bit, index, tag, bits = getbit( s, index, tag, bits )
  until bit == 0
  return v, index, tag, bits
end

return function( s )
  local index, tag, bits, bit =  1, 0, 1, nil
  local buffer, n = { "" }, 1
  while index <= #s do
    bit, index, tag, bits = getbit( s, index, tag, bits )
    if bit > 0 then
      local len, off
      len, index, tag, bits = getgamma( s, index, tag, bits )
      off, index, tag, bits = getgamma( s, index, tag, bits )
      len, off = len + 2, off - 2
      assert( off < 16777216 and index <= #s, errormsg )
      off, index = 256 * off + s:byte( index, index ) + 1, index + 1
      if off > #buffer[n] then buffer, n = compact( buffer, n ) end
      assert( off <= #buffer[ n ], errormsg )
      while len > 0 do -- copy match
        local c = buffer[ n ]:sub( -off, #buffer[ n ]-off+len )
        buffer, n = append( buffer, n, c )
        len, off = len - #c, #c
      end
    else -- copy literal
      assert( index <= #s, errormsg )
      index, buffer, n = index + 1, append( buffer, n, s:sub( index, index ) )
    end
  end
  return table.concat( buffer, "", 1, n )
end

