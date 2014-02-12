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
local setmetatable = setmetatable
local type = type

-- Modules --
local color = require("ui.Color")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Get the wrapped object
local function Object (line)
	return rawget(line, "m_object")
end

-- Is the object a true line?
local function IsLine (object)
	return object.m_x0
end

-- --
local LineMethods = {}

--- DOCME
function LineMethods:append (x, y)
	local object = Object(self)

	-- Already a true line: append points the normal way.
	if IsLine(object) then
		object:append(x, y)

	-- Pseudo-line, one point: given the new point, convert to a true line.
	elseif object.m_x then
		local group, index = object.parent

		-- Find the dummy's spot.
		for i = 1, group.numChildren do
			if group[i] == object then
				index = i

				break
			end
		end

		-- Create a line object and put it where the dummy is.
		local line = display.newLine(group, object.m_x, object.m_y, x, y)

		group:insert(line, index)

		-- Carry over any values (in particular, commit properties) to the line object.
		for k, v in pairs(self) do
			if k ~= "m_object" then
				line[k] = v
			end
		end

		-- Commit any color assigned to the pseudo-line.
		color.SetStrokeColor(line, object)

		-- Retain the first point (for any close() operation, and doing double duty as an
		-- "is line" predicate). Assign the line object and evict the dummy.
		line.m_x0, line.m_y0 = object.m_x, object.m_y

		rawset(self, "m_object", line)

		object:removeSelf()

	-- Pseudo-line, no points yet: stash a first point in the dummy object.
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
function LineMethods:setStrokeColor (...)
	local object = Object(self)

	if IsLine(object) then
		object:setStrokeColor(...)
	else
		color.PackColor(object, ...)
	end
end

-- Members that true lines assume remain intact --
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
	-- If the first argument is not a group, use the stage. Move number arguments, if any,
	-- into their expected variables.
	if group == nil or type(group) == "number" then 
		if group ~= nil then
			x1, y1, x2, y2 = group, x1, y1, x2
		end

		group = display.getCurrentStage()
	end

	-- If there is a second pair of numbers, just create a line the normal way.
	if x2 then
		return display.newLine(group, x1, y1, x2, y2), false

	-- Otherwise, stuff a dummy into the group to hold its spot, add a first pair of numbers
	-- if requested, and return the wrapped-up object.
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