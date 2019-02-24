#!/usr/bin/env lua

local prog = "amalg.lua"
local cache = "amalg.cache"


local function indent(str, indentBy)
  local lines = {}
  for s in str:gmatch("[^\r\n]+") do
    local line = ''
    for i=1,indentBy*2 do
      line = line .. ' '
    end
    line = line .. s
    lines[#lines+1] = line
  end
  return table.concat(lines, '\n')
end


-- Wrong use of the command line may cause warnings to be printed to
-- the console. This function is for printing those warnings:
local function warn( ... )
  io.stderr:write( "WARNING ", prog, ": " )
  local n = select( '#', ... )
  for i = 1, n do
    local v = tostring( (select( i, ... )) )
    io.stderr:write( v, i == n and '\n' or '\t' )
  end
end


-- Function for parsing the command line of `amalg.lua` when invoked
-- as a script. The following flags are supported:
--
-- *   `-o <file>`: specify output file (default is `stdout`)
-- *   `-s <file>`: specify main script to bundle
-- *   `-c`: add the modules listed in the cache file `amalg.cache`
-- *   `-i <pattern>`: ignore modules in the cache file matching the
--     given pattern (can be given multiple times)
-- *   `-d`: enable debug mode (file names and line numbers in error
--     messages will point to the original location)
-- *   `--`: stop parsing command line flags (all remaining arguments
--     are considered module names)
--
-- Other arguments are assumed to be module names. For an inconsistent
-- command line (e.g. duplicate options) a warning is printed to the
-- console.
local function parse_cmdline( ... )
  local modules, ignores, tname, use_cache, dbg, script, oname =
        {}, {}, "preload"

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

  local function add_ignore( v )
    if v then
      if not pcall( string.match, "", v ) then
        warn( "Invalid Lua pattern: `"..v.."'" )
      else
        ignores[ #ignores+1 ] = v
      end
    else
      warn( "Missing argument for -i option!" )
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
    elseif a == "-i" then
      i = i + 1
      add_ignore( i <= n and select( i, ... ) )
    elseif a == "-f" then
      tname = "postload"
    elseif a == "-c" then
      use_cache = true
    elseif a == "-d" then
      dbg = true
    else
      local prefix = a:sub( 1, 2 )
      if prefix == "-o" then
        set_oname( a:sub( 3 ) )
      elseif prefix == "-s" then
        set_script( a:sub( 3 ) )
      elseif prefix == "-i" then
        add_ignore( a:sub( 3 ) )
      elseif a:sub( 1, 1 ) == "-" then
        warn( "Unknown command line flag: "..a )
      else
        modules[ a ] = true
      end
    end
    i = i + 1
  end
  return oname, script, dbg, use_cache, tname, ignores, modules
end


-- The approach for embedding precompiled Lua files is different from
-- the normal way of pasting the source code, so this function detects
-- whether a file is a binary file (Lua bytecode starts with the `ESC`
-- character):
local function is_bytecode( path )
  local f, res = io.open( path, "rb" ), false
  if f then
    res = f:read( 1 ) == "\027"
    f:close()
  end
  return res
end


-- Read the whole contents of a file into memory without any
-- processing.
local function readfile( path, is_bin )
  local f = assert( io.open( path, is_bin and "rb" or "r" ) )
  local s = assert( f:read( "*a" ) )
  f:close()
  return s
end


-- Lua files to be embedded into the resulting amalgamation are read
-- into memory in a single go, because under some circumstances (e.g.
-- binary chunks, shebang lines, `-d` command line flag) some
-- preprocessing/escaping is necessary. This function reads a whole
-- Lua file and returns the contents as a Lua string.
local function readluafile( path )
  local is_bin = is_bytecode( path )
  local s = readfile( path, is_bin )
  local shebang
  if not is_bin then
    -- Shebang lines are only supported by Lua at the very beginning
    -- of a source file, so they have to be removed before the source
    -- code can be embedded in the output.
    shebang = s:match( "^(#![^\n]*)" )
    s = s:gsub( "^#[^\n]*", "" )
  end
  return s, is_bin, shebang
end


-- Lua 5.1's `string.format("%q")` doesn't convert all control
-- characters to decimal escape sequences like the newer Lua versions
-- do. This might cause problems on some platforms (i.e. Windows) when
-- loading a Lua script (opened in text mode) that contains binary
-- code.
local function qformat( code )
  local s = ("%q"):format( code )
  return (s:gsub( "(%c)(%d?)", function( c, d )
    if c ~= "\n" then
      return (d~="" and "\\%03d" or "\\%d"):format( c:byte() )..d
    end
  end ))
end


-- When the `-c` command line flag is given, the contents of the cache
-- file `amalg.cache` are used to specify the modules to embed. This
-- function is used to load the cache file:
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


-- When loaded as a module, `amalg.lua` collects Lua modules and C
-- modules that are `require`d and updates the cache file
-- `amalg.cache`. This function saves the updated cache contents to
-- the file:
local function writecache( c )
  local f = assert( io.open( cache, "w" ) )
  f:write( "return {\n" )
  for k,v in pairs( c ) do
    if type( k ) == "string" and type( v ) == "string" then
      f:write( "  [ ", qformat( k ), " ] = ", qformat( v ), ",\n" )
    end
  end
  f:write( "}\n" )
  f:close()
end


-- The standard Lua function `package.searchpath` available in Lua 5.2
-- and up is used to locate the source files for Lua modules and
-- library files for C modules. For Lua 5.1 a backport is provided.
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


-- This is the main function for the use case where `amalg.lua` is run
-- as a script. It parses the command line, creates the output files,
-- collects the module and script sources, and writes the amalgamated
-- source.
local function amalgamate( ... )
  local oname, script, dbg, use_cache, tname, ignores, modules = parse_cmdline( ... )
  local errors = {}

  -- When instructed to on the command line, the cache file is loaded,
  -- and the modules are added to the ones listed on the command line
  -- unless they are ignored via the `-i` command line option.
  if use_cache then
    local c = readcache()
    for k,v in pairs( c or {} ) do
      local addmodule = true
      for _,p in ipairs( ignores ) do
        if k:match( p ) then
          addmodule = false
          break
        end
      end
      if addmodule then
        modules[ k ] = v
      end
    end
  end

  local out = io.stdout
  if oname then
    out = assert( io.open( oname, "w" ) )
  end

  out:write( [=[
-- Begin Redis support
local package = {
  loaded={
    ['cjson'] = cjson,
    ['cmsgpack'] = cmsgpack,
    ['math'] = math,
    ['redis.breakpoint'] = redis.breakpoint,
    ['redis.debug'] = redis.debug,
    ['redis.sha1hex'] = redis.sha1hex,
    ['string'] = string,
    ['struct'] = struct,
    ['table'] = table
  },
  preload={}
}
local function require(name)
  if package.loaded[name] == nil then
    local preloadFn = package.preload[name]
    if preloadFn == nil then
      error(string.format("module '%s' not found: no field package.preload['%s']", name, name))
    end
    package.loaded[name] = preloadFn()
  end
  return package.loaded[name]
end
local arg = ARGV
local io = nil
local os = nil
-- End Redis support


]=] )

  local script_bytes, script_binary
  if script then
    script_bytes, script_binary, _ = readluafile( script )
  end

  -- If fallback loading is requested, the module loaders of the
  -- amalgamated module are registered in table `package.postload`,
  -- and an extra searcher function is added at the end of
  -- `package.searchers`.
  if tname == "postload" then
    out:write([=[
do
  local assert = assert
  local type = assert( type )
  local searchers = package.searchers or package.loaders
  local postload = {}
  package.postload = postload
  searchers[ #searchers+1 ] = function( mod )
    assert( type( mod ) == "string", "module name must be a string" )
    local loader = postload[ mod ]
    if loader == nil then
      return "\n\tno field package.postload['"..mod.."']"
    else
      return loader
    end
  end
end

]=] )
  end

  -- Sort modules alphabetically. Modules will be embedded in
  -- alphabetical order. This ensures deterministic output.
  local module_names = {}
  for m in pairs( modules ) do
    module_names[ #module_names+1 ] = m
  end
  table.sort( module_names )

  -- Every module given on the command line and/or in the cache file
  -- is processed.
  for _,m in ipairs( module_names ) do
    local t = modules[ m ]
    -- Only Lua modules are handled for now, so modules that are
    -- definitely C modules are skipped and handled later.
    if t ~= "C" then
      local path, msg  = searchpath( m, package.path )
      if not path and (t == "L") then
        -- The module is supposed to be a Lua module, but it cannot
        -- be found, so an error is raised.
        error( "module `"..m.."' not found:"..msg )
      elseif not path then
        -- Module possibly is a C module, so it is tried again later.
        -- But the current error message is saved in case the given
        -- name isn't a C module either.
        modules[ m ], errors[ m ] = "C", msg
      else
        local bytes, is_bin = readluafile( path )
        if is_bin or dbg then
          -- Precompiled Lua modules are loaded via the standard Lua
          -- function `load` (or `loadstring` in Lua 5.1). Since this
          -- preserves file name and line number information, this
          -- approach is used for all files if the debug mode is active
          -- (`-d` command line option).
          out:write( "package.", tname, "[ ", qformat( m ),
                     " ] = assert( (loadstring or load)(\n",
                     qformat( bytes ), "\n, '@'..",
                     qformat( path ), " ) )\n\n" )
        else
          -- Under normal circumstances Lua files are pasted into a
          -- new anonymous vararg function, which then is put into
          -- `package.preload` so that `require` can find it.
          out:write( "package.", tname, "[", qformat( m ), "] = function(...)\n" )
          
          -- BEGIN module-specific hacks
          
          -- BEGIN HACK 1: https://github.com/Yonaba/Moses/issues/66
          if m == 'moses' then
            out:write("  local os = {}\n")
          end
          -- END HACK 1
          
          -- END module-specific hacks
          
          out:write(indent(bytes, 1), "\nend\n\n")
        end
      end
    end
  end

  -- If a main script is specified on the command line (`-s` flag),
  -- embed it now that all dependent modules are available to
  -- `require`.
  if script then
    out:write( "\n" )
    if script_binary or dbg then
      out:write( "assert( (loadstring or load)(\n",
                 qformat( script_bytes ), "\n, '@'..",
                 qformat( script ), " ) )( ... )\n\n" )
    else
      out:write( script_bytes )
    end
  end

  if oname then
    out:close()
  end
end


-- If `amalg.lua` is loaded as a module, it intercepts `require` calls
-- (more specifically calls to the searcher functions) to collect all
-- `require`d module names and store them in the cache. The cache file
-- `amalg.cache` is updated when the program terminates.
local function collect()
  local searchers = package.searchers or package.loaders
  -- When the searchers table has been modified, it is unknown which
  -- elements in the table to replace, so `amalg.lua` bails out with
  -- an error. The `luarocks.loader` module which inserts itself at
  -- position 1 in the `package.searchers` table is explicitly
  -- supported, though!
  local off = 0
  if package.loaded[ "luarocks.loader" ] then off = 1 end
  assert( #searchers == 4+off, "package.searchers has been modified" )
  local c = readcache() or {}
  -- The updated cache is written to disk when the following value is
  -- garbage collected, which should happen at `lua_close()`.
  local sentinel = newproxy and newproxy( true )
                            or setmetatable( {}, { __gc = true } )
  getmetatable( sentinel ).__gc = function() writecache( c ) end
  local lua_searcher = searchers[ 2+off ]
  local c_searcher = searchers[ 3+off ]
  local aio_searcher = searchers[ 4+off ] -- all in one searcher

  local function rv_handler( tag, mname, ... )
    if type( (...) ) == "function" then
      c[ mname ] = tag
    end
    return ...
  end

  -- The replacement searchers just forward to the original versions,
  -- but also update the cache if the search was successful.
  searchers[ 2+off ] = function( ... )
    local _ = sentinel -- make sure that sentinel is an upvalue
    return rv_handler( "L", ..., lua_searcher( ... ) )
  end
  searchers[ 3+off ] = function( ... )
    local _ = sentinel -- make sure that sentinel is an upvalue
    return rv_handler( "C", ..., c_searcher( ... ) )
  end
  searchers[ 4+off ] = function( ... )
    local _ = sentinel -- make sure that sentinel is an upvalue
    return rv_handler( "C", ..., aio_searcher( ... ) )
  end

  -- Since calling `os.exit` might skip the `lua_close()` call, the
  -- `os.exit` function is monkey-patched to also save the updated
  -- cache to the cache file on disk.
  if type( os ) == "table" and type( os.exit ) == "function" then
    local os_exit = os.exit
    function os.exit( ... )
      writecache( c )
      return os_exit( ... )
    end
  end
end


-- To determine whether `amalg.lua` is run as a script or loaded as a
-- module it uses the debug module to walk the call stack looking for
-- a `require` call. If such a call is found, `amalg.lua` has been
-- `require`d as a module.
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


-- This checks whether `amalg.lua` has been called as a script or
-- loaded as a module and acts accordingly, by calling the
-- corresponding main function:
if is_script() then
  amalgamate( ... )
else
  collect()
end
