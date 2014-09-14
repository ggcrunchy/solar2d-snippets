--- The main functionality behind our heroic player.

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
local min = math.min
local pairs = pairs

-- Modules --
local ai = require("game.AI")
local collision = require("game.Collision")
local frames = require("utils.Frames")
local pathing = require("game.Pathing")
local path_utils = require("game.PathUtils")
local scrolling = require("game.Scrolling")
local tile_flags = require("game.TileFlags")
local tile_maps = require("game.TileMaps")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Helper to point our player in a given direction
local function Face (player, dir)
	if player.m_facing ~= dir then
		player.m_facing = dir
	end
end

-- Places our player somewhere
local function Place (player, x, y)
	player.m_body.x = x
	player.m_body.y = y
end

-- Puts the player fresh at the starting tile
local function PutAtStart (player)
	Face(player, "down")
	Place(player, tile_maps.GetTilePos(player.m_start))
end

-- Collision radius of body --
local Radius = 15

-- Collision body features --
local Body = { filter = { categoryBits = collision.FilterBits("player"), maskBits = 0xFFFF }, radius = Radius }

-- Player state --
local Player

--- Adds our heroic protagonist to a new level.
-- @pgroup group Display group that will hold the player parts.
-- @uint col Column of starting tile.
-- @uint row Row of starting tile.
function M.AddPlayer (group, col, row)
	Player = { m_start = tile_maps.GetTileIndex(col, row), m_touching = {} }

	-- Add the body "sprite"
	Player.m_body = display.newCircle(group, 0, 0, Radius)

	Player.m_body:setStrokeColor(1, 0, 0)

	Player.m_body.strokeWidth = 3

	-- Put the player on the starting tile.
	PutAtStart(Player)

	-- Activate collision.
	collision.MakeSensor(Player.m_body, "dynamic", Body)
	collision.SetType(Player.m_body, "player")
end

-- Current segment used to build a path, if any --
local Cur

-- The goal position of any path in progress --
local Goal

-- Graphics used to mark a path destination --
local X1, X2

--- If a path is in progress, cancels it; otherwise, this is a no-op.
function M.CancelPath ()
	display.remove(X1)
	display.remove(X2)

	ai.WipePath(Player.m_body)

	Cur, Goal, X1, X2 = nil
end

-- Event dispatched on action --
local ActOnDotEvent = { name = "act_on_dot" }

--- Acts on any objects that the player is touching.
function M.DoActions ()
	ActOnDotEvent.facing = Player.m_facing

	for object in pairs(Player.m_touching) do
		ActOnDotEvent.dot = object

		Runtime:dispatchEvent(ActOnDotEvent)
	end

	ActOnDotEvent.dot = nil
end

---@treturn number Player's x coordinate.
-- @treturn number Player's y coordinate.
function M.GetPos ()
	local body = Player.m_body

	return body.x, body.y
end

---@treturn boolean The player is following a path?
function M.IsFollowingPath ()
	return Goal ~= nil
end

---@treturn number Goal's x coordinate, or **nil** if no goal exists...
-- @treturn number ...and y coordinate.
-- @treturn int Goal's tile, or **nil** if no goal exists (or tile has not been found).
function M.GoalPos ()
	if Goal then
		return Goal.x, Goal.y, Goal.tile
	else
		return nil
	end
end

-- Distance that player can travel per second --
local Speed = 95

-- Updates the player on tile movement
local function UpdateOnMove (dir, tile)
	Cur = path_utils.Advance(Cur, "facing", dir)

	Goal.tile = tile

	return path_utils.CurrentDir(Cur) 
end

-- Near goal distance --
local NearGoal

--- Attempts to move the player in a given direction, at some average squirrel velocity.
-- @string dir Direction in which to move.
-- @see game.Movement.NextDirection
function M.MovePlayer (dir)
	-- Try to walk a bit.
	local moved, x2, y2, dir2 = ai.TryToMove(Player.m_body, Speed * frames.DiffTime(), dir, NearGoal, M, UpdateOnMove)

	-- Face the direction we at least tried to move.
	Face(Player, dir2)

	-- If we did move, update the animation.
	if moved then
--		Player.m_body:play()
	end

	-- Finally, put the body and tail relative to the feet.
	Place(Player, x2, y2)
end

-- Per-frame setup / update
local function OnEnterFrame ()
	-- If on a path, progress along it.
	-- TODO: Good way to get player onto X evenly (and reliably; right now it sort of depends on if there's already a node, probably, and how off-center the X is then)
	if Cur then
		M.MovePlayer(path_utils.CurrentDir(Cur))
	end
end

-- Layer onto which pathing graphics are planted --
local MarkersLayer

-- Reference group for tap and scroll coordinates --
local RefGroup

-- Helper to activate collision
local function Activate (active)
	Player.m_is_busy = not active

	collision.Activate(Player.m_body, active)
end

-- Listen to events.
AddMultipleListeners{
	-- Enter Level --
	enter_level = function(level)
		MarkersLayer = level.markers_layer
		NearGoal = min(level.w, level.h) / 3

--		Sounds:Load()

		Runtime:addEventListener("enterFrame", OnEnterFrame)
	end,

	-- Leave Level --
	leave_level = function()
		M.CancelPath()

		Player, RefGroup = nil

		Runtime:removeEventListener("enterFrame", OnEnterFrame)
	end,

	-- Move Done --
	move_done = function()
		Activate(true)

		scrolling.Follow(Player.m_body, "keep")
	end,

	-- Move Done Moving --
	move_done_moving = function(event)
		Place(Player, event.to.x, event.to.y)
	end,

	-- Move Prepare --
	move_prepare = function(event)
		event.from:AddItem(Player.m_body)

		Activate(false)

		scrolling.Follow(Player.m_body, "keep")
	end,

	-- Reset Level --
	reset_level = function()
		PutAtStart(Player)
		Activate(true)
	end,

	-- Tapped At --
	tapped_at = function(event)
		local x, y = event.x - RefGroup.x, event.y - RefGroup.y

		-- If we tapped on a tile, plan a path to it.
		local tile = tile_maps.GetTileIndex_XY(x, y)

		if tile_flags.IsOnPath(tile) then
			M.CancelPath()

			local ftile = tile_maps.GetTileIndex_XY(M.GetPos())
			local paths = pathing.FindPath(ftile, tile)

			if paths then
				local px, py = tile_maps.GetTilePos(tile)

				if tile_flags.IsFlagSet(tile, x < px and "left" or "right") then
					px = x
				end

				if tile_flags.IsFlagSet(tile, y < py and "up" or "down") then
					py = y
				end

				Cur = path_utils.ChooseBranch_Facing(paths, Player.m_facing)
				Goal = { x = px, y = py, tile = ftile }

				-- X marks the spot!
				X1 = display.newLine(MarkersLayer, x - 15, y - 15, x + 15, y + 15)
				X2 = display.newLine(MarkersLayer, x - 15, y + 15, x + 15, y - 15)

				X1:setStrokeColor(1, 0, 0)
				X2:setStrokeColor(1, 0, 0)

				X1.strokeWidth = 4
				X2.strokeWidth = 8
			end

		-- Otherwise, play some sparkles just to give some feedback on the tap.
		else
--			fx.Sparkle(MarkersLayer, x, y)
		end
	end,

	-- Things Loaded --
	things_loaded = function(level)
		RefGroup = level.game_group

		scrolling.Follow(Player.m_body, RefGroup)
	end,

	-- Touching Dot --
	touching_dot = function(event)
		Player.m_touching[event.dot] = event.is_touching or nil
	end
}

-- Export the module.
return M