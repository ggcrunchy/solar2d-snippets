--- Various helpers to populate the dialog with UI elements.

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

-- Modules --
local button = require("ui.Button")
local checkbox = require("ui.Checkbox")
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local utils = require("editor.dialog.Utils")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Checkbox response
local function OnCheck (cb, is_checked)
	utils.UpdateObject(cb, is_checked)
end

--- DOCME
-- @ptable options
function M:AddCheckbox (options)
	local cb = checkbox.Checkbox(self:ItemGroup(), nil, 0, 0, 40, 40, OnCheck)

	self:CommonAdd(cb, options, true)

	local is_checked = options and self:GetValue(options.value_name)

	cb:Check(is_checked)
end

-- NYI
-- @ptable options
function M:AddCoordinates (options)
 -- options = { text = text, is_static = false }...
end

-- --
local DirTabs

--- DOCME
-- @ptable options
function M:AddDirectionTabs (options)
	options = common.CopyInto({}, options)

	DirTabs = DirTabs or { "up", "down", "left", "right" }

	options.buttons = DirTabs

	self:AddTabs(options)
end

--- DOCME
-- @ptable options
function M:AddImage (options)
	--
	local image

	if options and options.file then
		image = display.newImage(self:ItemGroup(), options.file, 0, 0)
	end

	if image then
		image.xScale = 64 / image.width
		image.yScale = 64 / image.height
	else
		image = display.newRoundedRect(dgroup, 0, 0, 64, 64, 12)
	end

	self:CommonAdd(image, options)
end

--- DOCME
-- @ptable options
function M:AddLink (options)
	local link = common_ui.Link(self:ItemGroup(), options)

	-- TODO: Use stored rep, infer interfaces (might need some work in tags)...

	self:CommonAdd(link, options, true)
end

--- DOCME
-- @ptable options
function M:AddListbox (options)
	local listbox = common_ui.Listbox(self:ItemGroup(), 0, 0)

	utils.SetProperty(listbox, "type", "widget")

	-- TODO! there are probably some ways to make this nicer?
	self:CommonAdd(listbox, options)
end

--- DOCME
-- @ptable options
function M:AddSpinner (options)
	local sopts = common.CopyInto({}, options)

	local inc = sopts.inc or 1
	local nmax = sopts.max
	local nmin = sopts.min
	local skip = inc ~= 0 and sopts.skip
	local value = self:GetValue(sopts.value_name) or 0

	sopts.is_static = true
	sopts.text = value .. ""

	local name = sopts.name

	if name == true then
		name = sopts.value_name
	end

	name = name or {}

	sopts.name = name

	self:AddString(sopts)
	self:CommonAdd(button.Button(self:ItemGroup(), nil, 0, 0, 40, 30, function()
		local str = self:Find(name)

		repeat
			value = value - inc
		until value ~= skip

		if nmin then
			value = max(nmin, value)
		end

		utils.UpdateObject(str, value)

		str.text = value .. ""
	end, "-"), { continue_line = true })
	self:CommonAdd(button.Button(self:ItemGroup(), nil, 0, 0, 40, 30, function()
		local str = self:Find(name)

		repeat
			value = value + inc
		until value ~= skip

		if nmax then
			value = min(nmax, value)
		end

		utils.UpdateObject(str, value)

		str.text = value .. ""
	end, "+"))
end

--- DOCME
-- @ptable options
function M:AddString (options)
	local sopts, text = {}

	if options then
		if options.before then
			self:CommonAdd(false, { text = options.before, continue_line = true }, true)
		end

		if options.value_name then
			text = self:GetValue(options.value_name)
		else
			text = options.text
		end

		sopts.name = options.name
		sopts.value_name = options.value_name
	end

	sopts.text = text or ""

	self:CommonAdd(false, sopts, options and options.is_static)
end

--- DOCME
-- @string dir
-- @string type
function M:StockElements (dir, type)
	self:CommonAdd(button.Button(self:ItemGroup(), nil, 0, 0, 25, 25, function()
		self:RemoveSelf()
	end, "X"), { continue_line = true })
	self:AddImage{ file = format("%s_Assets/%s_Thumb.png", dir, type), continue_line = true }
	self:AddString{ value_name = "name" }
	self:AddCoordinates{ text = "Pos", is_static = true, name = "current" }
end

-- --
local TabButtons = setmetatable({}, { __mode = "k" })

-- Tab button pressed
local function TabButtonPress (event) -- TODO: This seems kind of brittle :P
	local label = event.target.label.text

	utils.UpdateObject(event.target.parent, label)

	return true
end

--
local function TabButtonsFromLabels (labels)
	if TabButtons[labels] then
		return TabButtons[labels]
	elseif labels then
		local buttons = {}

		for _, label in ipairs(labels) do
			buttons[#buttons + 1] = { label = label, onPress = TabButtonPress }
		end

		TabButtons[labels] = buttons

		return buttons
	end
end

--- DOCME
-- @ptable options
function M:AddTabs (options)
	if options then
		options = common.CopyInto({}, options)

		options.width = options.width or #(options.buttons or "") * 90
		options.buttons = TabButtonsFromLabels(options.buttons)

		local tabs = common_ui.TabBar(self:ItemGroup(), options.buttons, options, false)
		local choice = self:GetValue(options.value_name)

		for i = 1, #(options.buttons or "") do
			if choice == options.buttons[i].label then
				tabs:setSelected(i, true)

				break
			end
		end

		utils.SetProperty(tabs, "type", "widget")

		self:CommonAdd(tabs, options)

		-- TODO: Hack!
		common_ui.TabsHack(self:ItemGroup(), tabs, #options.buttons)
		-- /TODO
	end
end

-- Export the module.
return M