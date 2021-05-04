#!/usr/bin/env lua

-- **Amalg** is a Lua tool for bundling a Lua script and dependent
-- Lua modules in a single `.lua` file for easier distribution.
--
-- ## Implementation
--

-- The name of the script used in warning messages and the name of the
-- cache file can be configured here by changing these local
-- variables:
local PROGRAMNAME = "amalg.lua"
local CACHEFILENAME = "amalg.cache"
-- Lua 5.4 changed the format of the package.searchpath error message
local LUAVERSION = tonumber( _VERSION:match( "(%d+%.%d+)" ) )
local NOTFOUNDPREFIX = LUAVERSION < 5.4 and "" or "\n\t"


-- Wrong use of the command line may cause warnings to be printed to
-- the console. This function is for printing those warnings:
local function warn( ... )
  io.stderr:write( "WARNING ", PROGRAMNAME, ": " )
  local n = select( '#', ... )
  for i = 1, n do
    local v = tostring( (select( i, ... )) )
    io.stderr:write( v, i == n and '\n' or '\t' )
  end
end


-- Function for parsing the command line of `amalg.lua` when invoked
-- as a script. The following flags are supported:
--
-- *   `--`: stop parsing command line flags (all remaining arguments
--     are considered module names)
-- *   `-a`, `--no-argfix`: do *not* apply the `arg` fix (local alias
--     for the global `arg` table)
-- *   `-c`, `--use-cache`: add the modules listed in the cache file
--     `amalg.cache`
-- *   `-C <file>`, `--cache-file=<file>`: add the modules listed in
--     the cache file <file>
-- *   `-d`, `--debug`: enable debug mode (file names and line numbers
--     in error messages will point to the original location)
-- *   `-f`, `--fallback`: use embedded modules only as a fallback
-- *   `-h`, `--help`: print help
-- *   `-i <pattern>`, `--ignore=<pattern>`: ignore modules in the
--     cache file matching the given pattern (can be given multiple
--     times)
-- *   `-o <file>`, `--output=<file>`: specify output file (default is
--     `stdout`)
-- *   `-p <file>`, `--prefix=<file>`: use file contents as prefix
--     code for the amalgamated script (i.e. usually as a package
--     module stub)
-- *   `-s <file>`, `--script=<file>`: specify main script to bundle
-- *   `-S <shebang>`, `--shebang=<shebang>`: Specify shebang line to
--     use for the resulting script
-- *   `-t <plugin>`, `--transform=<plugin>`: use transformation
--     plugin (can be given multiple times)
-- *   `-v <file>`, `--virtual-io=<file>`: embed as virtual resource
--     (can be given multiple times)
-- *   `-x`, `--c-libs`: also embed compiled C modules
-- *   `-z <plugin>`, `--zip=<plugin>`: use (de-)compression plugin
--     (can be given multiple times)
--
-- Other arguments are assumed to be module names. For an inconsistent
-- command line (e.g. duplicate options) a warning is printed to the
-- console.
local function parsecommandline( ... )
  local options = {
    modules = {}, argfix = true, ignorepatterns = {}, plugins = {},
    packagefieldname = "preload", virtualresources = {}
  }
  local pluginalreadyadded = {} -- to remove duplicates

  local function makesetter( what, fieldname, optionname )
    return function( v )
      if v then
        if options[ fieldname ] then
          warn( "Resetting "..what.." '"..options[ fieldname ]..
                "'! Using '"..v.."' now!" )
        end
        options[ fieldname ] = v
      else
        warn( "Missing argument for "..optionname.." option!" )
      end
    end
  end

  local setoutputname = makesetter( "output file", "outputname", "-o/--output" )
  local setcachefilename = makesetter( "cache file", "cachefile", "-C/--cache-file" )
  local setmainscript = makesetter( "main script", "scriptname", "-s/--script" )
  local setshebang = makesetter( "shebang line", "shebang", "-S/--shebang" )
  local setprefixfile = makesetter( "prefix file", "prefixfile", "-p/--prefix" )

  local function addignorepattern( v )
    if v then
      if not pcall( string.match, "", v ) then
        warn( "Invalid Lua pattern: '"..v.."'" )
      else
        options.ignorepatterns[ #options.ignorepatterns+1 ] = v
      end
    else
      warn( "Missing argument for -i/--ignore option!" )
    end
  end

  local function addtransformation( v )
    if v then
      local transform = "amalg."..v..".transform"
      require( transform )
      if not pluginalreadyadded[ v ] then
        options.plugins[ #options.plugins+1 ] = { transform }
        pluginalreadyadded[ v ] = true
      end
    else
      warn( "Missing argument for -t/--transform option!" )
    end
  end

  local function addcompression( v )
    if v then
      local deflate = "amalg."..v..".deflate"
      local inflate = "amalg."..v..".inflate"
      require( deflate )
      require( inflate )
      if not pluginalreadyadded[ v ] then
        options.plugins[ #options.plugins+1 ] = { deflate, inflate }
        pluginalreadyadded[ v ] = true
      end
    else
      warn( "Missing argument for -z/--zip option!" )
    end
  end

  local function addvirtualioresource( v )
    if v then
      options.virtualresources[ #options.virtualresources+1 ] = v
    else
      warn( "Missing argument for -v/--virtual-io option!" )
    end
  end

  local i, n = 1, select( '#', ... )
  while i <= n do
    local a = select( i, ... )
    if a == "--" then
      for j = i+1, n do
        options.modules[ select( j, ... ) ] = true
      end
      break
    elseif a == "-h" or a == "--help" then
      i = i + 1
      options.showhelp = true
    elseif a == "-o" or a == "--output" then
      i = i + 1
      setoutputname( i <= n and select( i, ... ) )
    elseif a == "-p" or a == "--prefix" then
      i = i + 1
      setprefixfile( i <= n and select( i, ... ) )
    elseif a == "-s" or a == "--script" then
      i = i + 1
      setmainscript( i <= n and select( i, ... ) )
    elseif a == "-S" or a == "--shebang" then
      i = i + 1
      setshebang( i <= n and select( i, ... ) )
    elseif a == "-i" or a == "--ignore" then
      i = i + 1
      addignorepattern( i <= n and select( i, ... ) )
    elseif a == "-t" or a == "--transform" then
      i = i + 1
      addtransformation( i <= n and select( i, ... ) )
    elseif a == "-z" or a == "--zip" then
      i = i + 1
      addcompression( i <= n and select( i, ... ) )
    elseif a == "-v" or a == "--virtual-io" then
      i = i + 1
      addvirtualioresource( i <= n and select( i, ... ) )
    elseif a == "-f" or a == "--fallback" then
      options.packagefieldname = "postload"
    elseif a == "-c" or a == "--use-cache" then
      options.usecache = true
    elseif a == "-C" or a == "--cache-file" then
      options.usecache = true
      i = i + 1
      setcachefilename( i <= n and select( i, ... ) )
    elseif a == "-x" or a == "--c-libs" then
      options.embedcmodules = true
    elseif a == "-d" or a == "--debug" then
      options.debugmode = true
    elseif a == "-a" or a == "--no-argfix" then
      options.argfix = false
    else
      local prefix = a:sub( 1, 2 )
      if prefix == "-o" then
        setoutputname( a:sub( 3 ) )
      elseif prefix == "-p" then
        setprefixfile( a:sub( 3 ) )
      elseif prefix == "-s" then
        setmainscript( a:sub( 3 ) )
      elseif prefix == "-S" then
        setshebang( a:sub( 3 ) )
      elseif prefix == "-i" then
        addignorepattern( a:sub( 3 ) )
      elseif prefix == "-t" then
        addtransformation( a:sub( 3 ) )
      elseif prefix == "-z" then
        addcompression( a:sub( 3 ) )
      elseif prefix == "-v" then
        addvirtualioresource( a:sub( 3 ) )
      elseif prefix == "-C" then
        options.usecache = true
        setcachefilename( a:sub( 3 ) )
      elseif a:sub( 1, 1 ) == "-" then
        local option, value = a:match( "^(%-%-[%w%-]+)=(.*)$" )
        if option == "--output" then
          setoutputname( value )
        elseif option == "--prefix" then
          setprefixfile( value )
        elseif option == "--script" then
          setmainscript( value )
        elseif option == "--shebang" then
          setshebang( value )
        elseif option == "--ignore" then
          addignorepattern( value )
        elseif option == "--transform" then
          addtransformation( value )
        elseif option == "--zip" then
          addcompression( value )
        elseif option == "--virtual-io" then
          addvirtualioresource( value )
        elseif option == "--cache-file" then
          options.usecache = true
          setcachefilename( value )
        else
          warn( "Unknown/invalid command line flag: "..a )
        end
      else
        options.modules[ a ] = true
      end
    end
    i = i + 1
  end
  return options
end


-- The approach for embedding precompiled Lua files is different from
-- the normal way of pasting the source code, so this function detects
-- whether a file is a binary file (Lua bytecode starts with the `ESC`
-- character):
local function isbytecode( path )
  local file, result = io.open( path, "rb" ), false
  if file then
    result = file:read( 1 ) == "\027"
    file:close()
  end
  return result
end


-- The `readfile` funciton reads the whole contents of a file into
-- memory without any processing.
local function readfile( path, isbinary )
  local file = assert( io.open( path, isbinary and "rb" or "r" ) )
  local data = assert( file:read( "*a" ) )
  file:close()
  return data
end


-- Lua files to be embedded into the resulting amalgamation are read
-- into memory in a single go, because under some circumstances (e.g.
-- binary chunks, shebang lines, `-d` command line flag) some
-- preprocessing/escaping is necessary. This function reads a whole
-- Lua file and returns the contents as a Lua string. If there are
-- compression/transformation plugins specified, the deflate parts of
-- those plugins are executed on the file contents in the given order.
local function readluafile( path, plugins, stdinallowed )
  local isbinary, bytes
  if stdinallowed and path == "-" then
    bytes = assert( io.read( "*a" ) )
    isbinary = bytes:sub( 1, 1 ) == "\027"
    path = "<stdin>"
  else
    isbinary = isbytecode( path )
    bytes = readfile( path, isbinary )
  end
  local shebang
  if not isbinary then
    -- Shebang lines are only supported by Lua at the very beginning
    -- of a source file, so they have to be removed before the source
    -- code can be embedded in the output. A byte-order-marker is
    -- removed as well if present.
    bytes = bytes:gsub( "^\239\187\191", "" )
    shebang = bytes:match( "^(#[^\n]*)" )
    bytes = bytes:gsub( "^#[^\n]*", "" )
  end
  for _, pluginspec in ipairs( plugins ) do
    local r, b = require( pluginspec[ 1 ] )( bytes, not isbinary, path )
    bytes, isbinary = r, (isbinary or not b)
  end
  return bytes, isbinary, shebang
end


-- C extension modules and virtual resources may be embedded into the
-- amalgamated script as well. Compression/decompression plugins are
-- applied, transformation plugins are skipped because transformation
-- plugins usually expect and produce Lua source code.
local function readbinfile( path, plugins )
  local bytes = readfile( path, true )
  for _, pluginspec in ipairs( plugins ) do
    if pluginspec[ 2 ] then
      bytes = require( pluginspec[ 1 ] )( bytes, false, path )
    end
  end
  return bytes
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
-- function is used to load the cache file. `<filename>` is optional:
local function readcache( filename )
  local chunk = loadfile( filename or CACHEFILENAME, "t", {} )
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
local function writecache( cache )
  local file = assert( io.open( CACHEFILENAME, "w" ) )
  file:write( "return {\n" )
  if type( cache[ 1 ] ) == "string" then
    file:write( "  ", qformat( cache[ 1 ] ), ",\n" )
  end
  for k, v in pairs( cache ) do
    if type( k ) == "string" and type( v ) == "string" then
      file:write( "  [ ", qformat( k ), " ] = ", qformat( v ), ",\n" )
    end
  end
  file:write( "}\n" )
  file:close()
end


-- The standard Lua function `package.searchpath` available in Lua 5.2
-- and up is used to locate the source files for Lua modules and
-- library files for C modules. For Lua 5.1 a backport is provided.
local searchpath = package.searchpath
if not searchpath then
  local delimiter = package.config:match( "^(.-)\n" ):gsub( "%%", "%%%%" )

  function searchpath( name, path )
    local pname = name:gsub( "%.", delimiter ):gsub( "%%", "%%%%" )
    local messages = {}
    for subpath in path:gmatch( "[^;]+" ) do
      local fpath = subpath:gsub( "%?", pname )
      local file = io.open( fpath, "r" )
      if file then
        file:close()
        return fpath
      end
      messages[ #messages+1 ] = "\n\tno file '"..fpath.."'"
    end
    return nil, table.concat( messages )
  end
end


-- Every active plugin's inflate part is called on the code in the reverse
-- order the deflate parts were executed on the input files. The closing
-- parentheses are not included in the resulting string. The
-- `closeinflatecalls` function below is responsible for those.
local function openinflatecalls( plugins )
  local s = ""
  for _, pluginspec in ipairs( plugins ) do
    if pluginspec[ 2 ] then
      s = s.." require( "..qformat( pluginspec[ 2 ] ).." )("
    end
  end
  return s
end


-- The closing parentheses needed by the result of the
-- `openinflatecalls` function above is generated by this function.
local function closeinflatecalls( plugins )
  local count = 0
  for _, pluginspec in ipairs( plugins ) do
    if pluginspec[ 2 ] then count = count + 1 end
  end
  return (" )"):rep( count )
end


-- Lua modules are written to the output file in a format that can be
-- loaded by the Lua interpreter.
local function writeluamodule( out, modulename, path, plugins,
                               packagefieldname, debugmode, argfix )
  local bytes, isbinary = readluafile( path, plugins )
  if isbinary or debugmode then
    -- Precompiled Lua modules are loaded via the standard Lua
    -- function `load` (or `loadstring` in Lua 5.1). Since this
    -- preserves file name and line number information, this
    -- approach is used for all files if the debug mode is active
    -- (`-d` command line option). This is also necessary if
    -- decompression steps need to happen or if the final
    -- transformation plugin produces Lua byte-code.
    out:write( "package.", packagefieldname, "[ ", qformat( modulename ),
               " ] = assert( (loadstring or load)(",
               openinflatecalls( plugins ), " ",
               qformat( bytes ), closeinflatecalls( plugins ),
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
               "package.", packagefieldname, "[ ", qformat( modulename ),
               " ] = function( ... ) ",
               argfix and "local arg = _G.arg;\n" or "_ENV = _ENV;\n",
               bytes:gsub( "%s*$", "" ), "\nend\nend\n\n" )
  end
end


-- This is the main function for the use case where `amalg.lua` is run
-- as a script. It parses the command line, creates the output files,
-- collects the module and script sources, and writes the amalgamated
-- source.
local function amalgamate( ... )
  local options = parsecommandline( ... )
  local errors = {}

  if options.showhelp then
    print( ([[%s <options> [--] <modules...>

  available options:
    -a, --no-argfix: disable `arg` fix
    -c, --use-cache: take module names from `%s` cache file
    -C <file>, --cache-file=<file>: take module names from <file>
    -d, --debug: preserve file names and line numbers
    -f, --fallback: use embedded modules as fallback only
    -h, --help: print help/usage
    -i <pattern>, --ignore=<pattern>: ignore matching modules from
      cache (can be specified multiple times)
    -o <file>, --output=<file>: write output to <file>
    -p <file>, --prefix=<file>: add the file contents as prefix
      (very early) in the amalgamation
    -s <file>, --script=<file>: embed <file> as main script
    -S <shebang>, --shebang=<shebang>: specify shebang line to use
    -t <plugin>, --transform=<plugin>: use transformation plugin
      (can be specified multiple times)
    -v <file>, --virtual-io=<file>: store <file> in amalgamation
      (can be specified multiple times)
    -x, --c-libs: also embed C modules
    -z <plugin>, --zip=<plugin>: use (de-)compression plugin
      (can be specified multiple times)
]]):format( PROGRAMNAME, CACHEFILENAME ) )
    return
  end

  -- When instructed to on the command line, the cache file is loaded,
  -- and the modules are added to the ones listed on the command line
  -- unless they are ignored via the `-i` command line option.
  if options.usecache then
    local cache = readcache( options.cachefile )
    for k, v in pairs( cache or {} ) do
      local addmodule = true
      if type( k ) == "string" then
        for _, pattern in ipairs( options.ignorepatterns ) do
          if k:match( pattern ) then
            addmodule = false
            break
          end
        end
      else
        addmodule = false
        if k == 1 and options.scriptname == nil then
          options.scriptname = v
        end
      end
      if addmodule then
        options.modules[ k ] = v
      end
    end
  end

  local out = io.stdout
  if options.outputname and options.outputname ~= "-" then
    out = assert( io.open( options.outputname, "w" ) )
  end

  -- If a main script is to be embedded, this includes the same
  -- shebang line that was used in the main script, so that the
  -- resulting amalgamation can be run without explicitly
  -- specifying the interpreter on unixoid systems (if a shebang
  -- line was specified in the first place, that is). However, a
  -- shebang line specifed via command line options takes precedence!
  local scriptbytes, scriptisbinary, shebang
  if options.scriptname and options.scriptname ~= "" then
    scriptbytes, scriptisbinary, shebang = readluafile( options.scriptname,
                                                        options.plugins, true )
    if options.shebang then
      if options.shebang:match( "^#!" ) then
        shebang = options.shebang
      elseif options.shebang:match( "^%s*$" ) then
        shebang = nil
      else
        shebang = "#!"..options.shebang
      end
    end
    if shebang then
      out:write( shebang, "\n\n" )
    end
  end

  -- The `-p` command line switch allows to embed Lua code into the
  -- amalgamation right after the shebang line. This can be used to
  -- provide stubs for the standard `package` module required for
  -- the amalgamated script to work correctly in case the Lua
  -- implementation does not provide a sufficient `package` module
  -- implementation on its own. This is sometimes the case when Lua
  -- is embedded into host programs (e.g. Redis, WoW, etc.). The bits
  -- of the `package` module that are necessary depend on the command
  -- line switches given, but you will need at least `package.preload`
  -- and a `require` function that uses it.
  if options.prefixfile then
    out:write( readfile( options.prefixfile ), "\n" )
  end

  -- If fallback loading is requested, the module loaders of the
  -- amalgamated modules are registered in table `package.postload`,
  -- and an extra searcher function is added at the end of
  -- `package.searchers`.
  if options.packagefieldname == "postload" then
    out:write( [=[
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
  -- have already been processed.
  local activeplugins = {}
  for _, pluginspec in ipairs( options.plugins ) do
    if pluginspec[ 2 ] then
      local path, message  = searchpath( pluginspec[ 2 ], package.path )
      if not path then
        error( "module `"..pluginspec[ 2 ].."' not found:"..NOTFOUNDPREFIX..message )
      end
      writeluamodule( out, pluginspec[ 2 ], path, activeplugins, "preload" )
    end
    activeplugins[ #activeplugins+1 ] = pluginspec
  end

  -- Sorts modules alphabetically. Modules will be embedded in
  -- alphabetical order. This ensures deterministic output.
  local modulenames = {}
  for modulename in pairs( options.modules ) do
    modulenames[ #modulenames+1 ] = modulename
  end
  table.sort( modulenames )

  -- Every module given on the command line and/or in the cache file
  -- is processed.
  for _, modulename in ipairs( modulenames ) do
    local moduletype = options.modules[ modulename ]
    -- Only Lua modules are handled for now, so modules that are
    -- definitely C modules are skipped and handled later.
    if moduletype ~= "C" then
      local path, message  = searchpath( modulename, package.path )
      if not path and (moduletype == "L" or not options.embedcmodules) then
        -- The module is supposed to be a Lua module, but it cannot
        -- be found, so an error is raised.
        error( "module `"..modulename.."' not found:"..NOTFOUNDPREFIX..message )
      elseif not path then
        -- Module possibly is a C module, so it is tried again later.
        -- But the current error message is saved in case the given
        -- name isn't a C module either.
        options.modules[ modulename ], errors[ modulename ] = "C", NOTFOUNDPREFIX..message
      else
        writeluamodule( out, modulename, path, options.plugins,
                        options.packagefieldname, options.debugmode,
                        options.argfix )
      end
    end
  end

  -- If the `-x` command line flag is active, C modules are embedded
  -- as strings, and written out to temporary files on demand by the
  -- amalgamated code.
  if options.embedcmodules then
    local dllembedded = {}
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
    for _, modulename in ipairs( modulenames ) do
      local moduletype = options.modules[ modulename ]
      if moduletype == "C" then
        -- Try a search strategy similar to the standard C module
        -- searcher first and then the all-in-one strategy to locate
        -- the library files for the C modules to embed.
        local path, message  = searchpath( modulename, package.cpath )
        if not path then
          errors[ modulename ] = (errors[ modulename ] or "")..NOTFOUNDPREFIX..message
          path, message = searchpath( modulename:gsub( "%..*$", "" ), package.cpath )
          if not path then
            error( "module `"..modulename.."' not found:"..
                   errors[ modulename ]..NOTFOUNDPREFIX..message )
          end
        end
        local qpath = qformat( path )
        -- Builds the symbol(s) to look for in the dynamic library.
        -- There may be multiple candidates because of optional
        -- version information in the module names and the different
        -- approaches of the different Lua versions in handling that.
        local openf = modulename:gsub( "%.", "_" )
        local openf1, openf2 = openf:match( "^([^%-]*)%-(.*)$" )
        if not dllembedded[ path ] then
          local code = readbinfile( path, options.plugins )
          dllembedded[ path ] = true
          local qcode = qformat( code )
          -- The `temporarydll` function saves the embedded binary
          -- code into a temporary file for later loading.
          out:write( prefix, "\ndlls[ ", qpath, " ] = temporarydll(",
                             openinflatecalls( options.plugins ), " ", qcode,
                             closeinflatecalls( options.plugins ), " )\n" )
          prefix = ""
        end -- shared libary not embedded already
        -- Adds a function to `package.preload` to load the temporary
        -- DLL or shared object file. This function tries to mimic the
        -- behavior of Lua 5.3 which is to strip version information
        -- from the module name at the end first, and then at the
        -- beginning if that failed.
        local qm = qformat( modulename )
        out:write( "\npackage.", options.packagefieldname, "[ ", qm,
                   " ] = function()\n  local dll = dlls[ ", qpath,
                   " ][ 1 ]\n" )
        if openf1 then
          out:write( "  local loader = package_loadlib( dll, ",
                     qformat( "luaopen_"..openf1 ), " )\n",
                     "  if not loader then\n",
                     "    loader = assert( package_loadlib( dll, ",
                     qformat( "luaopen_"..openf2 ), " ) )\n  end\n" )
        else
          out:write( "  local loader = assert( package_loadlib( dll, ",
                     qformat( "luaopen_"..openf ), " ) )\n" )
        end
        out:write( "  return loader( ", qm, ", dll )\nend\n" )
      end -- is a C module
    end -- for all given module names
    if prefix == "" then
      out:write( "end\n\n" )
    end
  end -- if embedcmodules

  -- Virtual resources are embedded like dlls, and the Lua standard
  -- io functions are monkey-patched to search for embedded files
  -- first. The amalgamated script includes a complete implementation
  -- of file io that works on strings embedded in the amalgamation if
  -- (and only if) the file is opened in read-only mode.
  -- To reduce the size of the embedded code, error handling is mostly
  -- left out (since the resources are static, you can make sure that
  -- no errors occurr). Also, emulating the IO library for four
  -- different Lua versions on many different architectures and OSes
  -- is very challenging. Therefore, there might be corner cases
  -- where the virtual IO functions behave slightly differently than
  -- the native IO functions. This applies in particular to the `"*n"`
  -- format for `read` or `lines`.
  -- In addition to file IO functions and methods, `loadfile` and
  -- `dofile` are patched as well.
  if #options.virtualresources > 0 then
    out:write( [=[
do
local vfile = {}
local vfile_mt = { __index = vfile }
local assert = assert
local select = assert( select )
local setmetatable = assert( setmetatable )
local tonumber = assert( tonumber )
local type = assert( type )
local table_unpack = assert( unpack or table.unpack )
local io_open = assert( io.open )
local io_lines = assert( io.lines )
local _loadfile = assert( loadfile )
local _dofile = assert( dofile )
local virtual = {}
function io.open( path, mode )
  if (mode == "r" or mode == "rb") and virtual[ path ] then
    return setmetatable( { offset=0, data=virtual[ path ] }, vfile_mt )
  else
    return io_open( path, mode )
  end
end
function io.lines( path, ... )
  if virtual[ path ] then
    return setmetatable( { offset=0, data=virtual[ path ] }, vfile_mt ):lines( ... )
  else
    return io_lines( path, ... )
  end
end
function loadfile( path, ... )
  if virtual[ path ] then
    local s = virtual[ path ]:gsub( "^%s*#[^\n]*\n", "" )
    return (loadstring or load)( s, "@"..path, ... )
  else
    return _loadfile( path, ... )
  end
end
function dofile( path )
  if virtual[ path ] then
    local s = virtual[ path ]:gsub( "^%s*#[^\n]*\n", "" )
    return assert( (loadstring or load)( s, "@"..path ) )()
  else
    return _dofile( path )
  end
end
function vfile:close() return true end
vfile.flush = vfile.close
vfile.setvbuf = vfile.close
function vfile:write() return self end
local function lines_iterator( state )
  return state.file:read( table_unpack( state, 1, state.n ) )
end
function vfile:lines( ... )
  return lines_iterator, { file=self, n=select( '#', ... ), ... }
end
local function _read( self, n, fmt, ... )
  if n > 0 then
    local o = self.offset
    if o >= #self.data then return nil end
    if type( fmt ) == "number" then
      self.offset = o + fmt
      return self.data:sub( o+1, self.offset ), _read( self, n-1, ... )
    elseif fmt == "n" or fmt == "*n" then
      local p, e, x = self.data:match( "^%s*()%S+()", o+1 )
      if p then
        o = p - 1
        for i = p+1, e-1 do
          local newx = tonumber( self.data:sub( p, i ) )
          if newx then
            x, o = newx, i
          elseif i > o+3 then
            break
          end
        end
      else
        o = #self.data
      end
      self.offset = o
      return x, _read( self, n-1, ... )
    elseif fmt == "l" or fmt == "*l" then
      local s, p = self.data:match( "^([^\r\n]*)\r?\n?()", o+1 )
      self.offset = p-1
      return s, _read( self, n-1, ... )
    elseif fmt == "L" or fmt == "*L" then
      local s, p = self.data:match( "^([^\r\n]*\r?\n?)()", o+1 )
      self.offset = p-1
      return s, _read( self, n-1, ... )
    elseif fmt == "a" or fmt == "*a" then
      self.offset = #self.data
      return self.data:sub( o+1, self.offset )
    end
  end
end
function vfile:read( ... )
  local n = select( '#', ... )
  if n > 0 then
    return _read( self, n, ... )
  else
    return _read( self, 1, "l" )
  end
end
function vfile:seek( whence, offset )
  whence, offset = whence or "cur", offset or 0
  if whence == "set" then
    self.offset = offset
  elseif whence == "cur" then
    self.offset = self.offset + offset
  elseif whence == "end" then
    self.offset = #self.data + offset
  end
  return self.offset
end
]=] )
    for _, v in ipairs( options.virtualresources ) do
      local qdata = qformat( readbinfile( v, options.plugins ) )
      out:write( "\nvirtual[ ", qformat( v ), " ] =",
                 openinflatecalls( options.plugins ), " ", qdata,
                 closeinflatecalls( options.plugins ), "\n" )
    end
    out:write( "end\n\n" )
  end -- if #options.virtualresources > 0

  -- If a main script is specified on the command line (`-s` flag),
  -- embed it now that all dependency modules are available to
  -- `require`.
  if options.scriptname and options.scriptname ~= "" then
    if scriptisbinary or options.debugmode then
      if options.scriptname == "-" then
        options.scriptname = "<stdin>"
      end
      out:write( "assert( (loadstring or load)(",
                 openinflatecalls( options.plugins ), " ",
                 qformat( scriptbytes ),
                 closeinflatecalls( options.plugins ),
                 ", '@'..", qformat( options.scriptname ),
                 " ) )( ... )\n\n" )
    else
      out:write( scriptbytes )
    end
  end

  if options.outputname and options.outputname ~= "-" then
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
  local offset = 0
  if package.loaded[ "luarocks.loader" ] then offset = 1 end
  assert( #searchers == 4+offset, "package.searchers has been modified" )
  local cache = readcache() or {}
  -- The updated cache is written to disk when the following value is
  -- garbage collected, which should happen at `lua_close()`.
  local sentinel = newproxy and newproxy( true )
                            or setmetatable( {}, { __gc = true } )
  getmetatable( sentinel ).__gc = function()
    if type( arg ) == "table"  then
      cache[ 1 ] = arg[ 0 ]
    end
    writecache( cache )
  end
  local luasearcher = searchers[ 2+offset ]
  local csearcher = searchers[ 3+offset ]
  local aiosearcher = searchers[ 4+offset ] -- all in one searcher

  local function addcacheentry( tag, mname, ... )
    if type( (...) ) == "function" then
      cache[ mname ] = tag
    end
    return ...
  end

  -- The replacement searchers just forward to the original versions,
  -- but also update the cache if the search was successful.
  searchers[ 2+offset ] = function( ... )
    local _ = sentinel -- make sure that sentinel is an upvalue
    return addcacheentry( "L", ..., luasearcher( ... ) )
  end
  searchers[ 3+offset ] = function( ... )
    local _ = sentinel -- make sure that sentinel is an upvalue
    return addcacheentry( "C", ..., csearcher( ... ) )
  end
  searchers[ 4+offset ] = function( ... )
    local _ = sentinel -- make sure that sentinel is an upvalue
    return addcacheentry( "C", ..., aiosearcher( ... ) )
  end

  -- Since calling `os.exit` might skip the `lua_close()` call, the
  -- `os.exit` function is monkey-patched to also save the updated
  -- cache to the cache file on disk.
  if type( os ) == "table" and type( os.exit ) == "function" then
    local os_exit = os.exit
    function os.exit( ... ) -- luacheck: ignore os
      if type( arg ) == "table" then
        cache[ 1 ] = arg[ 0 ]
      end
      writecache( cache )
      return os_exit( ... )
    end
  end
end


-- To determine whether `amalg.lua` is run as a script or loaded as a
-- module it uses the debug module to walk the call stack looking for
-- a `require` call. If such a call is found, `amalg.lua` has been
-- `require`d as a module.
local function isscript()
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
if isscript() then
  amalgamate( ... )
else
  collect()
end

