if _VERSION == "Lua 5.1" then
  module( "module2" )
else
  local _M = {}
  package.loaded[ "module2" ] = _M
  _ENV = _M
end

function func() -- luacheck: ignore func
  return "module2"
end

