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
local max = math.max
local remove = table.remove
local sort = table.sort
local tonumber = tonumber

-- Modules --
local args = require("iterator_ops.args")
local button = require("ui.Button")
local common_ui = require("editor.CommonUI")
local keyboard = require("ui.Keyboard")
local layout = require("utils.Layout")
local persistence = require("game.Persistence")
local scenes = require("utils.Scenes")
local table_view_patterns = require("ui.patterns.table_view")

-- Corona globals --
local display = display
local native = native
local system = system

-- Corona modules --
local composer = require("composer")

-- Editor setup scene --
local Scene = composer.newScene()

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
function Scene:create ()
	button.Button(self.view, nil, 120, 70, 200, 50, scenes.WantsToGoBack, "Go Back")

	self.m_new_scene = button.Button(self.view, nil, display.contentWidth - (150 + 20), display.contentHeight - (20 + 50), 200, 50, function()
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

	self.m_cols_text = display.newText(self.view, ColText, 0, 150, native.systemFont, 24)
	self.m_rows_text = display.newText(self.view, RowText, 0, 210, native.systemFont, 24)

	self.m_cols_text.anchorX, self.m_cols_text.x = 0, 30
	self.m_rows_text.anchorX, self.m_rows_text.x = 0, 30

	if not OnDevice then
		self.m_keyboard = keyboard.Keyboard(self.view, { type = "nums" })
	end
end

Scene:addEventListener("create")

-- Updates levels listbox and related elements according to current choice
local function UpdateCurrent (scene, levels, index)
	scene.m_current.text = "Current choice: " .. levels[index].name

	layout.PutBelow(scene.m_current, scene.m_levels_list, 10)
	layout.LeftAlignWith(scene.m_current, scene.m_levels_list)

	scene.m_load_index = index
end

-- Clean up (conditional) elements used for scene loading
local function CleanupLoadElements ()
	for _, what in args.Args("m_current", "m_delete", "m_frame", "m_levels_list", "m_load") do
		display.remove(Scene[what])

		Scene[what] = nil
	end
end

-- Show Scene --
function Scene:show (event)
	if event.phase == "did" then
		scenes.SetListenFunc_GoBack("scene.Choices")

		-- Line up the text input (if on device, we use native keyboards) a little to the right
		-- of the columns or rows text (whichever was wider).
		local textx = self.m_cols_text.x + max(self.m_cols_text.width, self.m_rows_text.width) + 10

	 -- TODO: use object_helper...
		if OnDevice then
			self.m_cols = native.newTextField(textx, self.m_cols_text.y, 300, 65, function(event)
				if event.phase == "submitted" then
					native.setKeyboardFocus(self.m_rows)
				end
			end)

			self.m_rows = native.newTextField(textx, self.m_rows_text.y, 300, 65, function(event)
				if event.phase == "submitted" then
					native.setKeyboardFocus(nil)
				end
			end)

			self.m_cols.inputType = "number"
			self.m_rows.inputType = "number"

		-- In the simulator, fall back to buttons and a software keyboard.
		else
			local options = { is_modal = true }

			self.m_cols, self.m_colsedit = common_ui.EditableString(self.view, self.m_keyboard, textx, self.m_cols_text.y, options)
			self.m_rows, self.m_rowsedit = common_ui.EditableString(self.view, self.m_keyboard, textx, self.m_rows_text.y, options)

			self.m_keyboard:toFront()

			local w = .5 * self.m_colsedit.width

			for _, what in args.Args("m_cols", "m_colsedit", "m_rows", "m_rowsedit") do
				self[what]:translate(w, 0)
			end
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

			self.m_levels_list = table_view_patterns.Listbox(self.view, display.contentWidth - 350, 20, {
				--
				get_text = function(item)
					return item.name
				end,

				--
				press = function(event)
					UpdateCurrent(self, levels, event.index)
				end
			})

			self.m_current = display.newText(self.view, "", 0, 0, native.systemFont, 22)

			self.m_frame = common_ui.Frame(self.m_levels_list, 0, 0, 1)

			self.m_levels_list:AssignList(levels)

			UpdateCurrent(self, levels, 1)

			--
			local prev = self.m_new_scene

			for _, key, action, text in args.ArgsByN(3,
				-- Load Scene --
				"load", function()
					local level = levels[self.m_load_index]
					local params = persistence.Decode(level.data)

					params.is_loading = level.name

					scenes.GoToScene{ name = "scene.MapEditor", params = params }
				end, "Load Scene",

				-- Delete Scene --
				"delete", function()
					local index = self.m_load_index

					-- Remove the level from the database, the local sorted list, and the listbox.
					persistence.RemoveLevel(levels[index].name, true)

					remove(levels, index)

					self.m_levels_list:Delete(index)

					-- Update the listbox selection to reflect the missing element, or remove all the load
					-- elements entirely if no more levels exist.
					if #levels == 0 then
						CleanupLoadElements()
					else
						UpdateCurrent(self, levels, index <= #levels and index or index - 1)
					end
				end, "Delete scene"
			) do
				local button = button.Button(self.view, nil, 0, 0, 200, 50, action, text)

				layout.LeftAlignWith(button, prev)
				layout.PutAbove(button, prev, -20)

				self["m_" .. key], prev = button, button
			end
		end
	end
end

Scene:addEventListener("show")

-- Hide Scene --
function Scene:hide (event)
	if event.phase == "did" then
		self.m_cols:removeSelf()
		self.m_rows:removeSelf()

		if not OnDevice then
			self.m_colsedit:removeSelf()
			self.m_rowsedit:removeSelf()
		end

		CleanupLoadElements()

		scenes.SetListenFunc(nil)
	end
end

Scene:addEventListener("hide")

return Scene