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
--[=[
local convolve = require("number_ops.convolve")
M=convolve
print("Linear")
vdump(convolve.Convolve_1D({1,2,1},{1,2,3}))
print("Circular")
vdump(convolve.CircularConvolve_1D({1,2,1},{1,2,3}))
print("FFT")
vdump(convolve.Convolve_FFT1D({1,2,1},{1,2,3},{method="goertzel2"}))

-- Referring to:
-- http://www.songho.ca/dsp/convolution/convolution2d_example.html
-- http://www.johnloomis.org/ece563/notes/filter/conv/convolution.html
vdump(convolve.Convolve_2D({1,2,3,4,5,6,7,8,9}, {-1,-2,-1,0,0,0,1,2,1}, 3, 3, "same"))

local A, B, W, H = {17,24,1,8,15,
					23,5,7,14,16,
					4,6,13,20,22,
					10,12,19,21,3,
					11,18,25,2,9 }, {1,3,1,0,5,0,2,1,2}, 5, 3
local t1 = convolve.Convolve_2D(A, B, W, H)
-- From a paper...
vdump(M.CircularConvolve_2D({1,0,2,1}, {1,0,1,1}, 2,2))
-- Contrast to http://www.mathworks.com/matlabcentral/answers/100887-how-do-i-apply-a-2d-circular-convolution-without-zero-padding-in-matlab
-- but that seems to use a different padding strategy...

local t2 = M.Convolve_FFT2D(A, B, W, H, { method = "two_ffts" })
local t3 = M.Convolve_FFT2D(A, B, W, H, { method = "goertzel" })
local t4 = M.Convolve_FFT2D(A, B, W, H) -- separate fft's

print("COMPARING 2D convolve operations")
for i = 1, #t1 do
	if math.abs(t1[i] - t2[i]) > 1e-6 then
		print("Problem (method = Two FFT's) at: " .. i)
	end
	if math.abs(t3[i] - t2[i]) > 1e-6 then
		print("Problem (method = Goertzels) at: " .. i)
	end
	if math.abs(t4[i] - t2[i]) > 1e-6 then
		print("Problem (method = Separate FFT's) at: " .. i)
	end
end
print("DONE")
local w={1,1,1,1,0,0,0,0}
require("number_ops.fft").FFT_Real1D(w, 8)
vdump(w)
--]=]
-- Kick off the app.
scenes.GoToScene{ name = "scene.Intro" }