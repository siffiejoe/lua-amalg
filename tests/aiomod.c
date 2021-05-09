/* Copyright 2021 Philipp Janda */
#include <lua.h>
#include <lauxlib.h>


static int l_func1(lua_State* L) {
  lua_pushliteral(L, "aiomodule1");
  return 1;
}


static int l_func2(lua_State* L) {
  lua_pushliteral(L, "aiomodule2");
  return 1;
}


int luaopen_aiomod_a(lua_State* L) {
  lua_newtable(L);
  lua_pushcfunction(L, l_func1);
  lua_setfield(L, -2, "func");
  return 1;
}


int luaopen_aiomod_b(lua_State* L) {
  lua_newtable(L);
  lua_pushcfunction(L, l_func2);
  lua_setfield(L, -2, "func");
  return 1;
}

