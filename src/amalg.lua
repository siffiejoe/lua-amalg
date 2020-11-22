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
-- *   Can embed compiled C modules.
-- *   Can collect `require`d Lua (and C) modules automatically.
-- *   Can compress/decompress or precompile using plugin modules.
--
-- What it doesn't do:
--
-- *   It doesn't do static analysis of Lua code to collect `require`d
--     modules. That won't work reliably anyway in a dynamic language!
--     You can write your own program for that (e.g. using the output
--     of `luac -p -l`), or use [squish][1], or [soar][3] instead.
-- *   It doesn't handle the dependencies of C modules, so it is best
--     used on C modules without dependencies (e.g. LuaSocket, LFS,
--     etc.).
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
-- To collect all Lua (and C) modules used by a program, you can load
-- the `amalg.lua` script as a module, and it will intercept calls to
-- `require` (more specifically the Lua module searchers) and save the
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
-- command line) using the `-c` or `-C` flag:
--
--     ./amalg.lua -o out.lua -s main.lua -c
--     ./amalg.lua -o out.lua -s main.lua -C myamalg.cache
--
-- However, this will only embed the Lua modules. To also embed the C
-- modules (both from the cache and from the command line), you have
-- to specify the `-x` flag:
--
--     ./amalg.lua -o out.lua -s main.lua -c -x
--
-- This will make the amalgamated script platform- and Lua version
-- dependent, obviously!
--
-- In some cases you may want to ignore automatically listed modules
-- in the cache without editing the cache file. Use the `-i` option
-- for that and specify a Lua pattern:
--
--     ./amalg.lua -o out.lua -s main.lua -c -i "^luarocks%."
--
-- The `-i` option can be used multiple times to specify multiple
-- patterns.
--
-- Usually, the amalgamated modules take precedence over locally
-- installed (possibly newer) versions of the same modules. If you
-- want to use local modules when available and only fall back to the
-- amalgamated code otherwise, you can specify the `-f` flag.
--
--     ./amalg.lua -o out.lua -s main.lua -c -f
--
-- This installs another searcher/loader function at the end of
-- `package.searchers` (or `package.loaders` on Lua 5.1) and adds
-- a new table `package.postload` that serves the same purpose as the
-- standard `package.preload` table.
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
-- There is also some compression/decompression support handled via
-- plugins to amalg. To select a transformation us the `-z` option.
-- Multiple compression/transformation steps are possible, and they
-- are executed in the given order. The necessary decompression code
-- is embedded in the result and executed automatically.
--
--     ./amalg.lua -o out.lua -s main.lua -c -z luac -z brieflz
--
-- Some plugins generate valid Lua code (text or binary) and thus
-- don't need a decompression step. For those modules the `-t` option
-- should be used instead to reduce dead code in the resulting
-- amalgamation file.
--
--     ./amalg.lua -o out.lua -s main.lua -c -t luasrcdiet -t luac -z brieflz
--
-- Note that compression is usually most effective when applied to the
-- complete amalgamation script instead of just individual modules:
--
--     ./amalg.lua -s main.lua -c | ./amalg.lua -o out.lua -c- -t luasrcdiet -z brieflz
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
-- *   `-C <file>`: add the modules listed in the cache file <file>
-- *   `-i <pattern>`: ignore modules in the cache file matching the
--     given pattern (can be given multiple times)
-- *   `-d`: enable debug mode (file names and line numbers in error
--     messages will point to the original location)
-- *   `-a`: do *not* apply the `arg` fix (local alias for the global
--     `arg` table)
-- *   `-f`: use embedded modules only as a fallback
-- *   `-x`: also embed compiled C modules
-- *   `-t <plugin>`: use transformation plugin
-- *   `-z <plugin>`: use compression plugin
-- *   `--`: stop parsing command line flags (all remaining arguments
--     are considered module names)
--
-- Other arguments are assumed to be module names. For an inconsistent
-- command line (e.g. duplicate options) a warning is printed to the
-- console.
local function parse_cmdline( ... )
  local modules, afix, ignores, plugins, tname, use_cache, cmods, dbg, script, oname, cname =
        {}, true, {}, {}, "preload"
  local plugin_set = {} -- to remove duplicates

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

  local function set_cname( v )
    if v then
      if cname then
        warn( "Resetting cache file `"..cname.."'! Using `"..v.."' now!" )
      end
      cname = v
    else
      warn( "Missing argument for -C option!" )
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

  local function add_transformation( v )
    if v then
      require( "amalg."..v..".transform" )
      if not plugin_set[ v ] then
        plugins[ #plugins+1 ] = { v, "transform" }
        plugin_set[ v ] = true
      end
    else
      warn( "Missing argument for -t option!" )
    end
  end

  local function add_plugin( v )
    if v then
      require( "amalg."..v..".deflate" )
      require( "amalg."..v..".inflate" )
      if not plugin_set[ v ] then
        plugins[ #plugins+1 ] = { v, "deflate", "inflate" }
        plugin_set[ v ] = true
      end
    else
      warn( "Missing argument for -z option!" )
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
    elseif a == "-t" then
      i = i + 1
      add_transformation( i <= n and select( i, ... ) )
    elseif a == "-z" then
      i = i + 1
      add_plugin( i <= n and select( i, ... ) )
    elseif a == "-f" then
      tname = "postload"
    elseif a == "-c" then
      use_cache = true
    elseif a == "-C" then
      use_cache = true
      i = i + 1
      set_cname( i <= n and select( i, ... ) )
    elseif a == "-x" then
      cmods = true
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
  return oname, script, dbg, afix, use_cache, tname, ignores, plugins, cmods, modules, cname
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


-- Reads the whole contents of a file into memory without any
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
-- Lua file and returns the contents as a Lua string. If there are
-- compression/transformation plugins specified, the deflate parts of
-- those plugins are executed on the file contents in the given order.
local function readluafile( path, plugins, stdin_allowed )
  local is_bin, s
  if stdin_allowed and path == "-" then
    s = assert( io.read( "*a" ) )
    is_bin = s:sub( 1, 1 ) == "\027"
    path = "<stdin>"
  else
    is_bin = is_bytecode( path )
    s = readfile( path, is_bin )
  end
  local shebang
  if not is_bin then
    -- Shebang lines are only supported by Lua at the very beginning
    -- of a source file, so they have to be removed before the source
    -- code can be embedded in the output.
    shebang = s:match( "^(#![^\n]*)" )
    s = s:gsub( "^#[^\n]*", "" )
  end
  for _, p in ipairs( plugins ) do
    if p[ 2 ] then
      local r, b = require( "amalg."..p[ 1 ].."."..p[ 2 ] )( s, not is_bin, path )
      s, is_bin = r, (is_bin or not b)
    end
  end
  return s, is_bin, shebang
end


-- C extension modules may be embedded into the the amalgamated script
-- as well. Compression/decompression plugins are applied as well,
-- transformation plugins are skipped.
local function readdllfile( path, plugins )
  local s = readfile( path, true )
  for _, p in ipairs( plugins ) do
    if p[ 2 ] and p[ 3 ] then
      s = require( "amalg."..p[ 1 ].."."..p[ 2 ] )( s, false, path )
    end
  end
  return s
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
-- function is used to load the cache file. <filename> ist optional:
local function readcache( filename )
  local chunk = loadfile( filename or cache, "t", {} )
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


-- Every active plugin's inflate part is called on the code in the reverse
-- order the deflate parts were executed on the input files. The closing
-- parentheses are not included in the resulting string
local function open_inflate_calls( plugins )
  local s = ""
  for _, p in ipairs( plugins ) do
    if p[ 3 ] then
      s = s.." require( "..qformat( "amalg."..p[ 1 ].."."..p[ 3 ] ).." )("
    end
  end
  return s
end


-- The closing parentheses needed by the result of the
-- `open_inflate_calls` function above is generated by this function.
local function close_inflate_calls( plugins )
  local cnt = 0
  for _, p in ipairs( plugins ) do
    if p[ 3 ] then cnt = cnt + 1 end
  end
  return (" )"):rep( cnt )
end


-- Lua modules are written to the output file in a format that can be
-- loaded by the Lua interpreter.
local function writeluamodule( out, m, path, plugins, tname, dbg, afix )
  local bytes, is_bin = readluafile( path, plugins )
  if is_bin or dbg then
    -- Precompiled Lua modules are loaded via the standard Lua
    -- function `load` (or `loadstring` in Lua 5.1). Since this
    -- preserves file name and line number information, this
    -- approach is used for all files if the debug mode is active
    -- (`-d` command line option).
    out:write( "package.", tname, "[ ", qformat( m ),
               " ] = assert( (loadstring or load)(",
               open_inflate_calls( plugins ), " ",
               qformat( bytes ), close_inflate_calls( plugins ),
               ", '@'..", qformat( path ), " ) )\n\n" )
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
    out:write( "do\nlocal _ENV = _ENV\n",
               "package.", tname, "[ ", qformat( m ),
               " ] = function( ... ) ",
               afix and "local arg = _G.arg;\n" or "_ENV = _ENV;\n",
               bytes:gsub( "%s*$", "" ), "\nend\nend\n\n" )
  end
end


-- This is the main function for the use case where `amalg.lua` is run
-- as a script. It parses the command line, creates the output files,
-- collects the module and script sources, and writes the amalgamated
-- source.
local function amalgamate( ... )
  local oname, script, dbg, afix, use_cache, tname, ignores, plugins, cmods, modules, cname =
        parse_cmdline( ... )
  local errors = {}

  -- When instructed to on the command line, the cache file is loaded,
  -- and the modules are added to the ones listed on the command line
  -- unless they are ignored via the `-i` command line option.
  if use_cache then
    local c = readcache( cname )
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
  if oname and oname ~= "-" then
    out = assert( io.open( oname, "w" ) )
  end

  -- If a main script is to be embedded, this includes the same
  -- shebang line that was used in the main script, so that the
  -- resulting amalgamation can be run without explicitly
  -- specifying the interpreter on unixoid systems (if a shebang
  -- line was specified in the first place, that is).
  local script_bytes, script_binary, shebang
  if script then
    script_bytes, script_binary, shebang = readluafile( script, plugins, true )
    if shebang then
      out:write( shebang, "\n\n" )
    end
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

  -- The inflate parts of every compression plugin must be included
  -- into the output. Later plugins can be compressed by plugins that
  -- have already been loaded.
  local active_plugins = {}
  for _,plugin in ipairs( plugins ) do
    if plugin[ 3 ] then
      local m = "amalg."..plugin[ 1 ].."."..plugin[ 3 ]
      local path, msg  = searchpath( m, package.path )
      if not path then
        error( "module `"..m.."' not found:"..msg )
      end
      writeluamodule( out, m, path, active_plugins, "preload", false, false )
    end
    active_plugins[ #active_plugins+1 ] = plugin
  end

  -- Sorts modules alphabetically. Modules will be embedded in
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
      if not path and (t == "L" or not cmods) then
        -- The module is supposed to be a Lua module, but it cannot
        -- be found, so an error is raised.
        error( "module `"..m.."' not found:"..msg )
      elseif not path then
        -- Module possibly is a C module, so it is tried again later.
        -- But the current error message is saved in case the given
        -- name isn't a C module either.
        modules[ m ], errors[ m ] = "C", msg
      else
        writeluamodule( out, m, path, plugins, tname, dbg, afix )
      end
    end
  end

  -- If the `-x` command line flag is active, C modules are embedded
  -- as strings, and written out to temporary files on demand by the
  -- amalgamated code.
  if cmods then
    local nfuncs = {}
    -- The amalgamation of C modules is split into two parts:
    -- One part generates a temporary file name for the C library
    -- and writes the binary code stored in the amalgamation to
    -- that file, while the second loads the resulting dynamic
    -- library using `package.loadlib`. The split is necessary
    -- because multiple modules could be loaded from the same
    -- library, and the amalgamated code has to simulate that.
    -- Shared dynamic libraries are embedded and extracted only once.
    --
    -- To make the loading of C modules more robust, the necessary
    -- global functions are saved in upvalues (because user-supplied
    -- code might be run before a C module is loaded). The upvalues
    -- are local to a `do ... end` block, so they aren't visible in
    -- the main script code.
    --
    -- On Windows the result of `os.tmpname()` is not an absolute
    -- path by default. If that's the case the value of the `TMP`
    -- environment variable is prepended to make it absolute.
    --
    -- The temporary dynamic library files may or may not be
    -- cleaned up when the amalgamated code exits (this probably
    -- works on POSIX machines (all Lua versions) and on Windows
    -- with Lua 5.1). The reason is that starting with version 5.2
    -- Lua ensures that libraries aren't unloaded before normal
    -- user-supplied `__gc` metamethods have run to avoid a case
    -- where such a metamethod would call an unloaded C function.
    -- As a consequence the amalgamated code tries to remove the
    -- temporary library files *before* they are actually unloaded.
    local prefix = [=[
do
  local assert = assert
  local os_remove = assert( os.remove )
  local package_loadlib = assert( package.loadlib )
  local dlls = {}
  local function temporarydll( code )
    local tmpname = assert( os.tmpname() )
    if package.config:match( "^([^\n]+)" ) == "\\" then
      if not tmpname:match( "[\\/][^\\/]+[\\/]" ) then
        local tmpdir = assert( os.getenv( "TMP" ) or os.getenv( "TEMP" ),
                               "could not detect temp directory" )
        local first = tmpname:sub( 1, 1 )
        local hassep = first == "\\" or first == "/"
        tmpname = tmpdir..((hassep) and "" or "\\")..tmpname
      end
    end
    local f = assert( io.open( tmpname, "wb" ) )
    assert( f:write( code ) )
    f:close()
    local sentinel = newproxy and newproxy( true )
                              or setmetatable( {}, { __gc = true } )
    getmetatable( sentinel ).__gc = function() os_remove( tmpname ) end
    return { tmpname, sentinel }
  end
]=]
    for _,m in ipairs( module_names ) do
      local t = modules[ m ]
      if t == "C" then
        -- Try a search strategy similar to the standard C module
        -- searcher first and then the all-in-one strategy to locate
        -- the library files for the C modules to embed.
        local path, msg  = searchpath( m, package.cpath )
        if not path then
          errors[ m ] = (errors[ m ] or "") .. msg
          path, msg = searchpath( m:gsub( "%..*$", "" ), package.cpath )
          if not path then
            error( "module `"..m.."' not found:"..errors[ m ]..msg )
          end
        end
        local qpath = qformat( path )
        -- Builds the symbol(s) to look for in the dynamic library.
        -- There may be multiple candidates because of optional
        -- version information in the module names and the different
        -- approaches of the different Lua versions in handling that.
        local openf = m:gsub( "%.", "_" )
        local openf1, openf2 = openf:match( "^([^%-]*)%-(.*)$" )
        if not nfuncs[ path ] then
          local code = readdllfile( path, plugins )
          nfuncs[ path ] = true
          local qcode = qformat( code )
          -- The `temporarydll` function saves the embedded binary
          -- code into a temporary file for later loading.
          out:write( prefix, "\n  dlls[ ", qpath, " ] = temporarydll(",
                             open_inflate_calls( plugins ), " ", qcode,
                             close_inflate_calls( plugins ), " )\n" )
          prefix = ""
        end -- shared libary not embedded already
        -- Adds a function to `package.preload` to load the temporary
        -- DLL or shared object file. This function tries to mimic the
        -- behavior of Lua 5.3 which is to strip version information
        -- from the module name at the end first, and then at the
        -- beginning if that failed.
        local qm = qformat( m )
        out:write( "\n  package.", tname, "[ ", qm, " ] = function()\n",
                   "    local dll = dlls[ ", qpath, " ][ 1 ]\n" )
        if openf1 then
          out:write( "    local loader = package_loadlib( dll, ",
                     qformat( "luaopen_"..openf1 ), " )\n",
                     "    if not loader then\n",
                     "      loader = assert( package_loadlib( dll, ",
                     qformat( "luaopen_"..openf2 ),
                     " ) )\n    end\n" )
        else
          out:write( "    local loader = assert( package_loadlib( dll, ",
                     qformat( "luaopen_"..openf ), " ) )\n" )
        end
        out:write( "    return loader( ", qm, ", dll )\n  end\n" )
      end -- is a C module
    end -- for all given module names
    if prefix == "" then
      out:write( "end\n\n" )
    end
  end -- if cmods

  -- If a main script is specified on the command line (`-s` flag),
  -- embed it now that all dependent modules are available to
  -- `require`.
  if script then
    if script_binary or dbg then
      if script == "-" then script = "<stdin>" end
      out:write( "assert( (loadstring or load)(",
                 open_inflate_calls( plugins ), " ",
                 qformat( script_bytes ),
                 close_inflate_calls( plugins ),
                 ", '@'..", qformat( script ), " ) )( ... )\n\n" )
    else
      out:write( script_bytes )
    end
  end

  if oname and oname ~= "-" then
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
    function os.exit( ... ) -- luacheck: ignore os
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

