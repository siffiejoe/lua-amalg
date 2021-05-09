(local module2 (require :module2))

(fn func [] "module1")
(fn func2 [] (module2.func))

{
  :func func
  :func2 func2
}

