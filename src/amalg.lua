#!/usr/bin/env lua

-- **Amalg** is a Lua tool for bundling a Lua script and dependent
-- Lua modules in a single `.lua` file for easier distribution.
--
-- Features:
-- *   Pure Lua (compatible with Lua 5.1 and up), no external
--     dependencies. (Even works for modules using the deprecated
--     `module` function.)
-- *   You don't have to take care of the order in which the modules
--     are `require`d.
-- *   Can collect `require`d Lua modules automatically.
--
-- What it doesn't do:
--
-- *   It does not compile to bytecode. Use `luac` for that yourself,
--     or take a look at [squish][1], or [luac.lua][4].
-- *   It does not include C modules.
-- *   It doesn't do static analysis of Lua code to collect `require`d
--     modules. That won't work reliable anyway in a dynamic language!
--     You can write your own program for that (e.g. using the output
--     of `luac -p -l`), or use [squish][1], or [soar][3] instead.
-- *   It will not compress, minify, obfuscate your Lua source code,
--     or any of the other things [squish][1] can do.
--
-- The `amalg.lua` [source code][6] is available on GitHub, and is
-- released under the [MIT license][7]. You can view [a nice HTML
-- version][8] of this file rendered by [Docco][9] on the GitHub
-- pages.
--
-- As already mentioned, there are alternatives to this program: See
-- [squish][1], [LOOP][2], [soar][3], [luac.lua][4], and
-- [bundle.lua][5] (and probably some more).
--
--   [1]: http://matthewwild.co.uk/projects/squish/home
--   [2]: http://loop.luaforge.net/release/preload.html
--   [3]: http://lua-users.org/lists/lua-l/2012-02/msg00609.html
--   [4]: http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/5.1/luac.lua
--   [5]: https://github.com/akavel/scissors/blob/master/tools/bundle/bundle.lua
--   [6]: http://github.com/siffiejoe/lua-amalg
--   [7]: http://opensource.org/licenses/MIT
--   [8]: http://siffiejoe.github.io/lua-amalg/
--   [9]: http://jashkenas.github.io/docco/
--
--
-- ## Getting Started
--
-- You can bundle a collection of Lua modules in a single file by
-- calling the `amalg.lua` script and passing the module names on the
-- command line:
--
--     ./amalg.lua module1 module2
--
-- The modules are collected using `package.path`, so they have to be
-- available there. The resulting merged Lua code will be written to
-- the standard output stream. You have to actually run the resulting
-- code to make the embedded Lua modules available for `require`.
--
-- You can specify an output file to use instead of the standard
-- output stream:
--
--     ./amalg.lua -o out.lua module1 module2
--
-- You can also embed the main script of your application in the
-- merged Lua code as well. Of course, the embedded Lua modules can be
-- `require`d from the embedded main script.
--
--     ./amalg.lua -o out.lua -s main.lua module1 module2
--
-- If you want the original file names and line numbers to appear in
-- error messages, you have to activate debug mode. This will require
-- slightly more memory, though.
--
--     ./amalg.lua -o out.lua -d -s main.lua module1 module2
--
-- To collect all Lua modules used by a program, you can load the
-- `amalg.lua` script as a module, and it will intercept calls to
-- `require` (more specifically the Lua module searcher) and save the
-- necessary Lua module names in a file `amalg.cache` in the current
-- directory:
--
--     lua -lamalg main.lua
--
-- Multiple calls will add to this module cache. But don't access it
-- from multiple concurrent processes (the cache isn't protected
-- against race conditions)!
--
-- You can use the cache (in addition to all module names given on the
-- command line) using the `-c` flag:
--
--     ./amalg.lua -o out.lua -s main.lua -c
--
-- To fix a compatibility issue with Lua 5.1's vararg handling,
-- `amalg.lua` by default adds a local alias to the global `arg` table
-- to every loaded module. If for some reason you don't want that, use
-- the `-a` flag (but be aware that in Lua 5.1 with `LUA_COMPAT_VARARG`
-- defined (the default) your modules can only access the global `arg`
-- table as `_G.arg`).
--
--     ./amalg.lua -o out.lua -a -s main.lua -c
--
-- That's it. For further info consult the source.
--
--
-- ## Implementation
--

-- The name of the script used in warning messages and the name of the
-- cache file can be configured here by changing these local
-- variables:
local prog = "amalg.lua"
local cache = "amalg.cache"


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
-- *   `-d`: enable debug mode (file names and line numbers in error
--     messages will point to the original location)
-- *   `-a`: do *not* apply the `arg` fix (local alias for the global
--     `arg` table)
-- *   `--`: stop parsing command line flags (all remaining arguments
--     are considered module names)
--
-- Other arguments are assumed to be module names. For an inconsistent
-- command line (e.g. duplicate options) a warning is printed to the
-- console.
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
      elseif a:sub( 1, 1 ) == "-" then
        warn( "Unknown command line flag: "..a )
      else
        modules[ a ] = true
      end
    end
    i = i + 1
  end
  return oname, script, dbg, afix, use_cache, modules
end


-- The approach for embedding precompiled Lua files is different from
-- the normal way of pasting the source code, so this function detects
-- whether a file is a binary file (Lua bytecode starts with the `ESC`
-- character):
local function is_binary( path )
  local f, res = io.open( path, "rb" ), false
  if f then
    res = f:read( 1 ) == "\027"
    f:close()
  end
  return res
end


-- Files to be embedded into the resulting amalgamation are read into
-- memory in a single go, because under some circumstances (e.g.
-- binary chunks, shebang lines, `-d` command line flag) some
-- preprocessing/escaping is necessary. This function reads a whole
-- Lua file and returns the contents as a Lua string.
local function readluafile( path )
  local is_bin = is_binary( path )
  local f = assert( io.open( path, is_bin and "rb" or "r" ) )
  local s = assert( f:read( "*a" ) )
  f:close()
  if not is_bin then
    -- Shebang lines are only supported by Lua at the very beginning
    -- of a source file, so they have to be removed before the source
    -- code can be embedded in the output.
    s = s:gsub( "^#[^\n]*", "" )
  end
  return s, is_bin
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


-- When loaded as a module, `amalg.lua` collects Lua modules that are
-- `require`d and updates the cache file `amalg.cache`. This function
-- saves the updated cache contents to the file:
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


-- The standard Lua function `package.searchpath` available in Lua 5.2
-- and up is used to locate the source files for Lua modules. For Lua
-- 5.1 a backport is provided.
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
  local oname, script, dbg, afix, use_cache, modules = parse_cmdline( ... )

  -- When instructed to on the command line, the cache file is loaded,
  -- and the modules are added to the ones listed on the command line.
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

  -- If a main script is to be embedded, this includes a shebang line
  -- so that the resulting amalgamation can be run without explicitly
  -- specifying the interpreter on unixoid systems.
  if script then
    out:write( "#!/usr/bin/env lua\n\ndo\n\n" )
  end

  -- Every module given on the command line and/or in the cache file
  -- is processed.
  for m in pairs( modules ) do
    local path, msg  = searchpath( m, package.path )
    if not path then
      error( "module `"..m.."' not found:"..msg )
    end
    local bytes, is_bin = readluafile( path )
    if is_bin or dbg then
      -- Precompiled Lua modules are loaded via the standard Lua
      -- function `load` (or `loadstring` in Lua 5.1). Since this
      -- preserves file name and line number information, this
      -- approach is used for all files if the debug mode is active
      -- (`-d` command line option).
      out:write( "package.preload[ ", ("%q"):format( m ),
                 " ] = assert( (loadstring or load)(\n",
                 ("%q"):format( bytes ), "\n, '@'..",
                 ("%q"):format( path ), " ) )\n\n" )
    else
      -- Under normal circumstances Lua files are pasted into a
      -- new anonymous vararg function, which then is put into
      -- `package.preload` so that `require` can find it. Each
      -- function gets its own `_ENV` upvalue (on Lua 5.2+), and
      -- special care is taken that `_ENV` always is the first
      -- upvalue (important for the `module` function on Lua 5.2).
      -- Lua 5.1 compiled with `LUA_COMPAT_VARARG` (the default) will
      -- create a local `arg` variable to emulate the vararg handling
      -- of Lua 5.0. This might interfere with Lua modules that access
      -- command line arguments via the `arg` global. As a workaround
      -- `amalg.lua` adds a local alias to the global `arg` table
      -- unless the `-a` command line flag is specified.
      out:write( "local _ENV = _ENV\n",
                 "package.preload[ ", ("%q"):format( m ),
                 " ] = function( ... ) ",
                 afix and "local arg = _G.arg;\n" or "_ENV = _ENV;\n",
                 bytes, "\nend\n\n" )
    end
  end

  -- If a main script is specified on the command line (`-s` flag),
  -- embed it now that all dependent modules are available to
  -- `require`.
  if script then
    out:write( "end\n\n" )
    local bytes, is_bin = readluafile( script )
    if is_bin or dbg then
      out:write( "assert( (loadstring or load)(\n",
                 ("%q"):format( bytes ), "\n, '@'..",
                 ("%q"):format( script ), " ) )( ... )\n\n" )
    else
      out:write( bytes )
    end
  end

  if oname then
    out:close()
  end
end


-- If `amalg.lua` is loaded as a module, it intercepts `require` calls
-- (more specifically calls to the Lua searcher) to collect all
-- `require`d module names and store them in the cache. The cache file
-- `amalg.cache` is updated when the program terminates.
local function collect()
  local searchers = package.searchers or package.loaders
  -- When the searchers table has been modified, it is unknown which
  -- element in the table the Lua searcher is, so `amalg.lua` bails
  -- out with an error.
  assert( #searchers == 4, "package.searchers has been modified" )
  local c = readcache() or {}
  -- The updated cache is written to disk when the following value is
  -- garbage collected, which should happen at `lua_close()`.
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

  -- The replacement searcher just forwards to the original version,
  -- but also updates the cache if the search was successful.
  searchers[ 2 ] = function( ... )
    local _ = sentinel -- make sure that sentinel is an upvalue
    return rv_handler( ..., lua_searcher( ... ) )
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


-- Check whether `amalg.lua` has been called as a script or loaded as
-- a module and act accordingly:
if is_script() then
  amalgamate( ... )
else
  collect()
end

