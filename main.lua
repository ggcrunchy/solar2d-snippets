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

-- Corona hack
if not OnDevice then
	native.setActivityIndicator(false)
end
-- /Corona hack

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
package.loaded.bit = require("plugin.bit")
local bb=package.loaded.bit
local ii = 63
local i1=bb.lshift(1,ii)
local i2=2^bb.band(ii,0x1F)
print(bb.band(0xFFFFFFFF,bb.bnot(i1)))
print(bb.band(0xFFFFFFFF,bb.bnot(i2)))
--2^band(i, 0x1F)
--[===[
local ops = require("bitwise_ops.operators")
	-- --
	local DeBruijnLg = {
		0, 1, 28, 2, 29, 14, 24, 3, 30, 22, 20, 15, 25, 17, 4, 8,
		31, 27, 13, 23, 21, 19, 16, 7, 26, 12, 18, 6, 11, 5, 10, 9
	}
	-- band(x,-x), Lg
	local a = 0x80000000
	local c = 0x00004000
	local d = ops.bor(a, c)
--[[
r = MultiplyDeBruijnBitPosition2[(uint32_t)(v * 0x077CB531U) >> 27];
]]
local log=require("bitwise_ops.log2")
	local dd = ops.band(d, -d)
	local aa = DeBruijnLg[ops.rshift(dd * 0x077CB531, 27) + 1]
	print(dd, aa)
	local ee = ops.band(c, -c)
	local bb = DeBruijnLg[ops.rshift(ee * 0x077CB531, 27) + 1]
	print(ee, bb)
	local ff = ops.band(a, -a)
	print(2^31, ops.rshift(ff,31))
	print(ff==-2^31)
	local cc = log.Lg_PowerOf2(math.abs(ff))--DeBruijnLg[ops.rshift(ops.band(ff) * 0x077CB531, 27) + 1]	
	print(ff, cc)
local abs=math.abs
local Lg_PowerOf2 = log.Lg_PowerOf2
local band=ops.band
local bxor=ops.bxor
local coff=0
	local function ARG (cbits)
		print("ARG!", cbits)
		while cbits ~= 0 do
			local cbit = (band(cbits, -cbits))
			local col = coff + Lg_PowerOf2(abs(cbit))

			print(cbits, cbit, col)

			cbits = bxor(cbits, cbit)
		end
		print("")
	end

	ARG(ops.bor(0x80000000, 0xA10003F0))
	ARG(0x00003210)
	ARG(0x10003001)
	
	
	print("MOOGA!")
	print("")
	
	
		--
	local function AuxPowers (_, bits)
		if bits ~= 0 then
			local bit = band(bits, -bits)

			return bxor(bits, bit), bit > 0 and Lg_PowerOf2(bit) or 31--abs(bit))
		end
	end

	--
	local function Powers (bits)
		return AuxPowers, false, bits
	end

	for _, power in Powers(ops.bor(0x80000000, 0xA10003F0)) do
		print("POWER", power)
	end
	print("")
	for _, power in Powers(0x00003210) do
		print("POWER", power)
	end
	print("")
	for _, power in Powers(0x10003001) do
		print("POWER", power)
	end
	print("")

--[=[
					while cbits ~= 0 do
						local cbit = --[[abs]] (band(cbits, -cbits))
						local col = coff + Lg_PowerOf2(abs(cbit))
						local cost = Costs[ri + col]

						if cost < vmin then
							if cost == 0 then
								if not AA or AA < 5 then
									AA = (AA or 0) + 1
									print(i, j, roff, rbit, coff, cbit)
									print(ri, col)
								print("")
								end
								return ri, col
							else
								vmin = cost
							end
						end

						cbits = bxor(cbits, cbit)--cbits - cbit
]=]
---]===]
-- Kick off the app.
scenes.GoToScene{ name = "scene.Intro" }