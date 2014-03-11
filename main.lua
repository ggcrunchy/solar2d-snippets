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
local setmetatable = setmetatable

-- Modules --
local debug = require("debug")
local device = require("utils.Device")
local errors = require("tektite.errors")
local flow_bodies = require("coroutine_ops.flow_bodies")
local frames = require("utils.Frames")
local per_coroutine = require("coroutine_ops.per_coroutine")
local scenes = require("utils.Scenes")
local var_dump = require("var_ops.dump")

-- Corona globals --
local native = native
local system = system

-- Install the coroutine time logic.
flow_bodies.SetTimeLapseFuncs(per_coroutine.TimeLapse(frames.DiffTime, frames.GetFrameID))

-- Use standard tracebacks.
errors.SetTracebackFunc(debug.traceback)

-- Are we running on device? --
local OnDevice = system.getInfo("environment") == "device"

-- Install environment-limited events, if possible.
if system.getInfo("platformName") == "Android" or not OnDevice then
	-- Handler helper
	local function Handles (what)
		what = "message:handles_" .. what

		return function(event)
			if scenes.Send(what, event) then
				return true
			end
		end
	end

	-- Device-only events.
	if OnDevice then
		-- "axis" listener --
		Runtime:addEventListener("axis", Handles("axis"))

		-- "system" listener --
		Runtime:addEventListener("system", function(event)
			if event.type == "applicationStart" or event.type == "applicationResume" then
				device.EnumerateDevices()
			end
		end)
	end

	-- "key" listener --
	local HandleKey = Handles("key")

	Runtime:addEventListener("key", function(event)
		if HandleKey(event) then
			return true
		else
			local key = event.keyName
			local go_back = key == "back" or key == "deleteBack"

			if go_back or key == "volumeUp" or key == "volumeDown" then
				if event.phase == "down" then
					if go_back then
						scenes.WantsToGoBack()
					else
						-- VOLUME
					end
				end

				return true
			end
		end
	end)
end

-- "unhandledError" listener --
if OnDevice then
	Runtime:addEventListener("unhandledError", function(event)
		native.showAlert("Error!", event.errorMessage .. " \n " .. event.stackTrace, { "OK" }, native.requestExit)
	end)
end

--- Helper to print formatted argument.
-- @string s Format string.
-- @param ... Format arguments.
function printf (s, ...)
	print(s:format(...))
end

-- Install printf as the default var dump routine.
var_dump.SetDefaultOutf(printf)

--- Helper to dump generic variable.
-- @param var Variable to dump.
-- @param name As per @{var_ops.dump.Print}.
-- @uint limit As per @{var_ops.dump.Print}.
function vdump (var, name, limit)
	var_dump.Print(var, name and { name = name, limit = limit })
end
local mf=require("graph_ops.flow")
-- A = { b = 3, d = 3 } -> 1 = 2, 4
-- B = { c = 4 } -> 2 = 3
-- C = { a = 3, d = 1, e = 2 } -> 3 = 1, 4, 5
-- D = { e = 2, f = 6 } -> 4 = 5, 6
-- E = { b = 1, g = 1 } -> 5 = 2, 7
-- F = { g = 9 } -> 6 = 7
-- G = "SINK"
-- Source = a, sink = g
--[[
local a, b = mf.MaxFlow ({
	1, 2, 3, 1, 4, 3,
	2, 3, 4,
	3, 1, 3, 3, 4, 1, 3, 5, 2,
	4, 5, 2, 4, 6, 6,
	5, 2, 1, 5, 7, 1,
	6, 7, 9
}, 1, 7)
]]
--[[
local a, b = mf.MaxFlow_Labels ({
	a = { b = 3, d = 3 },
	b = { c = 4 },
	c = { a = 3, d = 1, e = 2 },
	d = { e = 2, f = 6 },
	e = { b = 1, g = 1 },
	f = { g = 9 }
}, "a", "g")
print("Max flow = " .. tostring(a))
vdump(b)
]]
--require("number_ops.convolve")
-- Kick off the app.
scenes.GoToScene{ name = "scene.Intro" }