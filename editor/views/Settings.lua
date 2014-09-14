--- Settings configuration for editor.

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

-- Standard libary imports --
local pairs = pairs

-- Modules --
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local grid = require("editor.Grid")

-- Exports --
local M = {}

-- Show layers checkbox --
local ShowLayers

---
-- @pgroup view X
function M.Load (view)
	ShowLayers = common_ui.CheckboxWithText(view, 175, 100, "Show other layers in grid?", {
		func = function(_, check)
			grid.ShowMultipleLayers(check)
		end,
		is_checked = true
	})
	-- Warning level?
	-- Replicate save to clipboard, console, log file, nothing?
	-- Other?
	-- common.AddHelp("settings", ...)
end

--- DOCMAYBE
function M.Enter ()
	ShowLayers.isVisible = true

	common.SetHelpContext("settings")
end

--- DOCMAYBE
function M.Exit ()
	ShowLayers.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	ShowLayers = nil
end

-- Listen to events.
for k, v in pairs {
	-- Build Level --
	build_level = function(level)
		level.settings = nil
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		for k, v in pairs(level.settings) do
			if k == "show_layers" then -- TODO: good enough for now...
				ShowLayers:Check(v)
			end
		end
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.settings = {
			show_layers = ShowLayers:IsChecked()
		}
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M