package = "luaxml"
version = "1.0-0"
source = {
   url = "git://github.com/Crazyokd/luaxml",
   tag = "v1.0.0"
}
description = {
   summary = "Expressing xml with lua",
   detailed = [[
   lua <=> xml with order.
   ]],
   homepage = "https://github.com/Crazyokd/luaxml",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, <= 5.4"
}
build = {
  type = "builtin",
  modules = {
      luaxml = "luaxml.lua",
  }
}
