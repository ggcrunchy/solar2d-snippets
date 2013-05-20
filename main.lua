--- Driver code and main functions.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local pairs = pairs
local print = print
local require = require
local setmetatable = setmetatable

-- Modules --
local debug = require("debug")
local errors = require("errors")
local flow_bodies = require("flow_bodies")
local frames = require("game.Frames")
local per_coroutine_ops = require("per_coroutine_ops")
local scenes = require("game.Scenes")
local var_dump = require("var_dump")

-- Corona globals --
local native = native
local system = system

-- Install the coroutine time logic.
flow_bodies.SetTimeLapseFuncs(per_coroutine_ops.TimeLapse(frames.DiffTime, frames.GetFrameID))

-- Use standard tracebacks.
errors.SetTracebackFunc(debug.traceback)

-- "enterFrame" listener --
Runtime:addEventListener("enterFrame", function()
	scenes.Send("update")
end)

-- "key" listener --
Runtime:addEventListener("key", function(event)
	local key = event.keyName

	if key == "back" or key == "volumeUp" or key == "volumeDown" then
		if event.phase == "down" then
			if key == "back" then
				scenes.Send("message:wants_to_go_back")
			else
				-- VOLUME
			end
		end

		return true
	end
end)

-- "unhandledError" listener --
if system.getInfo("environment") == "device" then
	Runtime:addEventListener("unhandledError", function(event)
		native.showAlert("Error!", event.errorMessage .. " \n " .. event.stackTrace, { "OK" }, native.requestExit)
	end)
end

--- Helper to deal with circular module require situations. Provided module access is not
-- needed immediately (in particular, it can wait until the requiring module has loaded),
-- the lazy-required module looks and may be treated as a normal module.
-- @string name Module name, as passed to @{require}.
-- @treturn table Module proxy, to be accessed like the module proper.
function lazy_require (name)
	local mod

	return setmetatable({}, {
		__index = function(_, k)
			mod = mod or require(name)

			return mod[k]
		end
	})
end

--- Helper to print formatted argument.
-- @string s Format string.
-- @param ... Format arguments.
function printf (s, ...)
	print(s:format(...))
end

-- Install printf as the default var dump routine.
var_dump.SetDefaultOutf(printf)

--- DOCME
function require_list (name)
	local from = require(name)
	local prefix, list = from._prefix, {}

	prefix = prefix and prefix .. "." or ""

	for k, v in pairs(from) do
		if k ~= "_prefix" then
			list[k] = require(prefix .. v)
		end
	end

	return list
end

-- Checks for vdump --
local Checks

--- Helper to dump generic variable.
-- @param var Variable to dump.
-- @param name If provided, the dump will check if it has been called with this name
-- before; if _limit_ has been reached, dumps will be ignored.
-- @uint limit Maximum number of times to allow a dump with _name_; if absent, 1.
function vdump (var, name, limit)
	if name then
		Checks = Checks or {}

		local check = Checks[name] or 0

		if check >= (limit or 1) then
			return
		else
			Checks[name] = check + 1
		end
	end

	var_dump.Print(var)
end

-- Kick off the app.
scenes.GoToScene{ name = "scene.Intro" }