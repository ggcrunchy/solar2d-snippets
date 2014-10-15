--- This module is responsible for getting a level in order.

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
local ceil = math.ceil
local ipairs = ipairs
local running = coroutine.running
local status = coroutine.status
local type = type
local wrap = coroutine.wrap
local yield = coroutine.yield

-- Modules --
local bind_utils = require("utils.Bind")
local controls = require("s3_utils.controls")
local dots = require("s3_utils.dots")
local event_blocks = require("s3_utils.event_blocks")
local global_events = require("s3_utils.global_events")
local level_list = require("game.LevelsList")
local persistence = require("corona_utils.persistence")
local player = require("game.Player")
local positions = require("s3_utils.positions")
local scenes = require("corona_utils.scenes")
local tile_maps = require("s3_utils.tile_maps")

-- Corona globals --
local display = display

-- Corona modules --
local composer = require("composer")

-- Exports --
local M = {}

-- Tile names, expanded from two-character shorthands --
local Names = {
	_H = "Horizontal", _V = "Vertical",
	UL = "UpperLeft", UR = "UpperRight", LL = "LowerLeft", LR = "LowerRight",
	TT = "TopT", LT = "LeftT", RT = "RightT", BT = "BottomT",
	_4 = "FourWays", _U = "Up", _L = "Left", _R = "Right", _D = "Down"
}

-- Decodes a level blob into a level list-compatible form
local function Decode (str)
	local level = persistence.Decode(str)

	level.ncols = level.main[1]
	level.start_col = level.player.col
	level.start_row = level.player.row

	for i, tile in ipairs(level.tiles.values) do
		level[i] = Names[tile] or false
	end

	return level
end

-- State of in-progress level --
local CurrentLevel

-- Tile dimensions --
local Width, Height = 64, 64

-- Helper to iterate on possibly empty tables
local function Ipairs (t)
	return ipairs(t or CurrentLevel)
end

-- In-progress loading coroutine --
local Loading

-- Running coroutine: used to detect runaway errors --
local Running

-- Loads part of the scene, and handles completion
local function LoadSome ()
	-- After the first frame, we have a handle to the running coroutine. The coroutine will
	-- go dead either when the loading finishes or if there was an error along the way, and
	-- in both cases we remove it.
	if Running and status(Running) == "dead" then
		Loading, Running = nil

		Runtime:removeEventListener("enterFrame", LoadSome)

	-- Coroutine still alive: run it another frame.
	else
		Loading()
	end
end

-- Primary display groups --
local Groups = { "game_group", "hud_group" }

-- Assorted values, during normal play... --
local NormalValues = { return_to = "scene.Choices", wait_to_end = 3000 }

-- ...those same values, if the level was launched from the editor... --
local TestingValues = { return_to = "scene.MapEditor", wait_to_end = 500 }

-- ...or from the intro / title screen... --
local QuickTestValues = { return_to = "scene.Title", wait_to_end = 500 }

-- ...the current set of values in effect  --
local Values

-- Cues an overlay scene
local function DoOverlay (name, func, arg)
	if false then--name and Values == NormalValues then
		scenes.Send("message:show_overlay", name, func, arg)
	else
		func(arg)
	end
end

-- Overlay loop spin lock --
local IsDone

-- Ends overlay loop
local function EndLoop ()
	IsDone = true
end

--- Loads a level.
--
-- The level information is gathered into a table and the **enter_level** event is dispatched
-- with said table as argument. It has the following fields:
--
-- * **ncols**, **nrows**: Columns wide and rows tall of level, respectively.
-- * **w**, **h**: Tile width and height, respectively.
-- * **game_group**, **hud_group**: Primary display groups.
-- * **bg_layer**, **tiles_layer**, **decals_layer**, **things_layer**, **markers_layer**:
-- Game group sublayers.
--
-- After tiles and game objects have been added to the level, the **things_loaded** event
-- is dispatched, with the same argument.
-- @pgroup view Level scene view.
-- @param which As a **uint**, a level index as per @{game.LevelsList.GetLevel}. As a
-- **string**, a level as archived by @{corona_utils.persistence.Encode}.
function M.LoadLevel (view, which)
	assert(not CurrentLevel, "Level not unloaded")
	assert(not Loading, "Load already in progress")

	local coming_from = scenes.ComingFrom()

	if coming_from == "Editor" then
		Values = TestingValues
	else
		Values = NormalValues
	end

	Loading = wrap(function()
		Running = running()

		-- Get the level info, either by decoding a database blob or grabbing it from the list.
		local level

		if type(which) == "string" then
			level, which = Decode(which), ""
		else
			level = level_list.GetLevel(which)
		end

		-- Record some information to pass along via dispatch.
		CurrentLevel = { ncols = level.ncols, nrows = ceil(#level / level.ncols), w = Width, h = Height, which = which }

		-- Add the primary display groups.
		for _, name in ipairs(Groups) do
			CurrentLevel[name] = display.newGroup()

			view:insert(CurrentLevel[name])
		end

		-- Add game group sublayers, duplicating them in the level info for convenience.
		for _, name in ipairs{ "bg_layer", "tiles_layer", "decals_layer", "things_layer", "markers_layer" } do
			local layer = display.newGroup()

			CurrentLevel[name] = layer

			CurrentLevel.game_group:insert(layer)
		end

		-- Add the level background, falling back to a decent default if none was given.
		local bg_func = level.background or level_list.DefaultBackground

		bg_func(CurrentLevel.bg_layer, CurrentLevel.ncols, CurrentLevel.nrows, Width, Height)

		-- Dispatch to "enter level" observers, now that the basics are in place.
		bind_utils.Reset("loading_level")

		CurrentLevel.name = "enter_level"

		Runtime:dispatchEvent(CurrentLevel)

		-- Add the tiles to the level...
		local tgroup = tile_maps.NewImageGroup()

		CurrentLevel.tiles_layer:insert(tgroup)

		tile_maps.AddTiles(tgroup, level)

		-- ...and the positions...
		for _, pos in Ipairs(level.positions) do
			positions.AddPosition(pos)
		end

		-- ...and the event blocks...
		for _, block in Ipairs(level.event_blocks) do
			event_blocks.AddBlock(block)
		end

		-- ...and the dots...
		for _, dot in Ipairs(level.dots) do
			dots.AddDot(CurrentLevel.things_layer, dot)
		end

		-- ...and the player...
		player.AddPlayer(CurrentLevel.things_layer, level.start_col, level.start_row)

		-- ...and any global events.
		global_events.AddEvents(level.global_events)

		-- Patch up deferred objects.
		bind_utils.Resolve("loading_level")

		-- Some of the loading may have been expensive, which can lead to an unnatural
		-- start, since various things will act as if that time had passed for them as
		-- well. We try to account for this by waiting a frame and getting a fresh start.
		-- This will actually go several frames in the typical (i.e. non-testing) case
		-- that we are showing a "starting the level" overlay at the same time.
		IsDone = false

		DoOverlay("overlay.StartLevel", EndLoop)

		repeat yield() until IsDone

		-- Dispatch to "things_loaded" observers, now that most objects are in place.
		CurrentLevel.name = "things_loaded"

		Runtime:dispatchEvent(CurrentLevel)

		CurrentLevel.is_loaded = true
	end)

	Runtime:addEventListener("enterFrame", LoadSome)
end

-- Helper to leave level
local function Leave (info)
	Runtime:dispatchEvent{ name = "leave_level", why = info.why }

	--
	local return_to = Values.return_to

	if type(return_to) == "function" then
		return_to = return_to(info)
	end

	composer.gotoScene(return_to, "crossFade")
end

-- Possible overlays to play on unload --
local Overlay = { won = "overlay.Win", lost = "overlay.OutOfLives" }

--- Unloads the current level and returns to a menu.
--
-- This will be the appropriate game or editor menu, depending on how the level was launched.
--
-- The **leave_level** event is dispatched, with _why_ as argument (under key **why**).
-- @string why Reason for unloading, which should be **won"**, **"lost"**, or **"quit"**.
function M.UnloadLevel (why)
	assert(not Loading, "Cannot unload: load in progress")
	assert(CurrentLevel, "No level to unload")

	if CurrentLevel.is_loaded then
		CurrentLevel.is_loaded = false

		DoOverlay(Overlay[why], Leave, { which = CurrentLevel.which, why = why })
	end
end

-- On(win): unload the level and do win-related logic
global_events.ExtendAction("win", function()
	timer.performWithDelay(Values.wait_to_end, function()
		M.UnloadLevel("won")
	end)
end)

-- Listen to events.
Runtime:addEventListener("enter_menus", function()
	for _, name in ipairs(Groups) do
		display.remove(CurrentLevel and CurrentLevel[name])
	end

	CurrentLevel = nil
end)

-- Export the module.
return M