module2 = require "module2"

func = -> "module1"

func2 = -> module2.func!

{
  :func, :func2
}

