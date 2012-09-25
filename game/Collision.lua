--- This module wraps up some useful collision functionality.

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
local assert = assert

-- Modules --
local dispatch_list = require("game.DispatchList")
local iterators = require("iterators")
local table_ops = require("table_ops")
local timers = require("game.Timers")
local utils = require("utils")

-- Corona globals --
local display = display

-- Corona modules --
local physics = require("physics")

-- Exports --
local M = {}

-- Collision handlers --
local Handlers = {}

--- Activate or deactivate of a physics object, via a 0-lapse timer.
-- @pobject object Physics object.
-- @bool active Activate? Otherwise, deactivate.
-- @return (0-lapse) timer handle.
function M.Activate (object, active)
	return timers.Defer(function()
		object.isBodyActive = active
	end)
end

--- Defines a collision handler for objects of a given collision type with other objects.
--
-- When two objects collide, each is checked for a handler. Each handler that exists is
-- called as
--    handler(phase, object, other, other_type),
-- where _phase_ is **"began"** or **"ended"**, _object_ is what supplied _handler_, _other_
-- is what collided with _object_, and _other_type_ is the collision type of _other_ (may be
-- **nil**).
--
-- The collision type of _object_ is not supplied, being implicit in the handler itself. For
-- all practical purposes, _type_ is just a convenient name for _func_; there is no real
-- reason to assign a handler to more than one type.
-- @param type Type of object that will use this handler, as assigned by @{SetType}.
-- @callable func Handler function, or **nil** to remove the handler.
function M.AddHandler (type, func)
	Handlers[type] = func
end

-- --
local BorderBody

-- Helper to build up a border
local function BorderRect (group, x, y, w, h)
	BorderBody = BorderBody or { filter = { categoryBits = M.FilterBits("border"), maskBits = 0xFFFF } }

	local rect = display.newRect(group, x, y, w, h)

	M.MakeSensor(rect, "static", BorderBody)
	M.SetType(rect, "border")

	rect.isVisible = false
end

--- Builds some invisible rectangles around a rectangular interior region. This is convenient
-- e.g. for detecting objects leaving the level boundaries.
--
-- These rectangles will have static, sensor bodies, with collision type **"border"**.
-- @pgroup group Display group that will hold border rectangles.
-- @number x Interior region, upper-left x-coordinate.
-- @number y Interior region, upper-left y-coordinate.
-- @number w Interior region width.
-- @number h Interior region height.
-- @number rdim One of the dimensions of each border rectangle: for rectangles mostly
-- to the left or right of the interior region, this will be the width; for the rest mostly
-- above or below, the height. The other dimension may then be deduced via a heuristic.
-- @tparam number sep Minimum separation distance away from sides of the interior rectangle
-- that border rectangles must honor; if absent, 0.
-- @see GetType
function M.Border (group, x, y, w, h, rdim, sep)
	sep = sep or 0

	local bdim = rdim + sep
	local xl, xr = x - bdim, x + w + sep
	local yt, yb = y - bdim, y + h + sep
	local bw, bh = xr - xl + rdim, yb - yt + rdim

	BorderRect(group, xl, yt, bw, rdim)
	BorderRect(group, xl, y, rdim, bh)
	BorderRect(group, xr, y, rdim, bh)
	BorderRect(group, xl, yb, bw, rdim)
end

-- Next mask to allocate --
local Mask = 0x1

-- Lazily named filter flags --
local NamedFlags = setmetatable({}, {
	__index = function(t, k)
		assert(Mask < 0xFFFF, "Limit of 16 named flags")

		t[k], Mask = Mask, Mask + Mask

		return t[k]
	end
})

--- Convenience routine used to build bitmasks for **categoryBits** and **maskBits** filter
-- fields, using friendly names instead of magic numbers.
--
-- When a name is used for the first time, it is mapped to the next available flag. There
-- is a hard limit of 16 names, per the physics API.
--
-- These names are in a separate namespace from collision types, i.e. they need not match,
-- though there is likely to be some crossover in practice, e.g. for clarity.
-- @param ... Names of filter bits to combine. Duplicate and **nil** names are ignored.
-- @treturn uint The boolean union of filter bits, or 0 if none were assigned.
function M.FilterBits (...)
	local bits = 0

	for _, name in iterators.Args(...) do
		if name ~= nil then
			bits = utils.SetFlag(bits, NamedFlags[name])
		end
	end

	return bits
end

-- Types used to manage physics interactions --
local Types = table_ops.Weak("k")

---@param object Object to query.
-- @return Collision type of _object_, or **nil** if absent.
-- @see SetType
function M.GetType (object)
	return Types[object]
end

--- Assigns a sensor body to an object.
-- @pobject object Object to make into a sensor.
-- @string body_type Physics body type, or **"dynamic"** by default.
-- @ptable props Optional properties.
function M.MakeSensor (object, body_type, props)
	physics.addBody(object, body_type or "dynamic", props)

	object.isSensor = true
end

---@number dx Incident vector x-component...
-- @number dy ...and y-component.
-- @number nx Normal x-component...
-- @number ny ...and y-component.
-- @treturn number Reflected vector x-component...
-- @treturn number ...and y-component.
function M.Reflect (dx, dy, nx, ny)
	local scale = 2 * (dx * nx + dy * ny) / (nx * nx + ny * ny)

	return dx - scale * nx, dy - scale * ny
end

--- Associates a collision type with _object_. This is used to choose _object_'s handler in
-- the event of a collision, and will also be provided (as a convenience) to the other
-- object's handler.
-- @param object Object to type.
-- @param type Type to assign, or **nil** to untype _object_.
-- @see AddHandler, GetType
function M.SetType (object, type)
	Types[object] = type
end

-- "collision" listener --
Runtime:addEventListener("collision", function(event)
	local o1, o2 = event.object1, event.object2
	local t1, t2 = Types[o1], Types[o2]
	local h1, h2 = Handlers[t1], Handlers[t2]

	if h1 then
		h1(event.phase, o1, o2, t2)
	end

	if h2 then
		h2(event.phase, o2, o1, t1)
	end
end)

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Things Loaded --
	things_loaded = function(level)
		-- Add a "net" around the level to deal with things that fly away.
		M.Border(level.things_layer, 0, 0, level.ncols * level.w, level.nrows * level.h, 500, 150)
	end
}

-- Kick off physics, sans gravity.
physics.start()
physics.setGravity(0, 0)

-- Export the module.
return M