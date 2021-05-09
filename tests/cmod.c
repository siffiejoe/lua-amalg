/* Copyright 2021 Philipp Janda */
#include <lua.h>
#include <lauxlib.h>


static int l_func(lua_State* L) {
  lua_pushliteral(L, "cmodule");
  return 1;
}

int luaopen_cmod(lua_State* L) {
  lua_newtable(L);
  lua_pushcfunction(L, l_func);
  lua_setfield(L, -2, "func");
  return 1;
}

