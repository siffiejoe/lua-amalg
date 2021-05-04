local module2 = require( "module2" )

local M = {}

function M.func() : string
  return "module1"
end

function M.add( a : number, b : number ) : number
  return a + b
end

function M.func2() : string
  assert( M.add( 1, 2 ) == 3 )
  return module2.func()
end

return M

