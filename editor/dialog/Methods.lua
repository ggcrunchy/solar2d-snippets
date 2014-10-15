--- Various dialog methods.

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
-- Modules --
local editable_patterns = require("corona_ui.patterns.editable")
local utils = require("editor.dialog.Utils")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

--
local function OnTextChange (event)
	local str = event.target

	utils.UpdateObject(str, event.new_text, str:GetChildOfParent())
end

--- DOCMEMORE
-- Common logic to add another widget to the dialog
function M:CommonAdd (object, options, static_text)
	-- Reflow around the object, if it exists.
	if object then
		self:Update(object)
	end

	local continue_line, text

	if options then
		-- If text was updated, check if it's static. If so, just bake it in; otherwise,
		-- make the text into editable strings. This will add one or two more objects to
		-- the dialog, so reflow after each of these as well.
		if options.text then
			local igroup = self:ItemGroup()

			if static_text then
				text = display.newText(igroup, options.text, 0, 0, native.systemFontBold, 22)
			else
				text = editable_patterns.Editable(igroup, options)

				text:addEventListener("text_change", OnTextChange)
			end

			self:Update(text)
		end

		-- If no object was supplied, the text will be the object instead. Associate a
		-- friendly name and value name to the object and note any further options.
		local name = options.name or options.value_name
		local oprops = utils.GetProperty_Table(object or text)

		oprops.name = name
		oprops.value_name = options.value_name

		continue_line = options.continue_line
	end

	-- Most commonly, we want to advance to the next line.
	if not continue_line then
		self:NewLine()
	end
end

--- Searches by name for an object in the dialog.
-- @param name Object name, as passed through **name** in the object's _options_. If
-- the name was **true**, the final name will be the value of **value\_name**.
-- @treturn DisplayObject Object, or **nil** if not found.
function M:Find (name)
	local igroup, item = self:ItemGroup()

	for i = 1, igroup.numChildren do
		item = igroup[i]

		if utils.GetProperty(item, "name") == name then
			break
		end
	end

	return item
end

--- DOCME
function M:ItemGroup ()
	return self.m_items
end

--- Removes the dialog. This does some additional cleanup beyond what is done by
-- `display.remove` and `object:removeSelf`.
function M:RemoveSelf ()
	self.m_defs = nil
	self.m_values = nil

	if self.m_before_remove then
		self:m_before_remove()
	end

	local igroup = self:ItemGroup()

	for i = igroup.numChildren, 1, -1 do
		if utils.GetProperty(igroup[i], "type") == "widget" then
			igroup[i]:removeSelf()
		end
	end

	if igroup.parent ~= self then
		igroup.parent:removeSelf()
	end

	self:removeSelf()
end

--- DOCME
function M:SetBeforeRemove (func)
	self.m_before_remove = func
end

-- Export the module.
return M