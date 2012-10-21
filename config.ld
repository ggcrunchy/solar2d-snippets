-- ldoc configuration file
file = { ".", "class", "dot", "effect", "enemy", "event", "fill", "game", "ui", exclude = { "scene", "tiles" } }
-- TODO: Why aren't my excludes working? ...And then correct those folders when they are.
output = "api"
title = "Snippets documentation"
project = "Corona SDK snippets"
dir = 'snippets_docs'
-- readme = "readme.md"
--one = true
-- no_summary = true
--examples = {'examples', exclude = {'examples/slow.lua'}}
description = [[
Snippets like crazy.
]]
--no_return_or_parms = true
--manual_url 'file:///D:/dev/lua/projects/lua-5.1.4/doc/manual.html'

format = 'markdown'

-- Type aliases
tparam_alias('bool', 'bool')

tparam_alias('number', 'number')
tparam_alias('byte', 'byte')
tparam_alias('int', 'int')
tparam_alias('uint', 'uint')

tparam_alias('string', 'string')

tparam_alias('callable', 'callable')

tparam_alias('array', 'array')
tparam_alias('ptable', 'table')

tparam_alias('pgroup', 'DisplayGroup')
tparam_alias('pobject', 'DisplayObject')