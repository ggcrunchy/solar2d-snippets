--- Various workarounds.

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

-- Exports --
local M = {}

local rawset = rawset
local select = select
local setmetatable = setmetatable
local unpack = unpack

--
local LineMT = {
	__newindex = function(line, k, v)
		if k == "strokeWidth" then
			for i = 1, #line do
				line[i].strokeWidth = v
			end

			rawset(line, "_sw", v)
		else
			rawset(line, k, v)
		end
	end
}

--
local Temp = {}

--
local function Append (line, x, y)
	local npieces, n, points = #line, line.n, line.points

	if n < 50 then
		if npieces > 0 then
			display.remove(line[npieces])
		else
			npieces = 1
		end

		points[n + 1], points[n + 2], n = x, y, n + 2
	else
		points[1], points[2] = points[49], points[50]
		points[3], points[4] = x, y
		npieces, n = npieces + 1, 4
	end

	line.n = n
 
	if n > 2 then
		local part = display.newLine(line.group, points[1], points[2], points[3], points[4])

		if n > 4 then
			part:append(unpack(points, 5, n))
		end

		line[npieces] = part

		part.strokeWidth = line._sw or 1

		if line._n and line._n > 0 then
			Temp[1], Temp[2], Temp[3], Temp[4] = line._r, line._g, line._b, line._a

			part:setStrokeColor(unpack(Temp, 1, line._n))
		end
	end
end

--
local function RemoveSelf (line)
	for i = 1, #line do
		line[i]:removeSelf()
	end
end

--
local function SetStrokeColor (line, ...)
	for i = 1, #line do
		line[i]:setStrokeColor(...)
	end

	local n = select("#", ...)
	local r, g, b, a = ...

	rawset(line, "_n", n)
	rawset(line, "_r", r)
	rawset(line, "_g", g)
	rawset(line, "_b", b)
	rawset(line, "_a", a)
end

--- DOCMENO
function M.LineShim (group, x1, y1, x2, y2)
	local shim = { group = group, points = {}, n = 0 }

	shim.append = Append
	shim.removeSelf = RemoveSelf
	shim.setStrokeColor = SetStrokeColor

	if x1 then
		shim:append(x1, y1)

		if x2 then
			shim:append(x2, y2)
		end
	end

	return setmetatable(shim, LineMT)
end

-- Export the module.
return M