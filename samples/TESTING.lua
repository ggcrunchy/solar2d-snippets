--- Staging area.

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

-- Corona modules --
local composer = require("composer")

-- --
local Scene = composer.newScene()

local M

do
	-- Standard library imports --
	local remove = table.remove

	-- Modules --
	local array_index = require("array_ops.index")
	local colors = require("ui.Color")
	local grid_iterators = require("iterator_ops.grid")
	local mask = require("utils.Mask")
	local range = require("number_ops.range")
	local skins = require("ui.Skin")
	local touch = require("ui.Touch")
	local utils = require("ui.Utils")

	-- Corona globals --
	local display = display

	-- Exports --
	--local
	M = {}

	--
	local function Cell (grid, x, y)
		local gx, gy = grid:contentToLocal(x, y)
		local col = array_index.FitToSlot(gx, -grid.width / 2, grid.width / grid.m_ncols)
		local row = array_index.FitToSlot(gy, -grid.height / 2, grid.height / grid.m_nrows)

		return col, row
	end

	--
	local function PosDim (grid)
		local x, dw = grid.x - .5 * grid.width, grid.width / grid.m_ncols
		local y, dh = grid.y - .5 * grid.height, grid.height / grid.m_nrows

		return x, y, dw, dh
	end

	--
	local function GetTarget (grid)
		return grid.parent.parent:GetTarget()
	end

	-- Touch listener
	local Touch = touch.TouchHelperFunc(function(event, grid)
		-- Track initial coordinates for dragging.
		local col, row = Cell(grid, event.x, event.y)
		local x, y, dw, dh = PosDim(grid)

		grid.m_func(GetTarget(grid), col, row, x + (col - 1) * dw, y + (row - 1) * dh, dw, dh)

		grid.m_col, grid.m_row = col, row
	end, function(event, grid)
		-- Fit the new position to a cell and do the callback on it if the cell has changed.
		-- Since moving may skip over intervening cells, we do a line traversal to approximate
		-- the path, likewise performing callbacks on each cell in between.
		local end_col, end_row = Cell(grid, event.x, event.y)

		end_col = range.ClampIn(end_col, 1, grid.m_ncols)
		end_row = range.ClampIn(end_row, 1, grid.m_nrows)

		local x, y, dw, dh = PosDim(grid)
		local func, group = grid.m_func, GetTarget(grid)
		local first = true

		-- TODO: I have gotten an "y1 is nil" error...
		for col, row in grid_iterators.LineIter(grid.m_col, grid.m_row,	end_col, end_row) do
			if not first then
				func(group, col, row, x + (col - 1) * dw, y + (row - 1) * dh, dw, dh)
			end

			first = false
		end

		-- Commit the new previous coordinates.
		grid.m_col = end_col
		grid.m_row = end_row
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
	-- @callable func
	-- @treturn DisplayGroup Child #1: the background; Child #2: the target + lines group.
	-- @see ui.Skin.GetSkin
	function M.Grid2D (group, skin, x, y, w, h, cols, rows, func)
		skin = skins.GetSkin(skin)

		local ggroup = display.newGroup()

		group:insert(ggroup)

		--
		local cgroup = display.newContainer(w, h)

		ggroup:insert(cgroup)

		cgroup.x, cgroup.y = x, y

		--
		local target = display.newGroup()

		cgroup:insert(target, true)
		target:translate(-w / 2, -h / 2)

		--
		local back = display.newRect(0, 0, w, h)

		cgroup:insert(back, true)
		cgroup:translate(w / 2, h / 2)

		if not skin.grid2d_backopaque then
			back.isHitTestable = true
			back.isVisible = false
		end

		back:setFillColor(colors.GetColor(skin.grid2d_backcolor))

		back.m_ncols = cols
		back.m_nrows = rows
		back.m_func = func

		--
		back:addEventListener("touch", Touch)

		--
		local lgroup = display.newGroup()

		ggroup:insert(lgroup)

		local xoff, dw = 0, w / cols

		for _ = 1, cols + 1 do
			AddGridLine(lgroup, skin, x + xoff, y, x + xoff, y + h)

			xoff = xoff + dw
		end

		local yoff, dh = 0, h / rows

		for _ = 1, rows + 1 do
			AddGridLine(lgroup, skin, x, y + yoff, x + w, y + yoff)

			yoff = yoff + dh
		end

		---DOCME
		-- @treturn DisplayGroup X
		function ggroup:GetTarget ()
			return target
		end

		--- DOCME
		-- @string name
		-- @string dir
		function ggroup:SetMask (name, dir)
			utils.SetMask(self, back, name, dir)
		end

		---DOCME
		-- @pgroup target
		-- @pgroup reserve
		function ggroup:SetTarget (target, reserve)
			utils.SetTarget(self, target, lgroup, reserve)
		end

		--- Manually performs a touch (or drag) on the grid.
		--
		-- This will trigger the grid's current touch behavior. Any in-progress touch state
		-- is preserved during this call.
		-- @uint col Initial touch column...
		-- @uint row ...and row.
		-- @uint cto Final column... (If absent, _col_.)
		-- @uint rto ...and row. (Ditto for _row_.)
		function ggroup:TouchCell (col, row, cto, rto)
			local scol, srow, x, y, dw, dh = self.m_col, self.m_row, PosDim(back)
			local event = remove(Events) or { name = "touch", id = "ignore_me" }

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
		function ggroup:TouchXY (x, y, xto, yto)
			local col, row = Cell(back, x, y)

			self:TouchCell(col, row, Cell(back, xto or x, yto or y))
		end

		-- Provide the grid.
		return ggroup
	end

	-- Main 2D grid skin --
	skins.AddToDefaultSkin("grid2d", {
		backcolor = { .375, .375, .375, .75 },
		backopaque = true,
		linecolor = "white",
		linewidth = 2
	})

	-- Export the module.
	--return M
end

--
function Scene:create ()
	self.gg = M.Grid2D(self.view, nil, 20, 20, 400, 400, 10, 10,
	function(group, col, row, x, y, dw, dh)
	--
	end)

-- TODO: Get several atop one another working right...
end

Scene:addEventListener("create")

--
function Scene:show ()

end

Scene:addEventListener("show")

return Scene