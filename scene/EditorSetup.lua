--- Editor setup scene.
--
-- From this scene, users can either configure a new level to work on, or (if available)
-- load up a "work in progress" level.

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
local format = string.format
local ipairs = ipairs
local max = math.max
local remove = table.remove
local sort = table.sort
local tonumber = tonumber

-- Modules --
local button = require("ui.Button")
local common = require("editor.Common")
local keyboard = require("ui.Keyboard")
local persistence = require("game.Persistence")
local scenes = require("game.Scenes")

-- Corona globals --
local display = display
local native = native
local system = system

-- Corona modules --
local storyboard = require("storyboard")

-- Editor setup scene --
local Scene = storyboard.newScene()

-- Is this running on a device? --
local OnDevice = system.getInfo("environment") == "device"

-- Some reasonable column / row defaults --
local Cols, Rows = 10, 10

-- Helper to supply a message on bad input
local function AlertMessage (n, low, high, what)
	if not n then
		return format("Non-numeric or invalid %s value", what)
	elseif n % 1 ~= 0 then
		return format("%s must be an integer", what)
	elseif n < low or n > high then
		return format("%s must be between %i and %i, inclusive", what, low, high)
	end
end

-- Static part of columns / rows text --
local ColText = "Number of columns:"
local RowText = "Number of rows:"

-- Create Scene --
function Scene:createScene ()
	button.Button(self.view, nil, 20, 20, 200, 50, scenes.WantsToGoBack, "Go Back")
	button.Button(self.view, nil, display.contentWidth - (200 + 20), display.contentHeight - (20 + 50), 200, 50, function()
		local cols = tonumber(self.m_cols.text)
		local rows = tonumber(self.m_rows.text)

		-- Alert the user if the input is invalid (too high a number, malformed, etc.).
		-- Otherwise, proceed to the editor.
		local err = AlertMessage(cols, 8, 60, "# columns") or AlertMessage(rows, 8, 60, "# rows")

		if err then
			native.showAlert("Error!", err)
		else
			scenes.GoToScene{ name = "scene.MapEditor", params = { main = { cols, rows } } }
		end
	end, "New Scene")

	self.m_cols_text = display.newText(self.view, ColText, 50, 130, native.systemFont, 24)
	self.m_rows_text = display.newText(self.view, RowText, 50, 230, native.systemFont, 24)

	if not OnDevice then
		self.m_keyboard = keyboard.Keyboard(self.view, nil, "nums", 0, 0)
	end
end

Scene:addEventListener("createScene")

-- Updates levels listbox and related elements according to current choice
local function UpdateCurrent (scene, levels, index)
	local bounds = scene.m_levels_list.contentBounds
	local cur = scene.m_current

	cur.text = "Current choice: " .. levels[index].name

	cur:setReferencePoint(display.CenterLeftReferencePoint)

	cur.x = bounds.xMin
	cur.y = bounds.yMax + 25

	scene.m_load_index = index
end

-- Clean up (conditional) elements used for scene loading
local function CleanupLoadElements ()
	for _, what in ipairs{ "m_current", "m_delete", "m_levels_list", "m_DUMMY", "m_load" } do
		display.remove(Scene[what])

		Scene[what] = nil
	end
end

-- Enter Scene --
function Scene:enterScene ()
	scenes.SetListenFunc_GoBack("scene.Choices")

	-- Line up the text input (if on device, we use native keyboards) a little to the right
	-- of the columns or rows text (whichever was wider).
	local textx = max(self.m_cols_text.x + self.m_cols_text.width / 2, self.m_rows_text.x + self.m_rows_text.width / 2) + 10
	local colsy = self.m_cols_text.y - self.m_cols_text.height / 2
	local rowsy = self.m_rows_text.y - self.m_rows_text.height / 2

	if OnDevice then
		self.m_cols = native.newTextField(textx, colsy, 300, 65, function(event)
			if event.phase == "submitted" then
				native.setKeyboardFocus(self.m_rows)
			end
		end)

		self.m_rows = native.newTextField(textx, rowsy, 300, 65, function(event)
			if event.phase == "submitted" then
				native.setKeyboardFocus(nil)
			end
		end)

		self.m_cols.inputType = "number"
		self.m_rows.inputType = "number"

	-- In the simulator, fall back to buttons and a software keyboard.
	else
		local options = { is_modal = true }

		self.m_cols, self.m_colsedit = common.EditableString(self.view, self.m_keyboard, textx, colsy, options)
		self.m_rows, self.m_rowsedit = common.EditableString(self.view, self.m_keyboard, textx, rowsy, options)

		self.m_keyboard:toFront()
	end

	-- Add the actual text, now that the input widgets have been decided.
	self.m_cols.text = format("%i", Cols)
	self.m_rows.text = format("%i", Rows)

	-- If any WIP levels exist, enumerate them and put them in a listbox.
	local levels = persistence.GetLevels(true)

	if #levels > 0 then
		sort(levels, function(level1, level2)
			return level1.name < level2.name
		end)

		self.m_levels_list, self.m_DUMMY = common.Listbox(self.view, display.contentWidth - 350, 20)
		self.m_current = display.newText(self.view, "", 0, 0, native.systemFont, 22)

		local add_row = common.ListboxRowAdder(function(index)
			UpdateCurrent(self, levels, index)
		end, nil, function(index)
			return levels[index].name
		end)

		for _ = 1, #levels do
			self.m_levels_list:insertRow(add_row)
		end

		UpdateCurrent(self, levels, 1)

		self.m_delete = button.Button(self.view, nil, display.contentWidth - (200 + 20), display.contentHeight - (20 + 190), 200, 50, function()
			local index = self.m_load_index

			-- Remove the level from the database, the local sorted list, and the listbox.
			persistence.RemoveLevel(levels[index].name, true)

			remove(levels, index)

			self.m_levels_list:deleteRow(index)

			-- Update the listbox selection to reflect the missing element, or remove all
			-- the load elements entirely if no more levels exist.
			if #levels == 0 then
				CleanupLoadElements()
			else
				UpdateCurrent(self, levels, index <= #levels and index or index - 1)
			end
		end, "Delete scene")

		self.m_load = button.Button(self.view, nil, display.contentWidth - (200 + 20), display.contentHeight - (20 + 120), 200, 50, function()
			local level = levels[self.m_load_index]
			local params = persistence.Decode(level.data)

			params.is_loading = level.name

			scenes.GoToScene{ name = "scene.MapEditor", params = params }
		end, "Load Scene")
	end
end

Scene:addEventListener("enterScene")

-- Exit Scene --
function Scene:exitScene ()
	self.m_cols:removeSelf()
	self.m_rows:removeSelf()

	if not OnDevice then
		self.m_colsedit:removeSelf()
		self.m_rowsedit:removeSelf()
	end

	CleanupLoadElements()

	scenes.SetListenFunc(nil)
end

Scene:addEventListener("exitScene")

return Scene