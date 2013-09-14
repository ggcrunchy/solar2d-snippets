--- Augmented version of Corona's line object.

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
local rawget = rawget
local rawset = rawset
local select = select
local setmetatable = setmetatable
local type = type
local unpack = unpack

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Color = {}

--
local function Object (line)
	return rawget(line, "m_object")
end

--
local function IsLine (object)
	return object.m_x0
end

-- --
local LineMethods = {}

--- DOCME
function LineMethods:append (x, y)
	local object = Object(self)

	--
	if IsLine(object) then
		object:append(x, y)

	--
	elseif object.m_x then
		local group, index = object.parent

		--
		for i = 1, group.numChildren do
			if group[i] == object then
				index = i

				break
			end
		end

		--
		local line = display.newLine(group, object.m_x, object.m_y, x, y)

		group:insert(line, index)

		--
		for k, v in pairs(self) do
			if k ~= "m_object" then
				line[k] = v
			end
		end

		--
		if object.m_ncomps then
			Color[1], Color[2], Color[3], Color[4] = object.m_r, object.m_g, object.m_b, object.m_a

			line:setColor(unpack(Color, 1, object.m_ncomps))

			Color[1], Color[2], Color[3], Color[4] = nil
		end

		--
		line.m_x0, line.m_y0 = object.m_x, object.m_y

		rawset(self, "m_object", line)

		object:removeSelf()

	--
	else
		object.m_x, object.m_y = x, y
	end
end

--- DOCME
function LineMethods:close ()
	local object = Object(self)

	if IsLine(object) then
		object:append(object.m_x0, object.m_y0)
	end
end

--- DOCME
function LineMethods:removeSelf ()
	Object(self):removeSelf()
end

--- DOCME
function LineMethods:setColor (...)
	local n, object = select("#", ...), Object(self)

	if IsLine(object) then
		object:setColor(...)
	elseif n > 0 then
		object.m_r, object.m_g, object.m_b, object.m_a = ...
		object.m_ncomps = n
	else
		object.m_ncomps = nil
	end
end

-- --
local Protected = { m_x0 = true, m_y0 = true }

-- --
local LineMT = {
	__index = function(t, k)
		local method = LineMethods[k]

		if method then
			return method
		else
			local object = Object(t)

			if IsLine(object) then
				return object[k]
			else
				return rawget(t, k)
			end
		end
	end,

	__newindex = function(t, k, v)
		if not LineMethods[k] then
			local object = Object(t)

			if IsLine(object) then
				if not Protected[k] then
					object[k] = v
				end
			elseif k ~= "m_object" then
				rawset(t, k, v)
			end
		end
	end
}

--- DOCME
function M.NewLine (group, x1, y1, x2, y2)
	--
	if group == nil or type(group) == "number" then 
		if group ~= nil then
			x1, y1, x2, y2 = group, x1, y1, x2
		end

		group = display.getCurrentStage()
	end

	--
	if x2 then
		return display.newLine(group, x1, y1, x2, y2), false

	--
	else
		local object = display.newCircle(group, 0, 0, 0)
		local wrapper = setmetatable({ m_object = object }, LineMT)

		if x1 then
			LineMethods.append(wrapper, x1, y1)
		end

		object.isVisible = false

		return wrapper, true
	end
end

-- Export the module.
return M