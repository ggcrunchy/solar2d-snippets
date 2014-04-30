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

--- Helper to dump generic variable, with integer values in hex.
-- @param var Variable to dump.
-- @param name As per @{var_ops.dump.Print}.
-- @uint limit As per @{var_ops.dump.Print}.
function vdumpx (var, name, limit)
	var_dump.Print(var, { hex_uints = true, name = name, limit = limit })
end

package.loaded.bit = require("plugin.bit")
--[=[
local bb=package.loaded.bit

local band=bb.band
local bnot=bb.bnot
local bor=bb.bor
local bxor=bb.bxor
local lshift=bb.lshift
local rshift=bb.rshift

function AuxInit (n, clear)
	return rshift(n, 5), band(n, 0x1F), 32
end

function Init (arr, n, clear)
	local mask, nblocks, tail, power = 0, AuxInit(n, clear)

	if tail > 0 then
		nblocks, mask = nblocks + 1, 2^tail - 1
	end

	local fill = clear and 0 or 2^power - 1

	for i = 1, nblocks do
		arr[i] = fill
	end

	if mask ~= 0 and not clear then
		arr[nblocks] = mask
	end

	arr.n, arr.mask = nblocks, mask
end

local function AuxGet (out, bits, ri, wi)
	--
--	bits=math.abs(bits)
	local j = wi + 1

	while bits ~= 0 do
		local _, e = math.frexp(bits)
		local pos = e - 1

		out[j], j, bits = ri + pos, j + 1, bits - 2^pos
	end

	--
	local l, r = wi + 1, j

	while l < r do
		r = r - 1

		out[l], out[r], l = out[r], out[l], l + 1
	end

	return j - 1
end

function GetIndices_Clear (out, from)
	local count, offset, n, mask = 0, 0, from.n, from.mask

	if mask ~= 0 then
		n = n - 1
	end

	for i = 1, n do
		local bits = bnot(from[i])

		if bits < 0 then
			bits = bits + 2^32
		end

		count, offset = AuxGet(out, bits, offset, count), offset + 32
	end

	if mask ~= 0 then
		count = AuxGet(out, band(bnot(from[n + 1]), mask), offset, count)
	end

	return count
end

function GetIndices_Set (out, from)
	local count, offset = 0, 0

	for i = 1, from.n do
		local bits = from[i]

		if bits < 0 then
			bits = bits + 2^32
		end

		count, offset = AuxGet(out, bits, offset, count), offset + 32
	end

	return count
end

	function AuxAllSet (arr, n)
		local bits = arr[1]

		for i = 2, n do
			bits = band(arr[i], bits)
		end

		return bxor(bits, 0xFFFFFFFF) == 0
	end

function AllSet (arr)
	local n, mask = arr.n, arr.mask

	if mask ~= 0 then
		if mask ~= arr[n] then -- In bitwise version, mask less than 2^31
			return false
		end

		n = n - 1
	end

	return AuxAllSet(arr, n)
end

function Clear (arr, index)
	local slot, bit = rshift(index, 5) + 1, lshift(1, index)
	local old = arr[slot]
	--[[
	local new = band(old, bnot(bit))

	if new < 0 then
		new = new + 2^32
	end
]]
	arr[slot] = band(old, bnot(bit))--new

	return band(old, bit) ~= 0--old ~= new
end

function Set (arr, index)
	local slot, bit = rshift(index, 5) + 1, lshift(1, index)
	local old = arr[slot]
--[[
	local new = bor(old, bit)

	if new < 0 then
		new = new + 2^32
	end
]]
	arr[slot] = bor(old, bit)--new

	return band(old, bit) == 0--old ~= new
end

local AA={}

Init(AA, 33)

local function VDUMP (out)
	vdumpx(out)
	for i = #out, 1, -1 do
		out[i] = nil
	end
end

vdumpx(AA)
print("ALL SET?", AllSet(AA))
local out={}
print("GET # SET", GetIndices_Set(out, AA))
VDUMP(out)
print("SET?", Set(AA, 3))
print("ALL SET?", AllSet(AA))
print("GET # SET", GetIndices_Set(out, AA))
VDUMP(out)
print("GET # CLEARED", GetIndices_Clear(out, AA))
VDUMP(out)
print("CLEAR?", Clear(AA, 13))
print("ALL SET?", AllSet(AA))
print("GET # SET", GetIndices_Set(out, AA))
VDUMP(out)
print("GET # CLEARED", GetIndices_Clear(out, AA))
VDUMP(out)
print("CLEAR?", Clear(AA, 32))
print("GET # SET", GetIndices_Set(out, AA))
VDUMP(out)
print("GET # CLEARED", GetIndices_Clear(out, AA))
VDUMP(out)
print("CLEAR?", Clear(AA, 31))
print("GET # SET", GetIndices_Set(out, AA))
VDUMP(out)
print("GET # CLEARED", GetIndices_Clear(out, AA))
VDUMP(out)
print("SET?", Set(AA, 31))
print("GET # SET", GetIndices_Set(out, AA))
VDUMP(out)
print("GET # CLEARED", GetIndices_Clear(out, AA))
VDUMP(out)
--]=]
--[=[
-- Cached logarithm --
local Lg2 = math.log(2)

--- DOCME
-- "Simple code in Python" from Hacker's Delight
function MagicGU (nmax, d)
	local nc, two_p = math.floor(nmax / d) * d - 1, 1
	local nbits = math.floor(math.log(nmax) / Lg2) + 1

	for p = 0, 2 * nbits + 1 do
		local q = d - 1 - (two_p - 1) % d

		if two_p > nc * q then
			local m = math.floor((two_p + q) / d)

			return m, p
		end

		two_p = two_p + two_p
	end
end

local M, P = 1,0

local list = {}
local N=1e7
for i = 1, N do--2048 do
	local m, p = MagicGU(i, 53)
	if m ~= M or p ~= P then
		print("As of", i - 1, m, p)
		M, P = m, p
		list[#list+1]=M
		list[#list+1]=P
		list[#list+1]=i - 1
	end
end

for i = 1, #list, 3 do
	local m, p, start, next = list[i], list[i + 1], list[i + 2], list[i + 5] or N--2048
	local k = m * 2^-p
	if i == 1 then
		start = 0
	end
	print("m, p", m, p, start, next - 1)
	for j = start, next - 1 do
		if j % 53 ~= j - math.floor(j * k) * 53 then
			print("SHUCKS :(", j)
			break
		end
	end
	print("YEAH!")
end
--]=]
--[=[
local K = 39 * 2^-11
print(57 % 53, 57 - math.floor(57 * K) * 53)
print((57 - 4) * K)

for i = 0, 105 do
	local pos = i % 53
	local slot = (i - pos) / 53 + 1
	local jj = math.floor(i * K)
	local SLOT = jj + 1
	local POS = i - jj * 53
	print(slot==SLOT, pos==POS)
end
--]=]
--[[
local div = require("number_ops.divide")
local m = div.GenerateUnsignedConstants(105, 53, true)
for i = 0, 105 do
	local a, b = div.DivRem(i, 53)
	local c, d = div.DivRem_Magic(i, 53, m)
	print(a==c, b==d)
end
--]]
-- Kick off the app.
scenes.GoToScene{ name = "scene.Intro" }