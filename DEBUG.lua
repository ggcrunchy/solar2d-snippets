--- Debug options and helper utilities.

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

-- Modules --
local button = require("ui.Button")
local checkbox = require("ui.Checkbox")
local dispatch_list = require("game.DispatchList")
local index_ops = require("index_ops")
local iterators = require("iterators")
local level_map = require("game.LevelMap")
local markers = require("effect.Markers")
local movement = require("game.Movement")
local player = require("game.Player")
local tile_maps = require("game.TileMaps")

-- Corona globals --
local display = display

-- Corona modules --
local physics = require("physics")

--[[
	if Version == "Final" then
		return false
	end
]]

-- --
local Options = { "NONE", "PHYSICS", "GRID", "TILE_FLAGS" }

-- --
local Index = 1

-- --
local ButtonsToAdd = {}

-- --
local GameGroup, DebugLayer

--
local function AddDebugLayer ()
	DebugLayer = display.newGroup()

	GameGroup:insert(DebugLayer)
end

--
local Colors = {
	down = { 0, 0, 255 },
	left = { 255, 0, 255 },
	right = { 0, 255, 0 },
	up = { 255, 0, 0 }
}

--
local function SetDirections (keep)
	if Options[Index] == "TILE_FLAGS" then
		if not keep and DebugLayer then
			DebugLayer:removeSelf()

			AddDebugLayer()
		end

		local ncols, nrows = tile_maps.GetCounts()

		for tile = 1, ncols * nrows do
			local x, y = tile_maps.GetTilePos(tile)

			for dir in movement.Ways(tile) do
				local arrow = markers.StraightArrow(DebugLayer, dir, x, y, 3)

				arrow:setColor(unpack(Colors[dir]))
			end
		end
	end
end

--
dispatch_list.AddToMultipleLists{
	-- Flags Updated --
	flags_updated = SetDirections,

	-- Leave Level --
	leave_level = function()
		local choice = Options[Index]

		if choice ~= "NONE" then
			physics.setDrawMode("normal")
		end

		DebugLayer, GameGroup = nil
	end,

	-- Reset Level --
	reset_level = SetDirections,

	-- Things Loaded --
	things_loaded = function(level)
		GameGroup = level.game_group

		local y = 20

		for _, key, func in iterators.ArgsByN(2,
--			"KillP", player.Kill,
			"Win", function()
				level_map.UnloadLevel("won")
			end
		) do
			if ButtonsToAdd[key] then
				button.Button(level.hud_group, nil, display.contentWidth - 220, y, 200, 50, func, key)

				y = y + 70
			end
		end

		local choice = Options[Index]

		if choice == "NONE" then
			return
		end

		physics.setDrawMode("hybrid")

		if choice ~= "PHYSICS" then
			AddDebugLayer()

			if choice == "GRID" then
				local w, h = level.ncols * level.w, level.nrows * level.h

				for col = 1, level.ncols do
					local line = display.newLine(DebugLayer, col * level.w, 0, col * level.w, h)

					line.width = 3
				end

				for row = 1, level.nrows do
					local line = display.newLine(DebugLayer, 0, row * level.h, w, row * level.h)

					line.width = 3
				end

			else
				SetDirections(true)
			end
		end
	end
}

--
return function(what, arg_)
	if what == "options" then -- arg_: data group
		local message = display.newText(arg_, Options[Index], 400, 200, native.systemFont, 50)

		button.Button(arg_, nil, 20, 200, 200, 50, function()
			Index = index_ops.RotateIndex(Index, #Options)

			message.text = Options[Index]
		end, "Debug...")

		for i, key, text in iterators.ArgsByN(2,
--			"KillP", "Add 'Kill player' button?",
			"Win", "Add 'Win' button?"
		) do
			local y = 230 + i * 50

			local cb = checkbox.Checkbox(arg_, nil, 10, y, 30, 30, function(_, check)
				ButtonsToAdd[key] = check
			end)

			display.newText(arg_, text, cb.x + cb.width + 40, y, native.systemFont, 20)

			cb:Check(ButtonsToAdd[key])
		end
	end
end