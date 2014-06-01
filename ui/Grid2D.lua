--- 2D grid UI elements.
--
-- @todo Document skin...

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
local floor = math.floor
local remove = table.remove

-- Modules --
local array_index = require("array_ops.index")
local colors = require("ui.Color")
local grid_iterators = require("iterator_ops.grid")
local range = require("number_ops.range")
local skins = require("ui.Skin")
local touch = require("ui.Touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
local function GetCellDims (back)
	return back.width / back.m_ncols, back.height / back.m_nrows
end

--
local function Cell (back, x, y)
	local gx, gy = back:contentToLocal(x, y)
	local dw, dh = GetCellDims(back)
	local col = array_index.FitToSlot(gx, -back.width / 2, dw)
	local row = array_index.FitToSlot(gy, -back.height / 2, dh)

	return col, row
end

-- Event to dispatch --
local Event = {}

-- Dispatch events to grid
local function Dispatch (back, col, row, x, y, is_first)
	local grid = back.parent.parent

	Event.name = "cell"
	Event.target = grid
	Event.col, Event.x = col, floor(x)
	Event.row, Event.y = row, floor(y)
	Event.is_first = is_first

	grid:dispatchEvent(Event)
end

--
local function GetOffsets (back)
	return (back.m_coffset or 0) - back.m_cx, (back.m_roffset or 0) - back.m_cy
end

-- Touch listener
local Touch = touch.TouchHelperFunc(function(event, back)
	-- Track initial coordinates for dragging.
	local coff, roff = GetOffsets(back)
	local col, row = Cell(back, event.x, event.y)
	local dw, dh = GetCellDims(back)

	Dispatch(back, col, row, (col + coff) * dw, (row + roff) * dh, true)

	back.m_col, back.m_row, Event.target = col, row
end, function(event, back)
	-- Fit the new position to a cell and do the callback on it if the cell has changed.
	-- Since moving may skip over intervening cells, we do a line traversal to approximate
	-- the path, likewise performing callbacks on each cell in between.
	local end_col, end_row = Cell(back, event.x, event.y)

	end_col = range.ClampIn(end_col, 1, back.m_ncols)
	end_row = range.ClampIn(end_row, 1, back.m_nrows)

	local first, dw, dh = true, GetCellDims(back)
	local coff, roff = GetOffsets(back)

	-- TODO: I have gotten an "y1 is nil" error...
	for col, row in grid_iterators.LineIter(back.m_col, back.m_row, end_col, end_row) do
		if not first then
			Dispatch(back, col, row, (col + coff) * dw, (row + roff) * dh, false)
		end

		first = false
	end

	-- Commit the new previous coordinates.
	back.m_col = end_col
	back.m_row = end_row
end)

-- Common line add logic
local function AddGridLine (group, skin, x1, y1, x2, y2)
	local line = display.newLine(group, x1, y1, x2, y2)

	line.strokeWidth = skin.grid2d_linewidth

	line:setStrokeColor(colors.GetColor(skin.grid2d_linecolor))
end

-- Cache of simulated touch events --
local Events = {}

---DOCME
-- @pgroup group Group to which grid will be inserted.
-- @param skin Name of grid's skin.
-- @number x
-- @number y
-- @number w
-- @number h
-- @uint cols
-- @uint rows
-- @treturn DisplayGroup Child #1: the background; Child #2: the target + lines group. 
-- @see ui.Skin.GetSkin
function M.Grid2D (group, skin, x, y, w, h, cols, rows)
	skin = skins.GetSkin(skin)

	local Grid = display.newGroup()

	group:insert(Grid)

	--
	local cgroup = display.newContainer(w, h)

	Grid:insert(cgroup, true)

	cgroup.x, cgroup.y = x, y

	--
	local target = display.newGroup()
	local back = display.newRect(0, 0, w, h)
	local halfw, halfh = floor(w / 2), floor(h / 2)

	cgroup:insert(back, true)
	cgroup:translate(halfw, halfh)
	cgroup:insert(target, true)
	target:translate(-halfw, -halfh)

	--
	back:setFillColor(colors.GetColor(skin.grid2d_backcolor))

	back.m_ncols, back.m_cx = cols, .5
	back.m_nrows, back.m_cy = rows, .5

	--
	back:addEventListener("touch", Touch)

	--
	if skin.grid2d_trapinput then
		back.isHitTestable = true
	end

	--
	local lines = display.newGroup()
	local xf, yf = x + w - 1, y + h - 1

	Grid:insert(lines)

	--
	local xoff, dw = 0, w / cols

	for _ = 1, cols do
		local cx = floor(x + xoff)

		AddGridLine(lines, skin, cx, y, cx, yf)

		xoff = xoff + dw
	end

	AddGridLine(lines, skin, xf, y, xf, yf)

	--
	local yoff, dh = 0, h / rows

	for _ = 1, rows do
		local cy = floor(y + yoff)

		AddGridLine(lines, skin, x, cy, xf, cy)

		yoff = yoff + dh
	end

	AddGridLine(lines, skin, x, yf, xf, yf)

	--- DOCME
	-- @treturn uint W
	-- @treturn uint H
	function Grid:GetCellDims ()
		return GetCellDims(back)
	end

	--- DOCME
	-- @treturn DisplayGroup X
	function Grid:GetTarget ()
		return target
	end

	--- DOCME
	-- @number x
	-- @number y
	function Grid:SetCentering (x, y)
		back.m_cx = 1 - range.ClampIn(x, 0, 1)
		back.m_cy = 1 - range.ClampIn(y, 0, 1)
	end

	--- DOCME
	-- @uint coffset
	function Grid:SetColOffset (coffset)
		back.m_coffset = coffset
	end

	--- DOCME
	-- @uint roffset
	function Grid:SetRowOffset (roffset)
		back.m_roffset = roffset
	end

	--- DOCME
	-- @bool show
	function Grid:ShowBack (show)
		back.isVisible = show
	end

	--- DOCME
	-- @bool show
	function Grid:ShowLines (show)
		lines.isVisible = show
	end

	--- Manually performs a touch (or drag) on the grid.
	--
	-- This will trigger the grid's current touch behavior. Any in-progress touch state
	-- is preserved during this call.
	-- @uint col Initial touch column...
	-- @uint row ...and row.
	-- @uint cto Final column... (If absent, _col_.)
	-- @uint rto ...and row. (Ditto for _row_.)
	function Grid:TouchCell (col, row, cto, rto)
		local scol, srow, x, y = self.m_col, self.m_row, back:localToContent(-.5 * back.width, -.5 * back.height)
		local event, dw, dh = remove(Events) or { name = "touch", id = "ignore_me" }, GetCellDims(back)
	--	local dc, dr = (back.m_coffset or 0) - .5, (back.m_roffset or 0) - .5

		event.target, event.x, event.y = back, x + (col - .5) * dw, y + (row - .5) * dh
		event.phase = "began"

		Touch(event)

		cto, rto = cto or col, rto or row

		if col ~= cto or row ~= rto then
			event.x, event.y = x + (cto - .5) * dw, y + (rto - .5) * dh
			event.phase = "moved"

			Touch(event)
		end

		event.phase = "ended"

		Touch(event)

		self.m_col, self.m_row, event.target = scol, srow

		Events[#Events + 1] = event
	end

	--- Variant of @{ggroup:TouchCell} that uses x- and y-coordinates.
	-- @number x Initial touch x-coordinate.
	-- @number y ...and y-coordinate.
	-- @number xto Final x... (If absent, _x_.)
	-- @number yto ...and y. (Ditto for _y_.)
	function Grid:TouchXY (x, y, xto, yto)
		local col, row = Cell(back, x, y)

		self:TouchCell(col, row, Cell(back, xto or x, yto or y))
	end

	-- Provide the grid.
	return Grid
end

-- Main 2D grid skin --
skins.AddToDefaultSkin("grid2d", {
	backcolor = { .375, .375, .375, .75 },
	linecolor = "white",
	linewidth = 2,
	trapinput = true
})

-- Export the module.
return M