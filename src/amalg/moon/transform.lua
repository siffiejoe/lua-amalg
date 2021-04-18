require "moonscript"
moon = require "moonscript.base"

local function endsWith(s, target)
  return s:sub(#s - #target + 1) == target
end

package.path = package.moonpath .. package.path

return function( s, is_text, path )
  if is_text then
    if endsWith(path, '.moon') then
      local code = moon.to_lua(s)
      return code, true
    else
      return s, true
    end
  else
    return s, false
  end
end

