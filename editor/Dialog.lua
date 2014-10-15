--- A dialog-type widget.

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

-- Method modules --
local dialog_data = require("editor.dialog.Data")
local dialog_items = require("editor.dialog.Items")
local dialog_layout = require("editor.dialog.Layout")
local dialog_methods = require("editor.dialog.Methods")
local utils = require("editor.dialog.Utils")

-- Modules --
local common = require("editor.Common")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Import dialog methods.
local Methods = {} 

for _, mod in ipairs{ dialog_data, dialog_items, dialog_layout, dialog_methods } do
	for k, v in pairs(mod) do
		Methods[k] = v
	end
end

--- DOCME
-- @pgroup group Group to which the dialog will be inserted.
-- @ptable options
--
-- **CONSIDER**: In EVERY case so far I've used _name_ = **true**...
function M.Dialog (group, options)
	--
	local dgroup = display.newGroup()

	group:insert(dgroup)

	--
	utils.AddBack(dgroup, 1, 1)

	--
	local igroup = display.newGroup()

	dgroup.m_items = igroup

	dgroup:insert(igroup)

	--
	if options and options.is_modal then
		common.AddNet(group, dgroup)
	end

	-- Install methods from submodules.
	for k, v in pairs(Methods) do
		dgroup[k] = v
	end

	return dgroup
end

-- Helper to populate defaults
local function GetDefaults (on_editor_event, type, key)
	local defs = { name = type .. " " .. key, type = type }

	on_editor_event(type, "enum_defs", defs)

	return defs
end

--- DOCME
-- @callable on_editor_event
-- @treturn function X
function M.DialogWrapper (on_editor_event)
	local dialog, dx, dy

	-- If we're closing a dialog (or switching to a different one), remember the
	-- current dialog's position, so that the next dialog can appear there.
	local function BeforeRemove ()
		dx, dy, dialog = dialog.x, dialog.y
	end

	return function(what, arg1, arg2, arg3, arg4)
		--
		if what == "get_dialog" then
			return dialog

		--
		-- arg1: Value type
		elseif what == "get_tag" then
			return common.GetTag(arg1, on_editor_event)

		--
		-- arg1: Value type
		-- arg2: Key
		elseif what == "new_values" then
			return GetDefaults(on_editor_event, arg1, arg2)

		--
		-- arg1: Values table
		elseif what == "is_bound" or what == "edit" then
			local is_bound = dialog and dialog:IsBoundToValues(arg1)

			if what == "is_bound" or is_bound then
				return is_bound
			end
		end

		--
		if (what == "close" or what == "edit") and dialog then
			dialog:RemoveSelf()
		end

		--
		-- arg1: Values to edit
		-- arg2: Group
		-- arg3: Key
		-- arg4: Representative object
		if what == "edit" then
			if arg1 then
				dialog = M.Dialog(arg2)

				dialog:BindDefaults(GetDefaults(on_editor_event, arg1.type, arg3))
				dialog:BindValues(arg1)
				dialog:SetBeforeRemove(BeforeRemove)

				on_editor_event(arg1.type, "enum_props", dialog, arg4)

				dialog.x = dx or display.contentCenterX - dialog.width / 2
				dialog.y = dy or display.contentCenterY - dialog.height / 2
				-- todo: clamping...
			end
		end
	end
end

-- Export the module.
return M