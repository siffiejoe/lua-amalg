local module2 = require( "module2" )

local M = {}

function M.func()
  return "module1"
end

function M.func2()
  return module2.func()
end

return M

