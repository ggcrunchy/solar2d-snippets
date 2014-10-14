--- Dialog utilities.

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
local rawget = rawget
local type = type

-- Modules --
local common = require("editor.Common")

-- Corona globals --
local display = display

-- Cached module references --
local _GetDialog_
local _GetProperty_

-- Exports --
local M = {}

--
local function NoTouch () return true end

--- DOCME
function M.AddBack (dialog, w, h)
	display.remove(dialog[1])

	local back = display.newRoundedRect(dialog, 0, 0, w, h, 12)

	back:addEventListener("touch", NoTouch)
	back:setFillColor(.5)
	back:setStrokeColor(.375, .375, .375)
	back:toBack()

	back.anchorX, back.x = 0, 0
	back.anchorY, back.y = 0, 0
	back.strokeWidth = 3
end

--- DOCMEMORE
-- Helper to access dialog via object
function M.GetDialog (object)
	repeat
		object = object.parent
	until object == nil or object.m_items

	return object
end

--- DOCME
function M.GetValue (object, alt)
	local dialog, value = _GetDialog_(alt or object)

	if dialog then
		local values, value_name = dialog.m_values, _GetProperty_(object, "value_name")

		if values and value_name then
			value = values[value_name]

			if type(value) == "table" then
				value = common.CopyInto({}, value)
			end
		end
	end

	return value
end

--- DOCMEMORE
-- Updates the value bound to an object (dirties the editor state)
function M.UpdateObject (object, value, alt)
	local values = _GetDialog_(alt or object).m_values
	local value_name = _GetProperty_(object, "value_name")

	if values and value_name then
		if type(value) == "table" then
			-- If the values are already a table, copy into it instead of overwriting the reference.
			if type(values[value_name]) == "table" then
				local cur = values[value_name]

				for k, v in pairs(value) do
					cur[k] = v
				end

				value = cur

			-- Otherwise, assign a shallow table copy to avoid capturing the input reference.
			else
				value = common.CopyInto({}, value)
			end
		end

		values[value_name] = value

		common.Dirty()
	end
end

-- --
local Props = setmetatable({}, {
	__index = function(t, k)
		local new = {}

		t[k] = new

		return new
	end,
	__mode = "k"
})

--- DOCME
function M.GetProperty (item, what)
	local iprops = rawget(Props, item)

	return iprops and iprops[what]
end

--- DOCME
function M.GetProperty_Table (item)
	return Props[item]
end

--- DOCME
function M.SetProperty (item, name, value)
	Props[item][name] = value
end

function M.SetProperty_Table (item, props)
	Props[item] = props
end

-- Cache module members.
_GetDialog_ = M.GetDialog
_GetProperty_ = M.GetProperty

-- Export the module.
return M