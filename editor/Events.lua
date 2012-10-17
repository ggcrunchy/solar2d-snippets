--- Some operations reused in editor events.

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
local assert = assert
local ipairs = ipairs
local pairs = pairs

-- Modules --
local common = require("editor.Common")
local grid = require("editor.Grid")

-- Export --
local M = {}

--- DOCME
-- @ptable level
-- @ptable mod
-- @ptable from
-- @array acc
-- @treturn array ACC
function M.BuildElement (level, mod, from, acc)
	acc = acc or {}

	local elem = common.CopyInto({}, from)

	mod.EditorEvent(from.type, "build", level, from, elem)

	acc[#acc + 1] = elem

	return acc
end

--- DOCME
-- @string what
-- @array verify
-- @ptable names
-- @ptable element
-- @treturn boolean X
function M.CheckForNameDups (what, verify, names, element)
	local type = names[element.name]

	if not type then
		names[element.name] = element.type
	else
		verify[#verify + 1] = "Duplicated " .. what .. " name: `" .. element.name .. "` of type `" .. element.type .. "`; already used by " .. what .. " of type `" .. type .. "`"

		return true
	end
end

--- DOCME
-- @string what
-- @array verify
-- @callable common_ops
function M.CheckNamesInElements (what, verify, common_ops)
	local names, _, elements = {}, common_ops("get_data")

	for _, elem in pairs(elements) do
		if M.CheckForNameDups(what, verify, names, elem) then
			return
		end
	end
end

---@array types An array of type name strings.
-- @string name The name to find.
-- @treturn uint Index of _name_ in _types_.
function M.GetIndex (types, name)
	local index = types[name]

	if not index then
		for i, type in ipairs(types) do
			if type == name then
				index = i

				break
			end
		end

		types[name] = assert(index, "Missing type")
	end

	return index
end

--- DOCME
-- @ptable level
-- @string what
-- @ptable mod
-- @callable grid_func
-- @callable common_ops
function M.Load (level, what, mod, grid_func, common_ops)
	grid.Show(grid_func)

	level[what].version = nil

	local current, elements, tiles = common_ops("get_data")
	local types = mod.GetTypes()
	local cells = grid.Get()

	for k, v in pairs(level[what].elements) do
		M.SetCurrentIndex(current, types, v.type)

		cells:TouchCell(common.FromKey(k))

		M.SaveOrLoad(level, mod, v, elements[k], false)
	end

	current:SetCurrent(1)

	grid.ShowOrHide(tiles)
	grid.Show(false)
end

--- DOCME
-- @ptable level
-- @string what
-- @ptable mod
-- @callable common_ops
function M.Save (level, what, mod, common_ops)
	local target = {}

	level[what] = { elements = target, version = 1 }

	local _, elements = common_ops("get_data")

	for k, v in pairs(elements) do
		local elem = {}

		M.SaveOrLoad(level, mod, v, elem, true)

		target[k] = elem
	end
end

-- --
local Defs

-- --
local Mod, ValueType

--- DOCME
-- @ptable level
-- @ptable mod
-- @ptable value
-- @ptable elem
-- @bool save
function M.SaveOrLoad (level, mod, value, elem, save)
	local arg1, arg2 = value, elem

	if save then
		arg1, arg2 = arg2, arg1
	end

	--
	if Mod ~= mod or ValueType ~= value.type then
		Mod, ValueType = mod, value.type

		Defs = { name = "", type = ValueType }

		mod.EditorEvent(ValueType, "enum_defs", Defs)
	end

	--
	for k, v in pairs(value) do
		elem[k] = v
	end

	--
	mod.EditorEvent(ValueType, save and "save" or "load", level, arg1, arg2)

	--
	for k, v in pairs(Defs) do
		if elem[k] == nil then
			elem[k] = v
		end
	end
end

---@pobject current The "current choice" @{ui.Grid1D} widget for the current editor view.
-- @array types An array of type strings, belonging to the view.
-- @string name A name to find in _types_.
function M.SetCurrentIndex (current, types, name)
	current:SetCurrent(M.GetIndex(types, name))
end

--- DOCME
-- @ptable verify
-- @ptable mod
-- @callable common_ops
function M.VerifyElements (verify, mod, common_ops)
	local _, elements = common_ops("get_data")

	for k, v in pairs(elements) do
		mod.EditorEvent(v.type, "verify", verify, elements, k)
	end
end

-- Export the module.
return M