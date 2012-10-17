--- Grid shared by various editor views.

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

-- Exports --
local M = {}

-- Standard library imports --
local ceil = math.ceil
local format = string.format
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs

-- Modules --
local common = require("editor.Common")
local grid1D = require("ui.Grid1D")
local grid2D = require("ui.Grid2D")
local sheet = require("ui.Sheet")

-- Corona globals --
local display = display
local native = native
local transition = transition

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

-- --
local Grid

-- --
local Offset

-- --
local Targets

--- Cleans up various state used by editor grid operations.
function M.CleanUp ()
	if Grid then
		Grid.reserve:removeSelf()
	end

	Grid, Offset, Targets = nil
end

--- Common logic for the **PAINT** / **EDIT** / **ERASE** combination of grid operations.
-- @callable dialog_wrapper Cf. the result of @{editor.Dialog.DialogWrapper}.
-- @array types An array of strings denoting type.
-- @treturn function A "common ops" wrapper for an editor view. Its signature starts with a
-- _what_ parameter, then all grid function parameters, cf. _func_ in @{ui.Grid2D.Grid2D}.
-- The following choices are available for _what_:
--
-- * **"grid"**: Boilerplate: editor grid function body.
-- * **"load"**: Boilerplate: editor view being loaded... (The assets directory prefix, viz.
-- in **"_prefix_\_Assets/", is passed through _col_, and a title for the current tile
-- @{ui.Grid1D} is passed through _row_.)
-- * **"enter"**: ...entered... (The grid function is passed through _col_.)
-- * **"exit"**: ...exited...
-- * **"unload"**: ...or unloaded.
-- * **"get\_data"**: Returns the current tile @{ui.Grid1D}, the elements table, and the
-- tiles table.
function M.EditErase (dialog_wrapper, types)
	local current, option, pick, elements, tabs, tiles, tile_images

	return function (what, group, col_, row_, x, y, w, h)
		-- Grid --
		if what == "grid" then
			local key, which = common.ToKey(col_, row_), current:GetCurrent()
			local cur, tile = elements[key], tiles[key]

			--
			pick = M.UpdatePick(group, pick, col_, row_, x, y, w, h)

			--
			if group == "show" or group == "hide" then
				if cur then
					tile.isVisible = group == "show"
				end

			--
			elseif option == "Edit" then
				if cur then
					dialog_wrapper("edit", cur, current.parent, key)
				else
					dialog_wrapper("close")
				end

			--
			elseif option == "Erase" then
				if cur then
					tile:removeSelf()

					common.Dirty()
				end

				elements[key], tiles[key] = nil

			--
			elseif not cur or sheet.GetSpriteSetImageFrame(tile) ~= which then
				elements[key] = dialog_wrapper("new_element", types[which], key)
				tiles[key] = tile or sheet.NewImage(group, tile_images, x, y, w, h)

				sheet.SetSpriteSetImageFrame(tiles[key], which)

				common.Dirty()
			end

		-- Load --
		-- col_: Prefix
		-- row_: Title
		elseif what == "load" then
			elements, tiles = {}, {}

			--
			current = grid1D.OptionsHGrid(group, nil, 150, 50, 200, 100, row_)

			--
			local tab_buttons = { "Paint", "Edit", "Erase" }

			for i, label in ipairs(tab_buttons) do
				tab_buttons[i] = {
					label = label,

					onPress = function()
						option = label

						common.ShowCurrent(current, label == "Paint")

						if label ~= "Edit" then
							dialog_wrapper("close")
						end
					end
				}
			end

			tabs = common.TabBar(group, tab_buttons, { top = display.contentHeight - 65, left = 120, width = 300 }, true)

			tabs:pressButton(1, true)

			--
			tile_images = common.SpriteSetFromThumbs(col_, types)

			current:Bind(tile_images, #tile_images)
			current:toFront()

			common.ShowCurrent(current, false)

		-- Enter --
		-- col_: Grid func
		elseif what == "enter" then
			M.Show(col_)

			common.ShowCurrent(current, option == "Paint")

			tabs.isVisible = true

		-- Exit --
		elseif what == "exit" then
			dialog_wrapper("close")

			common.ShowCurrent(current, false)

			tabs.isVisible = false

			M.Show(false)

		-- Unload --
		elseif what == "unload" then
			tabs:removeSelf()

			current, option, pick, elements, tabs, tiles, tile_images = nil

		-- Get Data --
		elseif what == "get_data" then
			return current, elements, tiles
		end
	end
end

---@treturn DisplayObject The global editor @{ui.Grid2D} widget.
function M.Get ()
	return Grid.grid
end

-- Column and row of upper-left cell --
local Col, Row

---@treturn uint Column offset... (i.e. upper-left cell visible on grid)
-- @treturn uint ...and row offset.
function M.GetOffsets ()
	return Col, Row
end

-- Number of columns and rows shown in the grid (maximum) and used as baseline for metrics --
local ColBase, RowBase = 9, 9

--
local function GetCellDims ()
	local gw, gh = display.contentWidth - 240, display.contentHeight - 160

	return gw / ColBase, gh / RowBase
end

--
local function GridFunc (group, col, row, x, y, w, h)
	if Grid.func then
		local cw, ch = GetCellDims()

		Grid.func(group, Col + col, Row + row, x + Col * cw, y + Row * ch, w, h)
	end
end

--
local function GetShowHide (old, new, nvis)
	local delta, past = new - old, old + nvis

	if delta < 0 then
		return delta, new + 1, past
	end

	return delta, past + 1, old + 1
end

--
local function UpdatePair (diff, coord, extent, nname, pname)
	local ncoord, pcoord, nalpha, palpha = 0, extent - 1, .4, 1

	if diff == 0 then
		return
	elseif diff > 0 then
		ncoord, pcoord = ncoord + 1, pcoord + 1
		nalpha, palpha = palpha, nalpha
	end

	common.FadeButton(nname, coord == ncoord, nalpha)
	common.FadeButton(pname, coord == pcoord, palpha)
end

-- Should multiple layers be shown? --
local DoMultipleLayers

-- One-shot iterator (no-op if key and value are absent; dummy key added when value only)
local DoOnce

local function Once (k, v)
	if DoOnce and (k or v) then
		DoOnce = false

		return k or false, v
	end
end

-- Conditional (one- or multi-shot) iterator
local function Iter (k, v)
	if DoMultipleLayers then
		return pairs(Targets)
	else
		DoOnce = true

		return Once, k, v
	end
end

-- Helper to show or hide one or more layers
local function AuxShow (how, col, row)
	for func in Iter(Grid.func) do
		func(how, col, row)
	end
end

-- --
local Hide = {}

-- How many columns and rows are viewable on the grid? --
local VCols, VRows

-- Grid scroll transition --
local To = {
	time = 150,

	onComplete = function()
		if Hide.what == "col" then
			for row = 1, VRows do
				AuxShow("hide", Hide.which, Row + row)
			end
		else
			for col = 1, VCols do
				AuxShow("hide", Col + col, Hide.which)
			end
		end
	end
}

--
local function UpdateCoord (col, row, diff)
	local ncols, nrows = common.GetDims()
	local cdelta, crange = 0, ncols - ColBase
	local rdelta, rrange = 0, nrows - RowBase

	if Grid.func then
		col = max(0, min(col, crange))
		row = max(0, min(row, rrange))

		--
		local target = Grid.grid:GetTarget()
		local cw, ch = GetCellDims()

		To.x, To.y = nil

		if col ~= Col then
			local dc, show, hide = GetShowHide(Col, col, VCols)

			Col = col

			-- 
			for row = 1, VRows do
				AuxShow("show", show, Row + row)
			end

			Hide.what, Hide.which = "col", hide

			To.x, cdelta = target.x - dc * cw, dc
		end

		if row ~= Row then
			local dr, show, hide = GetShowHide(Row, row, VRows)

			Row = row

			-- 
			for col = 1, VCols do
				AuxShow("show", Col + col, show)
			end

			Hide.what, Hide.which = "row", hide

			To.y, rdelta = target.y - dr * ch, dr
		end

		--
		if To.x or To.y then
			for _, group in Iter(target) do
				transition.to(group, To)
			end
		end
	end

	--
	UpdatePair(diff or cdelta, Col, crange, "lscroll", "rscroll")
	UpdatePair(diff or rdelta, Row, rrange, "uscroll", "dscroll")

	--
	Offset.text = format("Offset col = %i, row = %i", col, row)
end

--
local function UpdateDir (button)
	UpdateCoord(Col + button.m_dc, Row + button.m_dr)
end

--
local function AddButton (name, x, y, dc, dr)
	common.AddButton(name, common.ScrollButton(Grid.group, name, x, y, UpdateDir))
end

--- Initializes various state used by editor grid operations.
-- @pgroup view Map editor scene view.
function M.Init (view)
	Grid, Targets, Col, Row = {}, {}, 0, 0

	local ncols, nrows = common.GetDims()

	VCols, VRows = min(ncols, ColBase), min(nrows, RowBase)

	-- Consolidate grid and related interface elements into a group.
	Grid.group = display.newGroup()

	view:insert(Grid.group)

	-- Keep an invisible group on hand to store inactive grid targets.
	Grid.reserve = display.newGroup()

	Grid.reserve.isVisible = false

	-- Build the grid and put opaque elements around it to each side (as a lazy mask).
	local x, y = 120, 80
	local cw, ch = GetCellDims()
	local gw, gh = ceil(cw * VCols), ceil(ch * VRows)

	Grid.grid = grid2D.Grid2D(Grid.group, nil, x, y, gw, gh, VCols, VRows, GridFunc)

	common.WallInRect(Grid.group, x, y, gw, gh)

	-- Add scroll buttons for each dimension where the level exceeds the grid.
	local x, y = display.contentWidth - 100, display.contentHeight - 230

	if nrows > RowBase then
		AddButton("uscroll", x, y)
		AddButton("dscroll", x, y + 65)

		y = y - 130
	end

	if ncols > ColBase then
		AddButton("lscroll", x, y)
		AddButton("rscroll", x, y + 65)
	end

	-- Add the offset text and initialize it and the scroll button opacities.
	Offset = display.newText(Grid.group, "", display.contentWidth - 170, display.contentHeight - 40, native.systemFont, 24)

	UpdateCoord(Col, Row, -1)

	-- Start out in the hidden state.
	M.Show(false)
end

---DOCME
-- @callable func
function M.Show (func)
	local show = not not func

	--
	if show then
		local target = Targets[func]

		if not target then
			target = display.newGroup()

			Targets[func] = target
		end

		for _, group in Iter() do
			Grid.group:insert(group)

			if group ~= target then
				group.alpha = .75
				group.isVisible = true

				group:toBack()
			end
		end

		Grid.grid:SetTarget(target, Grid.reserve)

		--
		local cw, ch = GetCellDims()

		target.x, target.y = -Col * cw, -Row * ch

		--
		Grid.group:toBack()

	--
	elseif Grid then -- TODO: Wrong check... (or the stuff after is wrong)
		Grid.grid:SetTarget(nil, Grid.reserve)

		for _, group in Iter() do
			Grid.reserve:insert(group)
		end
	end

	--
	Grid.func = func
	Grid.group.isVisible = show
end

---@bool show Enable showing multiple layers?
function M.ShowMultipleLayers (show)
	DoMultipleLayers = not not show
end

--
local function DefShowOrHide (item, show)
	item.isVisible = show
end

---DOCME
-- @ptable items
-- @callable func
function M.ShowOrHide (items, func)
	func = func or DefShowOrHide

	local redge, bedge = Col + VCols, Row + VRows

	for k, v in pairs(items) do
		local col, row = common.FromKey(k)

		func(v, col > Col and col <= redge and row > Row and row <= bedge)
	end
end

--- DOCME
function M.UpdatePick (group, pick, row, col, x, y, w, h)
	if group == "show" or group == "hide" then
		if pick and pick.m_col == col and pick.m_row == row then
			pick.isVisible = group == "show"
		end

	--
	else
		if not pick then
			pick = display.newRect(group, 0, 0, w, h)

			pick:setFillColor(255, 0, 0, 64)
		end

		pick.x, pick.y = x + w / 2, y + h / 2
		pick.isVisible = true

		pick.m_col = col
		pick.m_row = row

		pick:toBack()
	end

	return pick
end

-- Export the module.
return M