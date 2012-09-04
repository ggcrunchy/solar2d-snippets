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
local array_ops = require("array_ops")
local collision = require("game.Collision")
local dispatch_list = require("game.DispatchList")
local movement = require("game.Movement")
--local shapes = require("game.Shapes")
local tile_flags = require("game.TileFlags")
local tile_maps = require("game.TileMaps")
local timers = require("game.Timers")

-- Imports --
local IsStraight = tile_flags.IsStraight
--local NewShape = shapes.NewShape
local NextDirection = movement.NextDirection
local ShallowEqual = array_ops.ShallowEqual
local Ways = movement.Ways
local WayToGo = movement.WayToGo

-- Exports --
local M = {}

-- Tile index -> dot map --
local Dots = {}

-- How many dots are left to pick up? --
local Remaining

-- Dot type lookup table --
local DotList = {}

-- Dummy properties
local function NOP () end

--- Adds a new _name_-type sensor dot to the level.
--
-- For each name, there must be a corresponding module **"dot.Name"** (e.g. for _name_ of
-- **"acorn"**, the module is **"dot.Acorn"**), the value of which is a constructor function,
-- called as
--    cons(group, info),
-- and which returns the new dot, which must be a display object without physics.
--
-- Various dot properties are important:
--
-- If the **"is_counted"** property is true, the dot will count toward the remaining dots
-- total. If this count falls to 0, the **all\_dots\_removed** event list is dispatched,
-- without arguments.
--
-- If the **"add\_to\_shapes"** property is true, the dot will be added to / may be removed from
-- shapes, and assumes that its **is_counted** property is true.
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
-- @see game.Collision.GetType, game.DispatchList.CallList, game.Shapes.shape:RemoveDot
function M.AddDot (group, info)
	local dot = DotList[info.type](group, info)
	local index = tile_maps.GetTileIndex(info.col, info.row)

	dot.GetProperty = dot.GetProperty or NOP

	tile_maps.PutObjectAt(index, dot)
	collision.MakeSensor(dot, dot:GetProperty("body_type"), dot:GetProperty("body"))
	collision.SetType(dot, info.type)

	local is_counted

	if dot:GetProperty("add_to_shapes") then
		dot.m_shapes = {}

		is_counted = true
	else
		is_counted = dot:GetProperty("is_counted")
	end

	dot.m_count = is_counted and 1 or 0

	Remaining = Remaining + dot.m_count

	Dots[index] = dot
end

--- Handler for dot-related events sent by the editor.
-- @string type Dot type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = DotList[type]

	if cons then
		-- Build --
		-- arg1: Level
		-- arg2: Instance
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
--			arg1:AddCheckbox{ text = "On By Default?", value_name = "starts_on", name = true }
			arg1:AddCheckbox{ text = "Can Attach To Event Block?", value_name = "can_attach", name = true }
			arg1:AddSeparator()				

		-- Verify --
		elseif what == "verify" then
			-- COMMON STUFF... nothing yet, I don't think, assuming well-formed editor
		end

		local event = cons("editor_event")

		if event then
			event(what, arg1, arg2, arg3)
		end
	end
end

---@treturn array Unordered list of dot type names, as strings.
function M.GetTypes ()
	local types = {}

	for k in pairs(DotList) do
		types[#types + 1] = k
	end

	return types
end

-- Indicates whether the shape defined by a group of corners is listed yet
local function InShapesList (shapes, corners)
	-- Since the same loop may be found by exploring in different directions, we can end up
	-- with different orderings of the same set of corner tiles, i.e. an equivalence class
	-- for the shape. The sorted order is as good a canonical form as any, so we impose it
	-- on the corners, making them trivial to compare against the (also sorted) shape.
	sort(corners)

	-- Report if the loop is in the list anywhere.
	for _, shape in ipairs(shapes) do
		if ShallowEqual(shape, corners) then
			return true
		end
	end

	-- Now it's in the list too.
	shapes[#shapes + 1] = corners
end

-- State for alternate attempts --
local Alts = {}

-- Detect if an alternate would have made a better loop
local function BetterAlt (attempted, n)
	local nrows, ncols = tile_maps.GetCounts()

	for i = 1, n, 3 do
		local dir, dt = Alts[i + 1], Alts[i + 2]
		local tile = Alts[i] + dt
		local col, row = tile_maps.GetCell(tile)

		if dir == "left" or dir == "right" then
			col = dir == "right" and ncols or 1
		else
			row = dir == "down" and nrows or 1
		end

		local endt = tile_maps.GetTileIndex(col, row)

		if dt < 0 then
			tile, endt = endt, tile
		end

		for j = tile, endt, dt do
			if attempted[j] then
				return true
			end
		end
	end
end

-- Tries to form a closed loop containing a given tile
local function TryLoop (attempted, dots, corners, tile, facing, pref, alt)
	local start_tile, nalts = tile, 0

	repeat
		attempted[tile] = true

		-- If there is a dot here that may belong to shapes, track it.
		if Dots[tile] and Dots[tile].m_shapes then
			dots[#dots + 1] = tile
		end

		-- If there's a corner or junction on this tile, add its index to the list. Indices
		-- are easy to sort, and the actual corners aren't important, only that a unique
		-- sequence was recorded for later comparison.
		if not IsStraight(tile) then
			corners[#corners + 1] = tile
		end

		-- Try to advance. If we have to turn around, there's no loop.
		local going, dt = WayToGo(tile, pref, "forward", alt, facing)

		if going == "backward" then
			return false

		-- We may overlook a better alternative by following our preference. In that case,
		-- our inferior shape would enclose the other path, so we can detect this case by
		-- heading straight out in the alternate direction until we hit an edge.
		elseif going ~= alt and tile ~= start_tile and movement.CanGo(tile, alt, facing) then
			Alts[nalts + 1] = tile
			Alts[nalts + 2], Alts[nalts + 3] = NextDirection(facing, alt, "tile_delta")

			nalts = nalts + 3
		end

		-- Advance to the next tile. On the first tile, stay the course moving forward.
		facing, dt = NextDirection(facing, tile ~= start_tile and going or "forward", "tile_delta")

		tile = tile + dt
	until attempted[tile]

	-- Completed a loop: was it back to where we started, and the best there was?
	return tile == start_tile and not BetterAlt(attempted, nalts)
end

-- Helper to discover new shapes by finding minimum loops
local function Explore (shapes, tile, dot_shapes, which, pref, alt)
	if not dot_shapes[which] then
		local attempt, dots, corners = {}, {}, {}

		if TryLoop(attempt, dots, corners, tile, which, pref, alt) and not InShapesList(shapes, corners) then
			local shape = NewShape(dots, attempt)

			-- Now that we have a new shape that knows about all of its dots, return the
			-- favor and tell the dots the shape holds them. Also, we may not have gone
			-- exploring from some of these dots yet, but we already know they will end
			-- up on this same loop / shape when heading in this direction, so we mark
			-- each dot to avoid wasted effort.
			for _, dot_index in ipairs(dots) do
				local shape_info = Dots[dot_index].m_shapes

				if shape_info then
					shape_info[which] = true

					shape_info[#shape_info + 1] = shape
				end
			end
		end
	end
end

-- Helper to bake dots into shapes
local function BakeShapes ()
	local shapes = {}

	for i, dot in pairs(Dots) do
		local dot_shapes = dot.m_shapes

		if dot_shapes then
			for dir in Ways(i) do
				Explore(shapes, i, dot_shapes, dir, "to_left", "to_right")
				Explore(shapes, i, dot_shapes, dir, "to_right", "to_left")
			end
		end
	end
end

-- Per-frame setup / update
local function OnEnterFrame ()
	for _, dot in pairs(Dots) do
		if dot.Update then
			dot:Update()
		end
	end
end

-- Dummy table to facilitate no-op ipairs() --
local Dummy = {}

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Act On Dot --
	act_on_dot = function(dot, facing)
		-- Remove the dot from any shapes it's in.
		for _, shape in ipairs(dot.m_shapes or Dummy) do
			shape:RemoveDot()
		end

		-- If this dot counts toward the "dots remaining", deduct it. If it was the last
		-- dot, fire off an alert to that effect.
		if dot.m_count > 0 then
			Remaining = Remaining - 1

			if Remaining == 0 then
				dispatch_list.CallList("all_dots_removed")
			end
		end

		-- Do dot-specific logic.
		dot:ActOn(facing)
	end,

	-- Enter Level --
	enter_level = function()
		Remaining = 0

		Runtime:addEventListener("enterFrame", OnEnterFrame)
	end,

	-- Event Block Setup --
	event_block_setup = function(block)
		local dots

		for index in block:IterSelf() do
			local dot = Dots[index]

			if dot and not dot:GetProperty("omit_from_event_blocks") then
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

	-- Post-Reset --
--	post_reset = BakeShapes,

	-- Reset Level --
	reset_level = function()
		Remaining = 0

		for i, dot in pairs(Dots) do
			tile_maps.PutObjectAt(i, dot)

			dot.isVisible = true
			dot.rotation = 0

			if dot.Reset then
				dot:Reset()
			end

			dot.m_shapes = dot.m_shapes and {}

			Remaining = Remaining + dot.m_count
		end

		timers.Defer(function()
			for _, dot in pairs(Dots) do
				dot.isBodyActive = true
			end
		end)
	end,

	-- Tiles Changed --
	tiles_changed = function()
		for _, dot in pairs(Dots) do
			dot.m_shapes = dot.m_shapes and {}
		end

--		BakeShapes()
	end,

	-- Things Loaded --
--	things_loaded = BakeShapes
}

-- Install various types of dots.
-- <SNIP>
DotList.warp = require("dot.Warp")

-- Export the module.
return M