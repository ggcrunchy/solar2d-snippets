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
local links = require("editor.Links")
local tags = require("editor.Tags")
local utils = require("utils")

-- Export --
local M = {}

--
local function HasAny (rep)
	local tag = links.GetTag(rep)

	if tag then
		local f, s, v0, reclaim = tags.Sublinks(tag)

		for _, sub in f, s, v0 do
			if links.HasLinks(rep, sub) then
				reclaim()

				return true
			end
		end
	end
end

--- DOCME
-- @ptable level
-- @ptable value
-- @ptable elem
-- @bool save
function M.AddAnyLinks (level, value, elem, save)
	local rep = common.GetBinding(elem, true)

	--
	if save then
		if HasAny(rep) then
			local list = level.links or {}

			if not list[rep] then
				elem.uid = utils.NewName()

				list[#list + 1] = rep
				list[rep] = #list
			end

			level.links = list
		end

	--
	elseif value.uid then
		level.links[value.uid] = rep
	end
end

--- DOCME
-- @ptable level
-- @ptable mod
-- @ptable from
-- @array acc
-- @treturn array ACC
function M.BuildElement (level, mod, from, acc)
	acc = acc or {}

	local elem = common.CopyInto({}, from)

	if from.uid then
		level.links[from.uid], elem.uid = elem

		level.links[elem] = mod.EditorEvent(from.type, "prep_link", level, elem)
	end

	elem.name = nil

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

--
local function ReadLinks (level, on_element, on_pair)
	local list, index, elem, sub = level.links, 1

	for i = 1, #list, 2 do
		local item, other = list[i], list[i + 1]

		--
		if item == "element" then
			elem = list[other]

			on_element(elem, index)

			list[index], index = elem, index + 1

		--
		elseif item == "sub" then
			sub = other

		--
		elseif index > item then
			on_pair(list, elem, list[item], sub, other)
		end
	end
end

--
local function OnElement_Build (elem, index)
	elem.uid = index
end

--
local function OnElement_Load () end

--
local function OnPair_Build (list, elem1, elem2, sub1, sub2)
	local func1, func2 = list[elem1], list[elem2]

	if func1 then
		func1(elem1, elem2, sub1, sub2)
	end

	if func2 then
		func2(elem2, elem1, sub2, sub1)
	end
end

--
local function OnPair_Load (_, obj1, obj2, sub1, sub2)
	links.LinkObjects(obj1, obj2, sub1, sub2)
end

--- DOCME
-- @ptable level
-- @bool save
function M.ResolveLinks (level, save)
	if level.links then
		--
		if save == "build" then
			ReadLinks(level, OnElement_Build, OnPair_Build)

			level.links = nil

		--
		elseif save then
			local list, new = level.links, {}

			for _, rep in ipairs(list) do
				local element = common.GetBinding(rep)

				--
				new[#new + 1] = "element"
				new[#new + 1] = element.uid

				for _, sub in tags.Sublinks(links.GetTag(rep)) do
					new[#new + 1] = "sub"
					new[#new + 1] = sub

					for link in links.Links(rep, sub) do
						local obj, osub = link:GetOtherObject(rep)

						new[#new + 1] = list[obj]
						new[#new + 1] = osub
					end
				end
			end

			level.links = new

		--
		else
			ReadLinks(level, OnElement_Load, OnPair_Load)
		end
	end
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
	M.AddAnyLinks(level, arg1, arg2, save)

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