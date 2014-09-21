--- Common functionality for various "area effect" game events.
--
-- Each such event type must return a factory function, cf. the result of @{GetEvent}.
-- Such functions must gracefully handle an _info_ argument of **"editor_event"**, by
-- returning either an editor event function or **nil**, cf. @{EditorEvent}.
--
-- **N.B.**: In each of the functions below that take columns and rows as input, the
-- operation will transparently sort the columns and rows, and clamp them against the
-- level boundaries. A rect completely outside the level is null and the operation
-- will be a no-op.

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
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs
local random = math.random
local yield = coroutine.yield

-- Modules --
local require_ex = require("tektite.require_ex")
local bind_utils = require("utils.Bind")
local fx = require("game.FX")
local range = require("number_ops.range")
local tile_flags = require("game.TileFlags")
local tile_maps = require("game.TileMaps")
local wrapper = require("coroutine_ops.wrapper")

-- Corona globals --
local display = display

-- Imports --
local GetFlags = tile_flags.GetFlags
local GetImage = tile_maps.GetImage
local SetFlags = tile_flags.SetFlags

-- Module --
local M = {}

-- Column and row extrema of currently iterated block --
local CMin, CMax, RMin, RMax

-- Block iterator body
local BlockIter = wrapper.Wrap(function()
	local left = tile_maps.GetTileIndex(CMin, RMin)
	local col, ncols = CMin, tile_maps.GetCounts()

	for row = RMin, RMax do
		for i = 0, CMax - CMin do
			yield(left + i, col + i, row)
		end

		left = left + ncols
	end
end)

-- Binds column and row extents, performing any clamping and sorting
local function BindExtents (col1, row1, col2, row2)
	local ncols, nrows = tile_maps.GetCounts()

	CMin, CMax = range.MinMax_N(col1, col2, ncols)
	RMin, RMax = range.MinMax_N(row1, row2, nrows)
end

-- Iterates over a block defined by input
local function Block (col1, row1, col2, row2)
	BindExtents(col1, row1, col2, row2)

	return BlockIter
end

-- Iterates over a block defined by its members
local function BlockSelf (block)
	CMin, CMax = block:GetColumns()
	RMin, RMax = block:GetRows()

	return BlockIter	
end

-- List of loaded event blocks --
local Blocks

-- Tile -> ID map indicating which event block, if any, occupies a given tile --
local BlockIDs

-- Creation-time values of flags within the block region, for restoration --
local OldFlags

-- Layers into which block groups are added --
local TilesLayer

-- Wipes event block state at a given tile index
local function Wipe (index)
	BlockIDs[index] = nil

	SetFlags(index, 0)
end

-- Prepares a new event block
local function NewBlock (col1, row1, col2, row2)
	-- Validate the block region, saving indices as we go to avoid repeating some work.
	local block = {}

	for index in Block(col1, row1, col2, row2) do
		assert(not OldFlags[index], "Tile used by another block")

		block[#block + 1] = index
	end

	-- Now that the true column and row values are known (from running the iterator),
	-- initialize the current values.
	local cmin, rmin = CMin, RMin
	local cmax, rmax = CMax, RMax
	local bgroup = display.newGroup()

	-- Lift any tile images into the block's own group. Mark the block region as occupied
	-- and cache the current flags on each tile, for restoration.
	local id, igroup = #Blocks + 1, tile_maps.NewImageGroup()

	for i, index in ipairs(block) do
		block[i] = GetImage(index) or false

		if block[i] then
			igroup:insert(block[i])
		end

		BlockIDs[index] = id
		OldFlags[index] = GetFlags(index)
	end

	bgroup:insert(igroup)
	TilesLayer:insert(bgroup)

	Blocks[id] = block

	--- Adds a new group to the block's main group.
	-- @treturn DisplayGroup Added group.
	function block:AddGroup ()
		local new = display.newGroup()

		bgroup:insert(new)

		return new
	end

	--- Indicates whether a block can occupy a region without overlapping a different block.
	-- The block will ignore itself, since this test will often be used to determine if a
	-- block could be changed.
	--
	-- **N.B.** that this is **not** called automatically by other block methods.
	-- @int col1 A column...
	-- @int row1 ... and row.
	-- @int col2 Another column...
	-- @int row2 ...and row.
	-- @treturn boolean The block can occupy the region, i.e. each tile is either unoccupied
	-- or already occupied by this block?
	-- @treturn uint If the first return value is **false**, the number of conflicting tiles.
	-- Otherwise, 0.
	function block:CanOccupy (col1, row1, col2, row2)
		local count = 0

		for index in Block(col1, row1, col2, row2) do
			local bid = BlockIDs[index]

			if bid and bid ~= id then
				count = count + 1
			end
		end

		return count == 0, count
	end

	--- Triggers a dust effect over the block's region.
	-- @pgroup group Group to which dust particles are added.
	-- @uint nmin Minimum number of clouds to randomly throw up...
	-- @uint nmax ...and maximum.
	-- @treturn uint Total time elapsed, in milliseconds, by effect.
	-- @see game.FX.Poof
	function block:Dust (group, nmin, nmax)
		local total = 0

		for _ = 1, random(nmin, nmax) do
			local col, row = random(cmin, cmax), random(rmin, rmax)
			local index = tile_maps.GetTileIndex(col, row)
			local x, y = tile_maps.GetTilePos(index)

			total = max(total, fx.Poof(group, x, y))
		end

		return total
	end

	--- Fills a region with occupancy information matching this block.
	-- @int col1 A column...
	-- @int row1 ... and row.
	-- @int col2 Another column...
	-- @int row2 ...and row.
	function block:FillRect (col1, row1, col2, row2)
		for index in Block(col1, row1, col2, row2) do
			BlockIDs[index] = id
		end
	end

	--- Variant of @{block:FillRect} that fills the current rect.
	-- @see block:SetRect
	function block:FillSelf ()
		for index in BlockSelf(self) do
			BlockIDs[index] = id
		end
	end

	--- Getter.
	-- @treturn int Minimum column...
	-- @treturn int ...and maximum.
	function block:GetColumns ()
		return cmin, cmax
	end

	--- Getter.
	-- @treturn DisplayGroup The block's main group.
	function block:GetGroup ()
		return bgroup
	end

	--- Getter.
	-- @treturn DisplayGroup The block's image group.
	function block:GetImageGroup ()
		return igroup
	end

	--- Getter.
	-- @treturn int Minimum row...
	-- @treturn int ...and maximum.
	function block:GetRows ()
		return rmin, rmax
	end

	-- Save the initial rect, given the current values --
	local cmin_save, rmin_save = cmin, rmin
	local cmax_save, rmax_save = cmax, rmax

	--- Gets the rect that was current at block initialization.
	-- @bool flagged If true, cull any unflagged outer rows and columns.
	-- @treturn int Minimum column...
	-- @treturn int ...and row.
	-- @treturn int Maximum column...
	-- @treturn int ...and row.
	function block:GetInitialRect (flagged)
		if flagged then
			local cmin, rmin = cmax_save, rmax_save
			local cmax, rmax = cmin_save, rmin_save

			for index, col, row in self:Iter(cmin_save, rmin_save, cmax_save, rmax_save) do
				if self:GetOldFlags(index) ~= 0 then
					cmin, cmax = min(cmin, col), max(cmax, col)
					rmin, rmax = min(rmin, row), max(rmax, row)
				end
			end

			return cmin, rmin, cmax, rmax
		end

		return cmin_save, rmin_save, cmax_save, rmax_save
	end

	--- Getter.
	-- @int index Tile index.
	-- @treturn uint Tile flags at block creation time.
	-- @see game.TileFlags.GetFlags
	function block:GetOldFlags (index)
		return OldFlags[index] or 0
	end

	--- Injects a new group above the image group's parent: i.e. the new group becomes
	-- the image group's parent, and is added as a child of the old parent.
	--
	-- By default, the image group belongs to the main group.
	-- @treturn DisplayGroup The injected group.
	function block:InjectGroup ()
		local new, parent = display.newGroup(), igroup.parent

		new:insert(igroup)
		parent:insert(new)

		return new
	end

	--- Iterates over a given region.
	-- @int col1 A column...
	-- @int row1 ... and row.
	-- @int col2 Another column...
	-- @int row2 ...and row.
	-- @treturn iterator Supplies tile index, column, row.
	function block:Iter (col1, row1, col2, row2)
		return Block(col1, row1, col2, row2)
	end

	--- Variant of @{block:Iter} that iterates over the current rect.
	-- @treturn iterator Supplies tile index, column, row.
	-- @see block:SetRect
	function block:IterSelf ()
		return BlockSelf(self)
	end

	--- Sets the block's current rect, as used by the ***Self** methods.
	--
	-- Until this call, the current rect will be equivalent to @{block:GetInitialRect}'s
	-- result (with _flagged_ false).
	--
	-- If the rect is null, those methods will be no-ops.
	-- @int col1 A column...
	-- @int row1 ...and row.
	-- @int col2 Another column...
	-- @int row2 ...and row.
	function block:SetRect (col1, row1, col2, row2)
		BindExtents(col1, row1, col2, row2)

		cmin, cmax = CMin, CMax
		rmin, rmax = RMin, RMax
	end

	--- Wipes event block state (flags, occupancy) in a given region.
	-- @int col1 A column...
	-- @int row1 ... and row.
	-- @int col2 Another column...
	-- @int row2 ...and row.
	function block:WipeRect (col1, row1, col2, row2)
		for index in Block(col1, row1, col2, row2) do
			Wipe(index)
		end
	end

	--- Variant of @{block:WipeRect} that wipes the current rect.
	-- @see block:SetRect
	function block:WipeSelf ()
		for index in BlockSelf(self) do
			Wipe(index)
		end
	end

	return block
end

-- Block events --
local Events

-- Event block type lookup table --
local EventBlockList

--- Adds a block to the level and registers an event for it.
-- @ptable info Block info, with at least the following properties:
--
-- * **name**: **string** The event is registered under this name, which should be unique
-- among event blocks.
-- * **type**: **string** One of the choices reported by @{GetTypes}.
-- * **col1**, **row1**, **col2**, **row2**: **int** Columns and rows defining the block.
-- These will be sorted and clamped, as with block operations.
--
-- @todo Detect null blocks? Mention construction, block:Reset
function M.AddBlock (info)
	local block = NewBlock(info.col1, info.row1, info.col2, info.row2)
	local event = assert(EventBlockList[info.type], "Invalid event block")(info, block)

	bind_utils.Publish("loading_level", event, info.uid, "fire")

	Events[#Events + 1] = event -- TODO: Forgo this when not debugging?
end

-- Keys referenced in editor event --
local BlockKeys = { "type", "col1", "row1", "col2", "row2" }

--- Handler for event block-related events sent by the editor.
--
-- If an editor event function is available for _type_, if will be called afterward as
-- `func(what, arg1, arg2, arg3)`.
-- @string type Event block type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local factory = EventBlockList[type]

	if factory then
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Block to build
		if what == "build" then
			for _, key in ipairs(BlockKeys) do
				arg3[key] = arg2[key]
			end

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
--			arg1.starts_on = true

		-- Enumerate Properties --
		-- arg1: Dialog
		-- arg2: Representative object
		elseif what == "enum_props" then
			arg1:Spacer()
			arg1:StockElements("EventBlock", type)
			arg1:AddLink{ text = "Link to event source", rep = arg2, sub = "fire", interfaces = "event_source" }
			arg1:AddSeparator()
--			arg1:AddCheckbox{ text = "On By Default?", value_name = "starts_on" }
--			arg1:AddSeparator()

		-- Get Tag --
		elseif what == "get_tag" then
			return "event_block"

		-- New Tag --
		elseif what == "new_tag" then
			return "sources_and_targets", nil, "fire"

		-- Prep Link --
		elseif what == "prep_link" then
			-- ??

		-- Verify --
		elseif what == "verify" then
			-- Has one or more source...
		end

		local event, result, r2, r3 = factory("editor_event")

		if event then
			result, r2, r3 = event(what, arg1, arg2, arg3)
		end

		return result, r2, r3
	end
end

--- Getter.
-- @param name Name used to register event in @{AddBlock}.
-- @treturn callable If missing, a no-op. Otherwise, this is a function called as
--   result = event(what, arg1, arg2)
-- which should handle the following choices of _what_:
--
-- * **"can_fire"**: If _result_ is true, the event can be safely fired. _arg1_ indicates
-- whether the source, e.g. a switch, wants to fire forward or backward (forward = true).
-- This has meaning to certain events.
-- * **"fire"**: Fires the event. _arg1_ is again the forward boolean.
-- * **"is_done"**: If _result_ is false, the event is still in progress.
-- * **"show"**: Shows or hides event hints. _arg1_ is the responsible party for firing
-- events, e.g. a switch, and _arg2_ is a boolean (true = show).
--
-- **CONSIDER**: Formalize _arg1_ in "show" more... e.g. an options list (m\_forward is
-- the only one we care about so far)... or maybe JUST the forward boolean, since the
-- hint might as well be compatible with can\_fire / fire?
function M.GetEvent (name)
	return Events[name] or function() end -- TODO: Remove this function?
end

--- Fires all events.
-- @bool forward Forward boolean, argument to event's **"can_fire"** and **"fire"** choices.
function M.FireAll (forward)
	forward = not not forward

	for _, v in ipairs(Events) do
		if v("can_fire", forward) then
			v("fire", forward)
		end
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of event block type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(EventBlockList) do
		types[#types + 1] = k
	end

	return types
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		Blocks = {}
		BlockIDs = {}
		Events = {}
		OldFlags = {}
		TilesLayer = level.tiles_layer
	end,

	-- Leave Level --
	leave_level = function()
		Blocks, BlockIDs, Events, OldFlags, TilesLayer = nil
	end,

	-- Pre-Reset --
	pre_reset = function()
		if #Blocks > 0 then
			BlockIDs = {}
		end

		-- Restore any flags that may have been altered by a block.
		for i, flags in pairs(OldFlags) do
--[[
			local image = GetImage(i) -- Relevant?...

			if image then
				PutObjectAt(i, image)
			end
]]
-- Physics...
			SetFlags(i, flags)
		end

		-- Reset any block state and refill initial block regions with IDs.
		for _, block in ipairs(Blocks) do
			if block.Reset then
				block:Reset()
			end

			block:SetRect(block:GetInitialRect()) -- TODO: Make responsibilty of event?
			block:FillSelf()
		end
	end,

	-- Things Loaded --
	things_loaded = function()
		for _, block in ipairs(Blocks) do
			Runtime:dispatchEvent{ name = "event_block_setup", block = block }
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Install various types of events.
EventBlockList = require_ex.DoList("config.EventBlocks")

-- Export the module.
return M