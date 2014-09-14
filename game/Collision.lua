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
local adaptive = require("table_ops.adaptive")
local args = require("iterator_ops.args")
local powers_of_2 = require("bitwise_ops.powers_of_2")
local timers = require("game.Timers")

-- Corona globals --
local display = display

-- Corona modules --
local physics = require("physics")

-- Exports --
local M = {}

--- Activate or deactivate of a physics object, via a 0-lapse timer.
-- @pobject object Physics object.
-- @bool active Activate? Otherwise, deactivate.
-- @return (0-lapse) timer handle.
function M.Activate (object, active)
	return timers.Defer(function()
		object.isBodyActive = active
	end)
end

-- Collision handlers --
local Handlers = {}

--- Defines a collision handler for objects of a given collision type with other objects.
--
-- When two objects collide, each is checked for a handler. Each handler that exists is
-- called as
--    handler(phase, object, other, other_type, contact)
-- where _phase_ is **"began"** or **"ended"**, _object_ is what supplied _handler_, _other_
-- is what collided with _object_, _other_type_ is the collision type of _other_ (may be
-- **nil**), and _contact_ is the physics object passed via the event.
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
local InterfacePreds, Interfaces = {}, {}

--- DOCME
function M.AddInterfaces (type, ...)
	for _, v in args.Args(...) do
		adaptive.AddToSet(Interfaces, type, v)
	end
end

--- DOCME
function M.AddInterfaces_Pred (type, ...)
	local preds = InterfacePreds[type] or {}

	for _, what, pred in args.ArgsByN(2, ...) do
		adaptive.AddToSet(Interfaces, type, what)

		preds[what] = pred
	end

	InterfacePreds[type] = preds
end

-- --
local BorderBody

-- Helper to build up a border
local function BorderRect (group, x, y, w, h)
	BorderBody = BorderBody or { filter = { categoryBits = M.FilterBits("border"), maskBits = 0xFFFF } }

	local rect = display.newRect(group, x, y, w, h)

	rect:translate(w / 2, h / 2)

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

-- --
local IsHidden

-- --
local Partners

--
local function Find (list, object)
	for i = 1, #(list or ""), 2 do
		if list[i] == object then
			return i, list
		end
	end

	return nil, list
end

--
local function RemoveFrom (object, other, index)
	local list = index and other or Partners[other]
	local i, n = index or Find(list, object), #list

	list[i], list[i + 1] = list[n - 1], list[n]
	list[n], list[n - 1] = nil
end

--
local function Cleanup (object)
	if not object.parent then
		local list = Partners[object]

		for i = 1, #(list or ""), 2 do
			RemoveFrom(object, list[i])
		end

		Partners[object] = nil
	end
end

--
local function DefAction () end

--
local function AddToList (object, other, func)
	local index, list = Find(Partners[object] or {}, other)

	if not index then
		list[#list + 1] = other
		list[#list + 1] = func
	elseif list[index + 1] == DefAction then
		list[index + 1] = func
	end

	Partners[object] = list
end

-- Types used to manage physics interactions --
local Types = setmetatable({}, { __mode = "k" })

--- DOCME
function M.DoOrDefer (object, other, phase, func)
	local intact = object.parent and other.parent

	-- Phase "began", objects intact: if at least one of the objects is hidden, defer the
	-- action; otherwise, perform it immediately.
	if intact and phase == "began" then
		if IsHidden[object] or IsHidden[other] then
			AddToList(object, other, func)
			AddToList(other, object, DefAction)
		else
			func(object, other, Types[other])
		end

	-- Phase "ended", objects intact: break pairings.
	elseif intact then
		-- TODO: what should `list' be??? (Partners[object], I think... but I forgot; will have to finally attend to this soon)
		for i = #(list or "") - 1, 1, -2 do
			RemoveFrom(object, list[i])
		end

	-- One or both objects dead: break pairings and remove dead objects.
	else
		Cleanup(object)
		Cleanup(other)
	end
end

-- Next mask to allocate --
local Mask = 0x1

-- Lazily named filter flags --
local NamedFlags = setmetatable({}, {
	__index = function(t, k)
		assert(Mask < 0xFFFF, "Limit of 16 named flags")

		t[k], Mask = Mask, 2 * Mask

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

	for _, name in args.Args(...) do
		if name ~= nil then
			bits = powers_of_2.Set(bits, NamedFlags[name])
		end
	end

	return bits
end

--- Getter.
-- @param object Object to query.
-- @return Collision type of _object_, or **nil** if absent.
-- @see SetType
function M.GetType (object)
	return Types[object]
end

--- DOCME
function M.Implements (object, what)
	return adaptive.InSet(Interfaces[Types[object]], what)
end

--- DOCME
function M.Implements_Pred (object, what, def, ...)
	local type = Types[object]
	local implements = adaptive.InSet(Interfaces[type], what)

	if implements then
		local preds = InterfacePreds[type]
		local func = preds and preds[what]

		if func then
			return func(...) and "passed" or "failed"
		else
			return "no_predicate"
		end
	end

	return "does_not_implement"
end

--- Predicate.
-- @pobject object Object to poll about visibility.
-- @treturn boolean Is _object_ visible?
-- @see SetVisibility
function M.IsVisible (object)
	return not IsHidden[object]
end

--- Assigns a sensor body to an object.
-- @pobject object Object to make into a sensor.
-- @string body_type Physics body type, or **"dynamic"** by default.
-- @ptable props Optional properties.
function M.MakeSensor (object, body_type, props)
	physics.addBody(object, body_type or "dynamic", props)

	object.isSensor = true
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

--- DOCME
function M.SetVisibility (object, show)
	--
	if object.parent then
		if IsHidden[object] and show then
			local list1, t1 = Partners[object], Types[object]

			for i = #(list1 or "") - 1, 1, -2 do
				local other = list1[i]

				if other.parent and not IsHidden[other] then
					local t2, j, list2 = Types[other], Find(Partners[other], object)

					list1[i + 1](object, other, t2)
					list2[j + 1](other, object, t1)

					RemoveFrom(nil, list1, i)
					RemoveFrom(nil, list2, j)
				end
			end
		end

		IsHidden[object] = not show

	--
	else
		Cleanup(object)
	end
end

-- Enter Level response
local function EnterLevel ()
	IsHidden, Partners = {}, {}
end

-- Listen to events.
for k, v in pairs{
	-- Collision --
	collision = function(event)
		local o1, o2 = event.object1, event.object2
		local t1, t2 = Types[o1], Types[o2]
		local h1, h2 = Handlers[t1], Handlers[t2]
		local phase, contact = event.phase, event.contact

		if h1 then
			h1(phase, o1, o2, t2, contact)
		end

		if h2 then
			h2(phase, o2, o1, t1, contact)
		end
	end,

	-- Enter Level --
	enter_level = EnterLevel,

	-- Leave Level --
	leave_level = function()
		IsHidden, Partners = nil
	end,

	-- Reset Level --
	reset_level = EnterLevel,

	-- Things Loaded --
	things_loaded = function(level)
		-- Add a "net" around the level to deal with things that fly away.
		M.Border(level.things_layer, 0, 0, level.ncols * level.w, level.nrows * level.h, 500, 150)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Kick off physics, sans gravity.
physics.start()
physics.setGravity(0, 0)

-- Export the module.
return M