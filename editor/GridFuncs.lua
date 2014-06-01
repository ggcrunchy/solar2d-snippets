--- Various useful, somewhat general grid functions.

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

-- Modules --
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local grid = require("editor.Grid")
local grid1D = require("ui.Grid1D")
local links = require("editor.Links")
local sheet = require("ui.Sheet")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--- Common logic for the **PAINT** / **EDIT** / **ERASE** combination of grid operations.
-- @callable dialog_wrapper Cf. the result of @{editor.Dialog.DialogWrapper}.
-- @array types An array of strings denoting type.
-- @treturn function A "common ops" wrapper for an editor view. Its signature starts with a
-- _what_ parameter, then all grid function parameters, cf. _func_ in @{ui.Grid2D.Grid2D}.
--
-- The following choices are available for _what_:
--
-- * **"grid"**: Boilerplate: editor grid function body.
-- * **"load"**: Boilerplate: editor view being loaded... (The assets directory prefix, viz.
-- in **"_prefix_\_Assets/", is passed through _col_, and a title for the current tile
-- @{ui.Grid1D} is passed through _row_.)
-- * **"enter"**: ...entered... (The grid function is passed through _col_.)
-- * **"exit"**: ...exited...
-- * **"unload"**: ...or unloaded.
-- * **"get_current"**: Returns the current tile @{ui.Grid1D}.
-- * **"get_values"**: Returns the values table.
-- * **"get_values_and_tiles"**: Returns the values and tiles tables.

--- DOCME (i.e. bring the above stuff back into sync)
function M.EditErase (dialog_wrapper, types)
	local cells, current, option, pick, tabs, tiles, try_option, tile_images, values

-- TODO: HACK!
local GRIDHACK
-- /TODO

	--
	local function Cell (event)
		local key, which = common.ToKey(event.col, event.row), current:GetCurrent()
		local cur, tile = values[key], tiles[key]
		local target, cw, ch = event.target:GetTarget(), event.target:GetCellDims()

		--
		pick = grid.UpdatePick(target, pick, event.col, event.row, event.x, event.y, cw, ch)

		--
		if option == "Edit" then
			if cur then
				dialog_wrapper("edit", cur, current.parent, key, tile)
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
		elseif not cur or sheet.GetSpriteSetImageFrame(tile) ~= which then -- TODO: can 'tile' sub for 'cur' ?(then we have a pattern...)
			if tile then
				links.RemoveTag(tile)
			end

			values[key] = dialog_wrapper("new_values", types[which], key)
			tiles[key] = tile or sheet.NewImage(target, tile_images, event.x, event.y, cw, ch)

			sheet.SetSpriteSetImageFrame(tiles[key], which)

			--
			local tag = dialog_wrapper("get_tag", types[which])

			if tag then
				common.BindRepAndValues(tiles[key], values[key])

				links.SetTag(tiles[key], tag)
			end

			common.Dirty()
		end
	end

	--
	local function ShowHide (event)
		local key = common.ToKey(event.col, event.row)

		if values[key] then
			tiles[key].isVisible = event.show
		end

		grid.ShowPick(pick, event.col, event.row, event.show)
	end

	--
	local View = {}

	--- DOCME
	function View:Enter ()
		grid.Show(cells)
		try_option(tabs, option)
		common.ShowCurrent(current, option == "Paint")

		tabs.isVisible = true
-- TODO: Hack!
GRIDHACK.isHitTestable = true 
-- /TODO
	end

	--- DOCME
	function View:Exit ()
		dialog_wrapper("close")

		common.SetChoice(option)
		common.ShowCurrent(current, false)

		tabs.isVisible = false
-- TODO: Hack!
GRIDHACK.isHitTestable = false 
-- /TODO
		grid.Show(false)
	end

	--- DOCME
	function View:GetCurrent ()
		return current
	end

	-- ^^ RENAME, while about it? (e.g. choice)

	--- DOCME
	function View:GetGrid ()
		return cells
	end

	--- DOCME
	function View:GetTiles ()
		return tiles
	end

	--- DOCME
	function View:GetValues ()
		return values
	end

	--- DOCME
	function View:Load (group, prefix, title)
		values, tiles, cells = {}, {}, grid.NewGrid()

		cells:addEventListener("cell", Cell)
		cells:addEventListener("show", ShowHide)

		--
		current = grid1D.OptionsHGrid(group, nil, 150, 50, 200, 100, title)
-- ^^ TODO: group
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

					return true
				end
			}
		end

		tabs = common_ui.TabBar(group, tab_buttons, { top = display.contentHeight - 65, left = 120, width = 300 }, true)
-- ^^ TODO: group
		tabs:setSelected(1, true)

		-- TODO: Hack!
		GRIDHACK = common_ui.TabsHack(group, tabs, #tab_buttons)
-- ^^ TODO: group
		GRIDHACK.isHitTestable = false 
		-- /TODO

		--
		try_option = common.ChoiceTrier(tab_buttons)

		--
		tile_images = common.SpriteSetFromThumbs(prefix, types)

		current:Bind(tile_images, #tile_images)
		current:toFront()

		common.ShowCurrent(current, false)

		--
		common.AddHelp(prefix, { current = current, tabs = tabs })
	end

	--- DOCME
	function View:Unload ()
		tabs:removeSelf()

		cells, current, option, pick, tabs, tiles, tile_images, try_option, values = nil
	end

	return View
end

-- Export the module.
return M