#!/usr/bin/env lua

local prog = "amalg.lua"
local cache = "amalg.cache"


local function warn( ... )
  io.stderr:write( "WARNING ", prog, ": " )
  local n = select( '#', ... )
  for i = 1, n do
    local v = tostring( (select( i, ... )) )
    io.stderr:write( v, i == n and '\n' or '\t' )
  end
end


local function parse_cmdline( ... )
  local modules, afix, use_cache, dbg, script, oname = {}, true

  local function set_oname( v )
    if v then
      if oname then
        warn( "Resetting output file `"..oname.."'! Using `"..v.."' now!" )
      end
      oname = v
    else
      warn( "Missing argument for -o option!" )
    end
  end

  local function set_script( v )
    if v then
      if script then
        warn( "Resetting main script `"..script.."'! Using `"..v.."' now!" )
      end
      script = v
    else
      warn( "Missing argument for -s option!" )
    end
  end

  local i, n = 1, select( '#', ... )
  while i <= n do
    local a = select( i, ... )
    if a == "--" then
      for j = i+1, n do
        modules[ select( j, ... ) ] = true
      end
      break
    elseif a == "-o" then
      i = i + 1
      set_oname( i <= n and select( i, ... ) )
    elseif a == "-s" then
      i = i + 1
      set_script( i <= n and select( i, ... ) )
    elseif a == "-c" then
      use_cache = true
    elseif a == "-d" then
      dbg = true
    elseif a == "-a" then
      afix = false
    else
      local prefix = a:sub( 1, 2 )
      if prefix == "-o" then
        set_oname( a:sub( 3 ) )
      elseif prefix == "-s" then
        set_script( a:sub( 3 ) )
      else
        modules[ a ] = true
      end
    end
    i = i + 1
  end
  return oname, script, dbg, afix, use_cache, modules
end


local function is_binary( path )
  local f, res = io.open( path, "rb" ), false
  if f then
    res = f:read( 1 ) == "\027"
    f:close()
  end
  return res
end


local function readfile( path )
  local is_bin = is_binary( path )
  local f = assert( io.open( path, is_bin and "rb" or "r" ) )
  local s = assert( f:read( "*a" ) )
  f:close()
  if not is_bin then
    s = s:gsub( "^#[^\n]*", "" )
  end
  return s, is_bin
end


local function readcache()
  local chunk = loadfile( cache, "t", {} )
  if chunk then
    if setfenv then setfenv( chunk, {} ) end
    local result = chunk()
    if type( result ) == "table" then
      return result
    end
  end
end


local function writecache( c )
  local f = assert( io.open( cache, "w" ) )
  f:write( "return {\n" )
  for k,v in pairs( c ) do
    if v and type( k ) == "string" then
      f:write( "  [ ", ("%q"):format( k ), " ] = true,\n" )
    end
  end
  f:write( "}\n" )
  f:close()
end


local searchpath = package.searchpath
if not searchpath then
  local delim = package.config:match( "^(.-)\n" ):gsub( "%%", "%%%%" )

  function searchpath( name, path )
    local pname = name:gsub( "%.", delim ):gsub( "%%", "%%%%" )
    local msg = {}
    for subpath in path:gmatch( "[^;]+" ) do
      local fpath = subpath:gsub( "%?", pname )
      local f = io.open( fpath, "r" )
      if f then
        f:close()
        return fpath
      end
      msg[ #msg+1 ] = "\n\tno file '"..fpath.."'"
    end
    return nil, table.concat( msg )
  end
end


local function amalgamate( ... )
  local oname, script, dbg, afix, use_cache, modules = parse_cmdline( ... )

  if use_cache then
    local c = readcache()
    for k in pairs( c or {} ) do
      modules[ k ] = true
    end
  end

  local out = io.stdout
  if oname then
    out = assert( io.open( oname, "w" ) )
  end

  if script then
    out:write( "#!/usr/bin/env lua\n\n" )
  end

  for m in pairs( modules ) do
    local path, msg  = searchpath( m, package.path )
    if not path then
      error( "module `"..m.."' not found:"..msg )
    end
    local bytes, is_bin = readfile( path )
    if is_bin or dbg then
      out:write( "package.preload[ ", ("%q"):format( m ),
                 " ] = assert( (loadstring or load)(\n",
                 ("%q"):format( bytes ), "\n, '@'..",
                 ("%q"):format( path ), " ) )\n\n" )
    else
      out:write( "local _ENV = _ENV\n",
                 "package.preload[ ", ("%q"):format( m ),
                 " ] = function( ... ) ",
                 afix and "local arg = _G.arg\n" or "_ENV = _ENV\n",
                 bytes, "\nend\n\n" )
    end
  end

  if script then
    local bytes, is_bin = readfile( script )
    if is_bin or dbg then
      out:write( "assert( (loadstring or load)(\n",
                 ("%q"):format( bytes ), "\n, '@'..",
                 ("%q"):format( script ), " ) )( ... )\n\n" )
    else
      out:write( "local _ENV = _ENV\ndo\n", bytes, "\nend\n\n" )
    end
  end

  if oname then
    out:close()
  end
end


local function collect()
  local searchers = package.searchers or package.loaders
  assert( #searchers == 4, "package.searchers has been modified" )
  local c = readcache() or {}
  local sentinel = newproxy and newproxy( true )
                            or setmetatable( {}, { __gc = true } )
  getmetatable( sentinel ).__gc = function() writecache( c ) end
  local lua_searcher = searchers[ 2 ]

  local function rv_handler( mname, ... )
    if type( (...) ) == "function" then
      c[ mname ] = true
    end
    return ...
  end

  searchers[ 2 ] = function( ... )
    local _ = sentinel -- make sure that sentinel is an upvalue
    return rv_handler( ..., lua_searcher( ... ) )
  end

  if type( os ) == "table" and type( os.exit ) == "function" then
    local os_exit = os.exit
    function os.exit( ... )
      writecache( c )
      return os_exit( ... )
    end
  end
end


local function is_script()
  local i = 3
  local info = debug.getinfo( i, "f" )
  while info do
    if info.func == require then
      return false
    end
    i = i + 1
    info = debug.getinfo( i, "f" )
  end
  return true
end


if is_script() then
  -- called as a script
  amalgamate( ... )
else
  -- loaded as a module
  collect()
end

