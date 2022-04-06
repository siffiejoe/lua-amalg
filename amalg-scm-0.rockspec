package = "amalg"
version = "scm-0"
source = {
  url = "git://github.com/siffiejoe/lua-amalg.git",
}
description = {
  summary = "Amalgamation for Lua modules/scripts.",
  detailed = [[
    This small Lua module/script can package a Lua script and its
    dependencies as a single Lua file for easier deployment.
  ]],
  homepage = "https://github.com/siffiejoe/lua-amalg/",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1, < 5.5"
}
build = {
  type = "builtin",
  modules = {
    amalg = "src/amalg.lua",
    ["amalg.luac.transform"] = "src/amalg/luac/transform.lua",
    ["amalg.luasrcdiet.transform"] = "src/amalg/luasrcdiet/transform.lua",
    ["amalg.dumbluaparser.transform"] = "src/amalg/dumbluaparser/transform.lua",
    ["amalg.moonscript.transform"] = "src/amalg/moonscript/transform.lua",
    ["amalg.teal.transform"] = "src/amalg/teal/transform.lua",
    ["amalg.fennel.transform"] = "src/amalg/fennel/transform.lua",
    ["amalg.brieflz.inflate"] = "src/amalg/brieflz/inflate.lua",
    ["amalg.brieflz.deflate"] = "src/amalg/brieflz/deflate.lua",
  },
  install = {
    bin = {
      ["amalg.lua"] = "src/amalg.lua"
    }
  }
}

