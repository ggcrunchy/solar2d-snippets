--- Maze-type event block.
--
-- A maze is a strictly toggle-type event, i.e. it goes on &rarr; off or vice versa,
-- and may begin in either state. After toggling, the **"tiles_changed"** event list
-- is dispatched with **"maze"** as the argument, cf. @{game.DispatchList.CallList}.
--
-- @todo Maze format.

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
local ceil = math.ceil
local floor = math.floor
local random = math.random
local remove = table.remove
local sqrt = math.sqrt

-- Modules --
local circle = require("fill.Circle")
local dispatch_list = require("game.DispatchList")
local index_ops = require("index_ops")
local tile_flags = require("game.TileFlags")
local tile_maps = require("game.TileMaps")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local transition = transition

-- Layer used to draw hints --
local MarkersLayer

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Enter Level --
	enter_level = function(level)
		MarkersLayer = level.markers_layer
	end,

	-- Leave Level --
	leave_level = function()
		MarkersLayer = nil
	end
}

-- A random shake displacement
local function ShakeBy ()
	local amount = random(3, 16)

	return amount <= 8 and amount or (amount - 11)
end

-- Fade-in transition --
local FadeInParams = { alpha = 1, time = 1100, transition = easing.inQuad }

-- Kicks off a fade-in
local function FadeIn (block)
	-- Start all the maze off hidden. Usually this will be unnecessary, but if a fade-out
	-- was in progress, this will account for any half-faded tiles.
	for index, col, row in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
			image.isVisible = false
		end
	end

	-- Fade the maze tiles in, as an expanding circle.
	local col1, row1, col2, row2 = block:GetInitialRect()
	local nx = col2 - col1 + 1
	local ny = row2 - row1 + 1
	local halfx = ceil(nx / 2)
	local halfy = ceil(ny / 2)
	local midx, midy, n = col1 + halfx - 1, row1 + halfy - 1, nx * ny

	local spread = circle.SpreadOut(nx - halfx, ny - halfx, function(x, y)
		x, y = x + midx, y + midy

		if x >= col1 and x <= col2 and y >= row1 and y <= row2 then
			local image = tile_maps.GetImage(tile_maps.GetTileIndex(x, y))

			if image then
				image.alpha = .05
				image.isVisible = true

				transition.to(image, FadeInParams)
			end

			n = n - 1
		end
	end)

	-- Spread out until all tiles in the block have been cued.
	local radius, t0 = sqrt(nx * nx + ny * ny) / 2000

	timers.RepeatEx(function(event)
		t0 = t0 or event.time

		if n ~= 0 then
			spread(floor((event.time - t0) * radius))
		else
			return "cancel"
		end
	end)
end

-- Fade-out transition --
local FadeOutParams = {
	alpha = .2, time = 250,

	onComplete = function(object)
		object.isVisible = false
	end
}

-- Kicks off a fade-out
local function FadeOut (block)
	for index, col, row in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
			FadeOutParams.delay = random(900)

			transition.to(image, FadeOutParams)
		end
	end
end

-- Tile deltas (indices into Deltas) available on current iteration, during maze building --
local Choices = {}

-- Tile deltas in each cardinal direction --
local Deltas = { false, -1, false, 1 }

-- List of flood-filled tiles that may still have exits available --
local Maze = {}

-- Populates the maze state used to build tile flags
local function MakeMaze (block, open)
	-- Update the ID for the current maze and overwrite one slot with an invalid ID. A slot
	-- is considered "explored" if it contains the current ID. This is a subtle alternative
	-- to overwriting all slots or building a new table: Since the current ID iterates over
	-- the number of available slots (and then resets), and since every slot is invalidated
	-- between occurrences of the ID taking on a given value, all slots will either contain
	-- some either ID or be invalid, i.e. none will be already explored.
	local new = index_ops.RotateIndex(open.id, #open)

	open.id, open[-new] = new

	-- Compute the deltas between rows of the maze event block (using its width).
	local col1, col2 = block:GetColumns()

	Deltas[1] = col1 - col2 - 1
	Deltas[3] = col2 - col1 + 1

	-- Choose a random maze tile and do a random flood-fill of the block.
	Maze[#Maze + 1] = random(#open / 4)

	repeat
		local index = Maze[#Maze]

		-- Mark this tile slot as explored.
		open[-index] = new

		-- Examine each direction out of the tile. If the direction was already marked
		-- (borders are pre-marked in the relevant direction), or the relevant neighbor
		-- has already been explored, ignore it. Otherwise, add it to the choices.
		local oi, n = (index - 1) * 4, 0

		for i, delta in ipairs(Deltas) do
			if not (open[oi + i] or open[-(index + delta)] == new) then
				n = n + 1

				Choices[n] = i
			end
		end

		-- If there are no choices left, remove the tile from the list. Otherwise, choose
		-- one of the available directions and mark it, plus the reverse direction in the
		-- relevant neighbor, and try to resume the flood-fill from that neighbor.
		if n > 0 then
			local i = Choices[random(n)]
			local delta = Deltas[i]

			open[oi + i] = true

			oi = oi + delta * 4
			i = (i + 1) % 4 + 1

			open[oi + i] = true

			Maze[#Maze + 1] = index + delta
		else
			remove(Maze)
		end
	until #Maze == 0
end

-- Updates tiles from maze block flags
local function UpdateTiles (block)
	tile_maps.SetTilesFromFlags(block:GetImageGroup(), block:GetInitialRect())
end

-- Wipes the maze state (and optionally its flags), marking borders
local function Wipe (block, open, wipe_flags)
	local i, col1, row1, col2, row2 = 0, block:GetInitialRect()

	for _, col, row in block:IterSelf() do
		open[i + 1] = row == row1
		open[i + 2] = col == col1
		open[i + 3] = row == row2
		open[i + 4] = col == col2

		i = i + 4
	end

	if wipe_flags then
		tile_flags.WipeFlags(col1, row1, col2, row2)
	end
end

-- Handler for maze-specific editor events, cf. game.EventBlocks.EditorEvent
local function OnEditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		-- STUFF

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.starts_on = false
			-- Seeds?

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddCheckbox{ text = "Starts on?", value_name = "starts_on" }

	-- Verify --
	-- arg1: Verify block
	-- arg2: Event blocks
	-- arg3: Key
	elseif what == "verify" then
		-- STUFF
	end
end

-- Export the maze factory.
return function(info, block)
	if info == "editor_event" then
		return OnEditorEvent
	end

	-- Shaking block transition and state --
	local shaking, gx, gy

	-- A safe way to stop an in-progress shake
	local function StopShaking (group)
		if shaking then
			group.x, group.y = gx, gy

			timer.cancel(shaking)

			shaking = nil
		end
	end

	-- Forming maze transition (or related step) --
	local forming

	-- A safe way to stop an in-progress form, at any step (will stop shakes, too)
	local function StopForming (group)
		StopShaking(group)

		if forming then
			transition.cancel(forming)

			forming = nil
		end
	end

	-- If allowed, add some logic to shake the group before and after formation.
	local Shake

	if not info.no_shake then
		function Shake (group, params)
			-- Randomly shake the group around from a home position every so often.
			gx, gy = group.x, group.y

			shaking = timers.Repeat(function()
				group.x = gx + ShakeBy()
				group.y = gy + ShakeBy()
			end, 50)

			-- Shake until the dust clears. If this is before the form itself, kick that
			-- off. Otherwise, cancel the dummy transition to conclude the form event.
			local sparams = { time = block:Dust(group, 3, 7) }

			function sparams.onComplete (group)
				StopShaking(group)

				forming = params and group.parent and transition.to(group, params)
			end

			return sparams
		end
	end

	-- Instantiate the maze state and some logic to reset / initialize it. The core state
	-- is a flat list of the open directions of each of the block's tiles, stored as {
	-- up1, left1, down1, right1, up2, left2, down2, right2, ... }, where upX et al. are
	-- booleans (true if open) indicating the state of tile X's directions. The hash part
	-- stores a current ID and the explored tiles list (under the negative integer keys).
	local open, added = { id = 0 }

	function block:Reset ()
		Wipe(self, open, added)

		if added then
			UpdateTiles(self)

			added = false
		end
	end

	-- Fires off the maze event
	local function Fire (forward)
		-- If the previous operation was adding the maze, then wipe it.
		if added then
			Wipe(block, open, true)

		-- Otherwise, make a new one and add it.
		else
			MakeMaze(block, open)

			-- Convert maze state into flags. Border flags are left in place, allowing the
			-- maze to coalesce with the rest of the level.
			-- TODO: Are the edge checks even necessary?
			local i, ncols, nrows = 0, tile_maps.GetCounts()

			for index, col, row in block:IterSelf() do
				local flags = 0

				if open[i + 1] and row > 1 then
					flags = flags + tile_flags.GetFlagsByName("up")
				end

				if open[i + 2] and col > 1 then
					flags = flags + tile_flags.GetFlagsByName("left")
				end

				if open[i + 3] and row < nrows then
					flags = flags + tile_flags.GetFlagsByName("down")
				end

				if open[i + 4] and col < ncols then
					flags = flags + tile_flags.GetFlagsByName("right")
				end

				tile_flags.SetFlags(index, flags)

				i = i + 4
			end
		end

		-- Alert listeners about tile changes and fade tiles in or out. When fading in,
		-- we must first update the tiles to reflect the new flags; on fadeout, we need
		-- to keep the images around until the fade is done, and at that point we can
		-- just leave them as is since they're ipso facto invisible.
		added = not added

		dispatch_list.CallList("tiles_changed", "maze")

		if added then
			UpdateTiles(block)
			FadeIn(block)
		else
			FadeOut(block)
		end

		-- Once the actual form part of the transition is done, send out an alert, e.g. to
		-- rebake shapes, then do any shaking.
		local params = {}

		function params.onComplete (group)
			StopForming(group)

			if Shake then
				forming = transition.to(group, Shake(group))
			end
		end

		-- Kick off the form transition. If shaking, the form is actually a sequence of
		-- three transitions: before, form, after. The before and after are no-ops but
		-- consolidate much of the bookkeeping that needs to be done.
		if Shake then
			params = Shake(block:GetGroup(), params)
		end

		forming = transition.to(block:GetGroup(), params)
	end

	-- Shows or hides hints about the maze event
	-- TODO: What's a good way to show this?
	local mgroup

	local function Show (switch, show)
		-- Show...
		if show then
			--
			mgroup = display.newGroup()

			MarkersLayer:insert(mgroup)

		-- ...or hide.
		else
			if mgroup and mgroup.parent then
				mgroup:removeSelf()
			end

			mgroup = nil
		end
	end

	-- Put the maze into an initial state and supply its event.
	block:Reset()

	return function(what, arg1, arg2)
		-- Can Fire? --
		-- arg1: forward boolean
		if what == "can_fire" then
			return #open > 0 -- ??? (more?)

		-- Fire --
		-- arg1: forward boolean
		elseif what == "fire" then
			Fire(arg1)

		-- Is Done? --
		elseif what == "is_done" then
			return not forming

		-- Show --
		-- arg1: Object that wants to show something, e.g. a switch
		-- arg2: If true, begin showing; otherwise, stop
		elseif what == "show" then
			Show(arg1, arg2)
		end
	end
end