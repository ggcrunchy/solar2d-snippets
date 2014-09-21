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
local pairs = pairs

-- Modules --
local tile_maps = require("game.TileMaps")

-- Exports --
local M = {}

-- Index -> position map --
local Positions

--- DOCME
-- @ptable info
function M.AddPosition (info)
	local pos = { m_index = tile_maps.GetTileIndex(info.col, info.row) }

	tile_maps.PutObjectAt(pos.m_index, pos)

	Positions[info.uid] = pos
end

--- DOCME
function M.EditorEvent (_, what, arg1, arg2)
	-- Enumerate Properties --
	-- arg1: Dialog
	-- arg2: Representative object
	if what == "enum_props" then
		arg1:Spacer()
		arg1:StockElements(nil)
		arg1:AddSeparator()
		arg1:AddLink{ text = "Generic link", rep = arg2, sub = "link" }
		-- TODO: "dynamic" boolean?

	-- Get Tag --
	elseif what == "get_tag" then
		return "position"

	-- New Tag --
	elseif what == "new_tag" then
		return { sub_links = { link = true } }
	end
end

--- DOCME
function M.GetPosition (id)
	return Positions[id]
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function()
		Positions = {}
	end,

	-- Leave Level --
	leave_level = function()
		Positions = nil
	end,

	-- Reset Level --
	reset_level = function()
		for id, pos in pairs(Positions) do
			tile_maps.PutObjectAt(pos.m_index, pos)
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M