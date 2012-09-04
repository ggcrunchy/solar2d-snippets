-- ldoc configuration file
file = { ".", "class", "dot", "effect", "enemy", "event", "fill", "game", "ui", exclude = { "scene", "tiles" } }
output = "api"
title = "So So Squirrel documentation"
project = "So So Squirrel"
-- readme = "readme.md"
--one = true
-- no_summary = true
--examples = {'examples', exclude = {'examples/slow.lua'}}
description = [[
What goes into our exciting squirrel adventure.
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