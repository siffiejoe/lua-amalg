package = "amalg-redis"
version = "0.1.2-0"
source = {
   url = "https://github.com/BixData/lua-amalg-redis/archive/0.1.2-0.tar.gz",
   dir = "lua-amalg-redis-0.1.2-0"
}
description = {
   summary = "A Lua amalgamator for Redis",
   detailed = [[
      A Lua amalgamator specific to scripts sent into Redis.
      This is a fork of lua-amalg by Philipp Janda.
   ]],
   homepage = "https://github.com/BixData/lua-amalg-redis",
   maintainer = "David Rauschenbach",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, < 5.4"
}
build = {
   type = "builtin",
   modules = {
      ["amalg-redis"] = "src/amalg-redis.lua"
   },
   install = {
     bin = {
       ["amalg-redis.lua"] = "src/amalg-redis.lua"
     }
   }
}
