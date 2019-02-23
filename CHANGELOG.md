## [0.1.1] - 2019-02-24
### Fixed
- [#5](https://github.com/BixData/lua-amalg-redis/issues/5) Custom module loader fails to ensure modules are singletons; downstream class type comparisons fail
- [#3](https://github.com/BixData/lua-amalg-redis/issues/3) Moses workaround sets os variable for other modules
- [#1](https://github.com/BixData/lua-amalg-redis/issues/1) Cannot require `cjson` or other built-in modules

## [0.1.0] - 2019-02-23
### Added
- Prefix amalgamated scripts with Redis support
- Indent code so that amalgamated result conforms to 2-space indents
- Initial port of `lua-amalg`

<small>(formatted per [keepachangelog-1.1.0](http://keepachangelog.com/en/1.0.0/))</small>
