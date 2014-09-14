--- Functionality common to most or all "dots", i.e. objects of interest that occupy tiles.
-- The nomenclature is based on _Amazing Penguin_, this game's spiritual prequel, in which
-- such things looked like dots.
--
-- All dots support an **ActOn** method, which defines what happens if So So acts on them.
--
-- A dot may optionally provide other methods: **Reset** and **Update** define how the dot
-- changes state when the level resets and per-frame, respectively; **GetProperty**, called
-- with a name as argument, returns the corresponding property if available, otherwise
-- **nil** (or nothing).

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
local ipairs = ipairs
local pairs = pairs
local sort = table.sort

-- Modules --
local collision = require("game.Collision")
local require_ex = require("tektite.require_ex")
local tile_maps = require("game.TileMaps")
local timers = require("game.Timers")

-- Exports --
local M = {}

-- Tile index -> dot map --
local Dots = {}

-- How many dots are left to pick up? --
local Remaining

-- Dot type lookup table --
local DotList

-- Dummy properties
local function NoOp () end

--- Adds a new _name_-type sensor dot to the level.
--
-- For each name, there must be a corresponding module **"dot.Name"** (e.g. for _name_ of
-- **"acorn"**, the module is **"dot.Acorn"**), the value of which is a constructor function,
-- called as
--    cons(group, info)
-- and which returns the new dot, which must be a display object without physics.
--
-- Various dot properties are important:
--
-- If the **"is_counted"** property is true, the dot will count toward the remaining dots
-- total. If this count falls to 0, the **all\_dots\_removed** event is dispatched.
--
-- Unless the **"omit\_from\_event\_blocks"** property is true, a dot will be added to any event
-- block that it happens to occupy.
--
-- The **"body"** and **"body_type"** properties can be supplied to @{game.Collision.MakeSensor}.
-- @pgroup group Display group that will hold the dot.
-- @ptable info Information about the new dot. Required fields:
--
-- * **col**: Column on which dot sits.
-- * **row**: Row on which dot sits.
-- * **type**: Name of dot type, q.v. _name_, above. This is also assigned as the dot's collision type.
--
-- Instance-specific data may also be passed in other fields.
-- @see game.Collision.GetType
function M.AddDot (group, info)
	local dot = DotList[info.type](group, info)
	local index = tile_maps.GetTileIndex(info.col, info.row)

	dot.GetProperty = dot.GetProperty or NoOp

	tile_maps.PutObjectAt(index, dot)
	collision.MakeSensor(dot, dot:GetProperty("body_type"), dot:GetProperty("body"))
	collision.SetType(dot, info.type)

	local is_counted = dot:GetProperty("is_counted")

	dot.m_count = is_counted and 1 or 0
	dot.m_index = index

	Remaining = Remaining + dot.m_count

	Dots[#Dots + 1] = dot
end

--- Handler for dot-related events sent by the editor.
-- @string type Dot type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = DotList[type]

	if cons then
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Dot to build
		if what == "build" then
			-- COMMON STUFF
			-- t.col, t.row = ...

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
--			arg1.starts_on = true
			arg1.can_attach = true

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:Spacer()
			arg1:StockElements("Dot", type)
			arg1:AddSeparator()
--			arg1:AddCheckbox{ text = "On By Default?", value_name = "starts_on" }
			arg1:AddCheckbox{ text = "Can Attach To Event Block?", value_name = "can_attach" }
			arg1:AddSeparator()

		-- Verify --
		elseif what == "verify" then
			-- COMMON STUFF... nothing yet, I don't think, assuming well-formed editor
		end

		local event, result, r2, r3 = cons("editor_event")

		if event then
			result, r2, r3 = event(what, arg1, arg2, arg3)
		end

		return result, r2, r3
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of dot type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(DotList) do
		types[#types + 1] = k
	end

	return types
end

-- Per-frame setup / update
local function OnEnterFrame ()
	for _, dot in ipairs(Dots) do
		if dot.Update then
			dot:Update()
		end
	end
end

-- Dot-ordering predicate
local function DotLess (a, b)
	return a.m_index < b.m_index
end

-- Listen to events.
for k, v in pairs{
	-- Act On Dot --
	act_on_dot = function(event)
		-- If this dot counts toward the "dots remaining", deduct it. If it was the last
		-- dot, fire off an alert to that effect.
		if event.dot.m_count > 0 then
			Remaining = Remaining - 1

			if Remaining == 0 then
				Runtime:dispatchEvent{ name = "all_dots_removed" }
			end
		end

		-- Do dot-specific logic.
		event.dot:ActOn(event.facing)
	end,

	-- Enter Level --
	enter_level = function()
		Remaining = 0

		Runtime:addEventListener("enterFrame", OnEnterFrame)
	end,

	-- Event Block Setup --
	event_block_setup = function(event)
		-- Sort the dots so that they may be incrementally traversed as we iterate the block.
		if not Dots.sorted then
			sort(Dots, DotLess)

			Dots.sorted = true
		end

		-- Accumulate any non-omitted dot inside the event block region into its dots list.
		local block = event.block
		local slot, n, dots = 1, #Dots

		for index in block:IterSelf() do
			while slot <= n and Dots[slot].m_index < index do
				slot = slot + 1
			end

			local dot = Dots[slot]

			if dot and dot.m_index == index and not dot:GetProperty("omit_from_event_blocks") then
				dots = dots or {}

				dots[#dots + 1] = dot
				dots[#dots + 1] = dot.x
				dots[#dots + 1] = dot.y
			end
		end

		block.dots = dots
	end,

	-- Leave Level --
	leave_level = function()
		Dots = {}

		Runtime:removeEventListener("enterFrame", OnEnterFrame)
	end,

	-- Reset Level --
	reset_level = function()
		Remaining = 0

		for _, dot in ipairs(Dots) do
			tile_maps.PutObjectAt(dot.m_index, dot)

			dot.isVisible = true
			dot.rotation = 0

			if dot.Reset then
				dot:Reset()
			end

			Remaining = Remaining + dot.m_count
		end

		timers.Defer(function()
			for _, dot in ipairs(Dots) do
				dot.isBodyActive = true
			end
		end)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Install various types of dots.
DotList = require_ex.DoList("config.Dots")

-- Export the module.
return M