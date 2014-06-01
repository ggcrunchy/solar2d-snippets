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

-- Standard library imports --
local ceil = math.ceil
local format = string.format
local max = math.max
local min = math.min
local pairs = pairs

-- Modules --
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local grid2D = require("ui.Grid2D")

-- Corona globals --
local display = display
local native = native
local transition = transition

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
--[[
	if Grid then
		Grid.reserve:removeSelf()
	end
]]

	Grid, Offset, Targets = nil
end

--- Getter.
-- @treturn DisplayObject The global editor @{ui.Grid2D} widget.
--[[
function M.Get ()
	return Grid.grid
end
]]
--- DOCME
function M.GetHelp (func)
	if Grid.group--[[.grid.parent]].isVisible then
		common.GetHelp(func, "_Grid_")
	end
end

-- Column and row of upper-left cell --
local Col, Row

--- Getter.
-- @treturn uint Column offset... (i.e. upper-left cell visible on grid)
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
--[[
local function GridFunc (group, col, row, x, y, w, h)
	if Grid.func then
		local cw, ch = GetCellDims()

		Grid.func(group, Col + col, Row + row, x + Col * cw, y + Row * ch, w, h)
	end
end
]]
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

-- --
local ShowHideEvent = { name = "show" }

-- Helper to show or hide one or more layers
local function AuxShow (how, col, row)
	ShowHideEvent.show, ShowHideEvent.col, ShowHideEvent.row = how == "show", col, row
--[[
	for func in Iter(Grid.func) do
		func(how, col, row)
	end
]]
	for grid in Iter(Grid.active) do
		grid:dispatchEvent(ShowHideEvent)
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

	if Grid.active then--func then
		col = max(0, min(col, crange))
		row = max(0, min(row, rrange))

		--
		local target = Grid.active--[[grid]]:GetTarget()
		local cw, ch = GetCellDims()

		To.x, To.y = nil

		if col ~= Col then
			local dc, show, hide = GetShowHide(Col, col, VCols)

			Col = col

for grid in pairs(Targets) do
	grid:SetColOffset(col)
end

-- ^^^ SetColOffset() all
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

for grid in pairs(Targets) do
	grid:SetRowOffset(row)
end
-- ^^ SetRowOffset() all...
			-- 
			for col = 1, VCols do
				AuxShow("show", Col + col, show)
			end

			Hide.what, Hide.which = "row", hide

			To.y, rdelta = target.y - dr * ch, dr
		end

		--
		if To.x or To.y then
			for grid in pairs(Targets) do--Iter(Grid.active) do--_, group in Iter(nil, target) do
				transition.to(grid:GetTarget()--[[group]], To)
			end
			-- ^^ Should just do all anyway?
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
local function AddButton (name, x, y)--, dc, dr)
	local button = common_ui.ScrollButton(Grid.group, name, x, y, UpdateDir)

	button:translate(button.width / 2, button.height / 2)

	common.AddButton(name, button)
end

--
local function GridRect ()
	local cw, ch = GetCellDims()

	return 120, 80, ceil(cw * VCols), ceil(ch * VRows)
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
--[[
	Grid.reserve = display.newGroup()

	Grid.reserve.isVisible = false
]]
-- ^^ Defunct?
	-- Build the grid and put opaque elements around it to each side (as a lazy mask).
--[[
	local gx, gy = 120, 80
	local cw, ch = GetCellDims()
	local gw, gh = ceil(cw * VCols), ceil(ch * VRows)

	Grid.grid = grid2D.Grid2D(Grid.group, nil, gx, gy, gw, gh, VCols, VRows, GridFunc)

	common_ui.WallInRect(Grid.group, gx, gy, gw, gh)
-- ^^^ TODO: Just make a dummy rect (perhaps even in lieu of the proxy) with GridRect() dimensions
	local grid_proxy = common.Proxy(view, Grid.grid)
]]
	local grid_proxy = common.ProxyRect(view, GridRect())

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

	local n = Grid.group.numChildren
	local scroll_proxy = common.Proxy(view, Grid.group[n - 3], Grid.group[n - 2], Grid.group[n - 1], Grid.group[n])
-- ^^ Should be reordered? (would put nil's at right spot, if empty)
	-- Add the offset text and initialize it and the scroll button opacities.
	Offset = display.newText(Grid.group, "", display.contentWidth - 170, display.contentHeight - 40, native.systemFont, 24)

	UpdateCoord(Col, Row, -1)

	--
	common.AddHelp("_Grid_", {
		grid = "A marked cell on the grid indicates where the current selection will be appear.",
		offset = "Offset of upper-left cell in grid, from (0, 0)",
		scroll = "Scrolls the grid, i.e. updates the offset"
	})

	common.AddHelp("_Grid_", { grid = grid_proxy, offset = Offset, scroll = scroll_proxy })

	-- Start out in the hidden state.
	M.Show(false)
end

--- DOCME
function M.NewGrid ()
	local gx, gy, gw, gh = GridRect()
	local grid = grid2D.Grid2D(Grid.group, nil, gx, gy, gw, gh, VCols, VRows)

	grid:ShowBack(false)

	grid.isVisible = false

	Targets[grid] = true

	return grid
end

---DOCME
-- @callable func
function M.Show (target)--func)
	local show = not not target--func
-- ^^ "func" will be grids themselves...
	--
	if show then
--[[
		local target = Targets[func]

		if not target then
			target = display.newGroup()

			Targets[func] = target
		end
]]
		for grid in Iter(target) do--_, group in Iter() do
		--	Grid.group:insert(group)

			grid:ShowLines(grid == target)

			if grid == target then--group ~= target then
				grid.alpha = 1
			else
				grid--[[group]].alpha = .75
--				group.isVisible = true

				grid--[[group]]:toBack()
			end
-- ^^^ Where do these get set for the target?
			grid.isVisible = true
		end

	--	Grid.grid:SetTarget(target, Grid.reserve)

		--
		local cw, ch = GetCellDims()

		for grid in pairs(Targets) do
			local target = grid:GetTarget()

			target.x, target.y = grid:GetCellPos(Col, Row)-- -Col * cw, -Row * ch
		end
-- ^^ This needs to affect all of them
-- Actually, maybe this is pointless?
		--
		Grid.group:toBack()

	--
	elseif Grid then -- TODO: Wrong check... (or the stuff after is wrong)
--		Grid.grid:SetTarget(nil, Grid.reserve)

--		for _, group in Iter() do
--			Grid.reserve:insert(group)
--		end
		for grid in pairs(Targets) do
			grid.isVisible = false
		end
	end

	--
--	Grid.func = func
	Grid.active = target
	Grid.group.isVisible = show
end

--- Utility.
-- @bool show Enable showing multiple layers?
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
function M.ShowPick (pick, col, row, show)
	if pick and pick.m_col == col and pick.m_row == row then
		pick.isVisible = show
	end
end

--- DOCME
function M.UpdatePick (group, pick, col, row, x, y, w, h)
--[[
	if group == "show" or group == "hide" then
		if pick and pick.m_col == col and pick.m_row == row then
			pick.isVisible = group == "show"
		end
-- ^^ TODO: This is moved into ShowPick()
	--
	else]]
		if not pick then
			pick = display.newRect(group, 0, 0, w, h)

			pick:setFillColor(1, 0, 0, .25)
		end

		pick.x, pick.y = x, y-- + w / 2, y + h / 2
-- ^^ TODO: already translated?
		pick.isVisible = true

		pick.m_col = col
		pick.m_row = row

		pick:toBack()
--	end

	return pick
end

-- Export the module.
return M