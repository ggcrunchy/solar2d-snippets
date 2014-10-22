--- Various useful, somewhat general grid view objects, and associated logic.

-- The following methods are available:
--
-- * **"grid"**: Boilerplate: editor grid function body.
-- * **"load"**: Boilerplate: editor view being loaded... (The assets directory prefix, viz.
-- in **"_prefix_\_Assets/", is passed through _col_, and a title for the current tile
-- @{ui.Grid1D} is passed through _row_.)
-- * **Enter(view)**: The editor view is being entered... (
-- * **Exit**: ...exited...
-- * **Load(group, prefix, title)**:
-- * **Unload**: ...or unloaded.
-- * **GetCurrent**: Returns the current tile @{ui.Grid1D}.
-- * **GetGrid**: @{corona_ui.widgets.grid.Grid}
-- * **GetValues**: Returns the values table.
-- * **GetTiles**: Returns the values and tiles tables.

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
local ipairs = ipairs
local min = math.min
local type = type

-- Modules --
local common = require("editor.Common")
local grid = require("editor.Grid")
local grid1D = require("corona_ui.widgets.grid_1D")
local help = require("editor.Help")
local links = require("editor.Links")
local sheet = require("corona_ui.utils.sheet")
local str_utils = require("tektite_core.string")
local tabs_patterns = require("corona_ui.patterns.tabs")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--- DOCME
-- @pgroup group
-- @array names
-- @callable func
-- @uint w
-- @treturn DisplayObject X
function M.AddTabs (group, names, func, w)
	local buttons = {}

	for i, label in ipairs(names) do
		buttons[i] = { label = label, onPress = func(label) }
	end

	local tabs = tabs_patterns.TabBar(group, buttons, { top = display.contentHeight - 65, left = 120, width = w })

	tabs.isVisible = false

-- HACK!
local GRIDHACK = tabs_patterns.TabsHack(group, tabs, #buttons)
local old = getmetatable(tabs)
setmetatable(tabs, {
	__index = old.__index,
	__newindex = function(t, k, v)
		if k == "isVisible" then
			GRIDHACK.isHitTestable = v
		end

		old.__newindex(t, k, v)
	end
})
GRIDHACK.isHitTestable = false
tabs:addEventListener("finalize", function()
	if GRIDHACK.parent then
		GRIDHACK:removeSelf()
	end
end)
-- /HACK

	tabs:setSelected(1, true)

	return tabs
end

--
local function CircleUpdate (canvas, tile, x, y, cw, ch)
	tile = tile or display.newCircle(canvas, 0, 0, min(cw, ch) / 2)

	tile:setStrokeColor(1, 0, 0)

	tile.strokeWidth, tile.x, tile.y = 3, x, y

	return tile
end

--- DOCME
function M.CircleUpdate (grid, x, y, tile)
	return CircleUpdate(grid:GetCanvas(), tile, x, y, grid:GetCellDims())
end

--
local function DefSame (tile)
	return tile
end

--
local function FrameSame (tile, which, cur) -- TODO: can 'tile' sub for 'cur' ?(then we have a pattern...)
	return cur and sheet.GetSpriteSetImageFrame(tile) == which
end

--
local function FrameUpdate (canvas, tile, x, y, cw, ch, tile_images, which)
	tile = tile or sheet.NewImage(canvas, tile_images, x, y, cw, ch)

	sheet.SetSpriteSetImageFrame(tile, which)

	return tile
end

--
local function ImageUpdate (canvas, tile, x, y, cw, ch, tile_images)
	-- Like FrameUpdate, but "tile_images" is a filename
end

--- Common logic for the **PAINT** / **EDIT** / **ERASE** combination of grid operations.
-- @callable dialog_wrapper Cf. the result of @{editor.Dialog.DialogWrapper}.
-- @tparam array|string types An array of strings denoting type.
-- @string[opt=""] palette 
-- @treturn GridView Editor grid view object.
function M.EditErase (dialog_wrapper, types, palette)
	local cells, current, option, pick, tabs, tiles, try_option, tile_images, values

	--
	local same, update = DefSame

	if palette == "circle" then
		update = CircleUpdate
	elseif #(palette or "") ~= 0 then
		update, tile_images = ImageUpdate, palette
	else
		same, update = FrameSame, FrameUpdate
	end

	--
	local function Cell (event)
		local key, which = str_utils.PairToKey(event.col, event.row), current and current:GetCurrent()
		local cur, tile = values[key], tiles[key]
		local canvas, cw, ch = event.target:GetCanvas(), event.target:GetCellDims()

		--
		pick = grid.UpdatePick(canvas, pick, event.col, event.row, event.x, event.y, cw, ch)

		--
		if option == "Edit" then
			if cur then
				dialog_wrapper("edit", cur, tabs.parent, key, tile)
			else
				dialog_wrapper("close")
			end

		--
		elseif option == "Erase" then
			if tile then
				tile:removeSelf()

				common.BindRepAndValues(tile, nil)
				common.Dirty()
			end

			values[key], tiles[key] = nil

		--
		elseif not same(tile, which, cur) then 
			if tile then
				links.RemoveTag(tile)
			end

			local vtype = type(types) == "string" and types or types[which]

			values[key] = dialog_wrapper("new_values", vtype, key)
			tiles[key] = update(canvas, tile, event.x, event.y, cw, ch, tile_images, which)

			--
			local tag = dialog_wrapper("get_tag", vtype)

			if tag then
				common.BindRepAndValues(tiles[key], values[key])
				links.SetTag(tiles[key], tag)
			end

			common.Dirty()
		end
	end

	--
	local function ShowHide (event)
		local key = str_utils.PairToKey(event.col, event.row)

		if values[key] then
			tiles[key].isVisible = event.show
		end

		grid.ShowPick(pick, event.col, event.row, event.show)
	end

	--
	local EditEraseGridView = {}

	--- DOCME
	function EditEraseGridView:Enter ()
		grid.Show(cells)
		try_option(tabs, option)

		if current then
			common.ShowCurrent(current, option == "Paint")
		end

		tabs.isVisible = true
	end

	--- DOCME
	function EditEraseGridView:Exit ()
		dialog_wrapper("close")

		grid.SetChoice(option)

		if current then
			common.ShowCurrent(current, false)
		end

		tabs.isVisible = false

		grid.Show(false)
	end

	--- DOCME
	function EditEraseGridView:GetCurrent ()
		return current
	end

	-- ^^ RENAME, while about it? (e.g. choice)

	--- DOCME
	function EditEraseGridView:GetGrid ()
		return cells
	end

	--- DOCME
	function EditEraseGridView:GetTiles ()
		return tiles
	end

	--- DOCME
	function EditEraseGridView:GetValues ()
		return values
	end

	--- DOCME
	function EditEraseGridView:Load (group, prefix, title)
		values, tiles, cells = {}, {}, grid.NewGrid()

		cells:addEventListener("cell", Cell)
		cells:addEventListener("show", ShowHide)

		--
		if update == FrameUpdate then
			current = grid1D.OptionsHGrid(group, nil, 150, 50, 200, 100, title)
		end

		--
		local choices = { "Paint", "Edit", "Erase" }

		tabs = M.AddTabs(group, choices, function(label)
			return function()
				option = label

				if current then
					common.ShowCurrent(current, label == "Paint")
				end

				if label ~= "Edit" then
					dialog_wrapper("close")
				end

				return true
			end
		end, 300)

		--
		try_option = grid.ChoiceTrier(choices)

		--
		if current then
			tile_images = common.SpriteSetFromThumbs(prefix, types)

			current:Bind(tile_images, #tile_images)
			current:toFront()

			common.ShowCurrent(current, false)
		end

		--
		help.AddHelp(prefix, { current = current, tabs = tabs })
	end

	--- DOCME
	function EditEraseGridView:Unload ()
		tabs:removeSelf()

		cells, current, option, pick, tabs, tiles, tile_images, try_option, values = nil
	end

	return EditEraseGridView
end

-- Export the module.
return M