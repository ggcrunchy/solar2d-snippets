--- Object tagging components.

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
local types = types

-- Modules --
local common = require("editor.Common")
local iterators = require("iterators")
local table_ops = require("table_ops")

-- Exports --
local M = {}

-- Registered tags --
local Tags = {}

-- Helper to resolve tags during iteration
local function Name (tag, i)
	local name = tag[i]

	if name then
		return i, name
	end
end

do
	-- Iterator body
	local function AuxChildren (tag, i)
		return Name(tag, i + 1)
	end

	---@string name Tag name.
	-- @treturn iterator Supplies, in order, at each iteration:
	--
	-- * Iteration variable, of dubious practical use.
	-- * Child tag name, s.t. _name_ was assigned as a parent in @{New}. (Grandchildren,
	-- et al. are **not** iterated.)
	function M.Children (name)
		local tag = Tags[name]

		return AuxChildren, tag, tag and tag.nparents or -1
	end
end

---@string name Tag name.
-- @treturn boolean The name has been registered with @{New}?
function M.Exists (name)
	return Tags[name] ~= nil
end

-- Helper to distinguish prospective property keys
local function IsProp (what)
	return type(what) == "string" and what ~= "sub_links"
end

--- DOCME
-- @string name
-- @string what
-- @return
function M.GetProperty (name, what)
	local tag = Tags[name]

	if tag and IsProp(what) then
		return tag[what]
	else
		return nil
	end
end

do
	--
	local function AuxHasChild (name, child)
		for _, tname in M.Children(name) do
			if tname == child or AuxHasChild(tname, child) then
				return true
			end
		end

		return false
	end

	--- DOCME
	-- @function M.HasChild
	-- @string name
	-- @string cname
	-- @treturn boolean
	M.HasChild = AuxHasChild
end

do
	--
	local function AuxHasSublink (name, sub)
		--
		local sub_links = Tags[name].sub_links

		if sub_links and table_ops.Find(sub_links, sub, true) then
			return true
		end

		--
		for _, tname in M.Parents(name) do
			if AuxHasSublink(tname, sub) then
				return true
			end
		end

		return false
	end

	--- DOCME
	-- @treturn boolean
	function M.HasSublink (
		name, -- MURBLE
		sub -- BURBLE
		)
		return sub == nil or AuxHasSublink(name, sub)
	end
end

do
	--
	local function AuxIs (name, super)
		for _, tname in M.Parents(name) do
			if tname == super or AuxIs(tname, super) then
				return true
			end
		end

		return false
	end

	--- DOCME
	-- @string name
	-- @string what
	-- @treturn boolean
	function M.Is (name, what)
		return name == what or AuxIs(name, what)
	end
end

--- DOCME
-- @string name
-- @ptable options
function M.New (name, options)
	assert(not Tags[name], "Tag already exists")

	local tag = { nparents = #(options or "") }

	if options then
		-- We track the tag's parent and child tag names, so that these may be iterated.
		-- The parents are only assigned at tag creation, so we can safely put these at
		-- the beginning of the tag's info array; whereas child tags may be added over
		-- time. By making note of how many parents there were, however, we can append
		-- the children to the same array: namely, the new tag name itself is here added
		-- to each of its parents.
		for _, pname in ipairs(options) do
			local ptag = assert(Tags[pname], "Invalid parent")

			assert(ptag[#ptag] ~= name, "Duplicate parent")

			ptag[#ptag + 1], tag[#tag + 1] = name, pname
		end

		-- Add any sublinks.
		if options.sub_links then
			tag.sub_links = table_ops.Copy(options.sub_links)
		end

		-- Record anything else that could be a property.
		for k, v in pairs(options) do
			if IsProp(k) then
				tag[k] = v
			end
		end
	end

	Tags[name] = tag
end

do
	-- Iterator body
	local function AuxParents (tag, i)
		return Name(tag, i - 1)
	end

	---@string name Tag name.
	-- @treturn iterator Supplies, in order, at each iteration:
	--
	-- * Iteration variable, of dubious practical use.
	-- * Parent tag name, as assigned in @{New} for _name_. (Grandparents, et al. are
	-- **not** iterated.)
	function M.Parents (name)
		local tag = Tags[name]

		return AuxParents, tag, tag and tag.nparents + 1 or 0
	end
end

--
local IterStrList = iterators.InstancedAutocacher(function()
	local str_list = {}

	-- Body --
	return function(_, i)
		return i + 1, str_list[i + 1]
	end,

	-- Done --
	function(_, i)
		return str_list[i + 1] == nil
	end,

	-- Setup --
	function(enum, name_, is_multi, extra)
		--
		local count

		if is_multi then
			count = 0

			for _, base in ipairs(name_) do
				count = enum(str_list, base, count)
			end
		else
			count = enum(str_list, name_, 0)
		end

		--
		for i = #str_list, count + 1, -1 do
			str_list[i] = nil
		end

		common.RemoveDups(str_list)

		if extra then
			str_list[#str_list + 1] = false
		end

		return nil, 0
	end
end)

do
	-- Enumerator body
	local function EnumSublinks (str_list, name, count)
		for _, tname in M.Parents(name) do
			count = EnumSublinks(str_list, tname, count)
		end

		--
		for _, v in common.IpairsIf(Tags[name].sub_links) do
			str_list[count + 1], count = v, count + 1
		end

		return count
	end

	--- DOCME
	-- @string name
	-- @bool add_nil
	-- @treturn iterator I
	function M.Sublinks (name, add_nil)
		return IterStrList(EnumSublinks, name, false, add_nil)
	end
end

do
	-- Enumerator body
	local function EnumTagAndChildren (str_list, name, count)
		for i, tname in M.Children(name) do
			count = EnumTagAndChildren(str_list, tname, count)
		end

		str_list[count + 1] = name

		return count + 1
	end

	--- DOCME
	-- @string name
	-- @treturn iterator I
	function M.TagAndChildren (name)
		return IterStrList(EnumTagAndChildren, name)
	end

	--- DOCME
	-- @array names
	-- @treturn iterator I
	function M.TagAndChildren_Multi (names)
		return IterStrList(EnumTagAndChildren, names, true)
	end
end

do
	-- Enumerator body
	local function EnumTagAndParents (str_list, name, count)
		for i, tname in M.Parents(name) do
			count = EnumTagAndParents(str_list, tname, count)
		end

		str_list[count + 1] = name

		return count + 1
	end

	---@string name Tag name.
	-- @treturn iterator Supplies, in some order without duplication, at each iteration:
	--
	-- * Iteration variable, of dubious practical use.
	-- * Tag name, which may be _name_ itself; a parent tag name, as assigned in @{New} for
	-- _name_; the parent tag name, in turn, of such a parent, etc.
	function M.TagAndParents (name)
		return IterStrList(EnumTagAndParents, name)
	end

	---@array names Tag names.
	-- @treturn iterator As per @{TagAndParents}, but with iteration domain consisting of the
	-- union of all tags in _names_.
	function M.TagAndParents_Multi (names)
		return IterStrList(EnumTagAndParents, names, true)
	end
end

-- Export the module.
return M