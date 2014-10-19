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
local assert = assert
local ipairs = ipairs
local pairs = pairs
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local array_funcs = require("tektite_core.array.funcs")
local iterator_utils = require("iterator_ops.utils")

-- Cached module references --
local _Children_
local _Is_
local _Parents_
local _TagAndChildren_

-- Exports --
local M = {}

-- Registered tags --
local Tags = {}

-- Helper to resolve tags during iteration
local function Name (tag, i)
	local name = tag and tag[i]

	if name then
		return i, name
	end
end

do
	-- Iterator body
	local function AuxChildren (tag, i)
		return Name(tag, i + 1)
	end

	--- Iterator.
	-- @string name Tag name.
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

--- Predicate.
-- @string name Tag name.
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
		for _, tname in _Children_(name) do
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

		if sub_links then
			local sublink = sub_links[sub]

			if sublink then
				return sublink
			end
		end

		--
		for _, tname in _Parents_(name) do
			local sublink = AuxHasSublink(tname, sub)

			if sublink then
				return sublink
			end
		end
	end

	-- --
	local Name1, Sub1, Sublink1
	local Name2, Sub2, Sublink2

	--
	local function FindSublink (name, sub)
		if name == Name1 and sub == Sub1 then
			return Sublink1
		elseif name == Name2 and sub == Sub2 then
			return Sublink2
		else
			local sublink = AuxHasSublink(name, sub)

			Name1, Sub1, Sublink1 = name, sub, sublink
			Name2, Sub2, Sublink2 = Name1, Sub1, Sublink1

			return sublink
		end
	end

	--- DOCME
	function M.CanLink (name1, name2, object1, object2, sub1, sub2)
		local so1, is_cont, passed, why = FindSublink(name1, sub1), true

		if so1 then
			local so2 = FindSublink(name2, sub2)

			if so2 then
				passed, why, is_cont = so1.m_can_link(object1, object2, so1, so2)
			else
				why = "Missing sublink #2: `" .. (sub2 or "?") .. "`"
			end
		else
			why = "Missing sublink #1: `" .. (sub1 or "?") .. "`"
		end

		if passed then
			return true
		else
			return false, why or "", not not is_cont
		end
	end

	--- DOCME
	-- @string name
	-- @string sub
	-- @treturn boolean
	function M.HasSublink (name, sub)
		return FindSublink(name, sub) ~= nil
	end
end

do
	--
	local function AuxIs (name, super)
		for _, tname in _Parents_(name) do
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

-- --
local function NoOp () end

--
local function Pairs (t)
	if t then
		return pairs(t)
	else
		return NoOp
	end
end

do
	--
	local function AddInterface (sub, what)
		adaptive.AddToSet(sub, "m_interfaces", what)
	end

	--
	local function GetName (sub)
		return sub.m_name
	end

	--
	local function Implements (sub, what)
		return adaptive.InSet(sub.m_interfaces, what)
	end

	--
	local function LinkToAny () return true end

	--
	local function CanLinkTo (_, _, sub, other_sub)
		if Implements(other_sub, sub.m_link_to) then
			return true
		else
			return false, "Expected `" .. sub.m_link_to .. "`", true
		end
	end

	-- --
	local Implies = {}

	--- DOCME
	function M.ImpliesInterface (name, what)
		adaptive.AddToSet(Implies, name, what)
	end

	-- --
	local ImplementedBy = {}

	--- DOCME
	function M.Implementors (what)
		return _TagAndChildren_(ImplementedBy[what], true)
	end

	--
	local function AddImplementor (name, what)
		for impl_by in adaptive.IterSet(ImplementedBy[what]) do
			if _Is_(name, impl_by) then
				return
			end
		end

		adaptive.AddToSet(ImplementedBy, what, name)
	end

	--- DOCME
	-- @string name
	-- @ptable options
	function M.New (name, options)
		assert(not Tags[name], "Tag already exists")

		local tag, new = {}

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
			local sub_links = options.sub_links

			if sub_links then
				new = {}

				for name, sub in pairs(sub_links) do
					local stype, obj, link_to = type(sub), {}

					--
					if stype == "table" then
						for _, v in ipairs(sub) do
							AddInterface(obj, v)
						end

						--
						link_to = sub.link_to

					--
					elseif sub then
						link_to = sub ~= true and sub
					end
					
					--
					obj.m_name = name

					if type(link_to) == "string" then
						obj.m_can_link, obj.m_link_to = CanLinkTo, link_to

						--
						for interface in adaptive.IterSet(Implies[link_to]) do
							AddInterface(obj, interface)
						end

					--
					elseif link_to ~= nil then
						obj.m_can_link = link_to or LinkToAny
					end

					--- DOCME
					obj.GetName = GetName

					--- DOCME
					obj.Implements = Implements

					--
					new[name] = obj
				end
			end

			--
			for _, sub in Pairs(new) do
				for what in adaptive.IterSet(sub.m_interfaces) do
					AddImplementor(name, what)
				end
			end

			-- Record anything else that could be a property.
			for k, v in pairs(options) do
				tag[k] = v
			end
		end

		--
		tag.nparents, tag.sub_links = #(options or ""), new

		Tags[name] = tag
	end
end

do
	-- Iterator body
	local function AuxParents (tag, i)
		return Name(tag, i - 1)
	end

	--- Iterator.
	-- @string name Tag name.
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
local IterStrList = iterator_utils.InstancedAutocacher(function()
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
	function(enum, name_, as_set)
		--
		local count = 0

		if as_set then
			for base in adaptive.IterSet(name_) do
				count = enum(str_list, base, count)
			end
		else
			for _, base in adaptive.IterArray(name_) do
				count = enum(str_list, base, count)
			end
		end

		-- Enumeration will overwrite the old elements, but if the previous iteration was
		-- longer than this one, the list will still contain leftover elements at the tail
		-- end, so trim the list as needed. Remove any duplicates to get the final list.
		for i = #str_list, count + 1, -1 do
			str_list[i] = nil
		end

		array_funcs.RemoveDups(str_list)

		return nil, 0
	end
end)

do
	-- Enumerator body
	local function EnumSublinks (str_list, name, count)
		for _, tname in _Parents_(name) do
			count = EnumSublinks(str_list, tname, count)
		end

		--
		for _, v in Pairs(Tags[name].sub_links) do
			str_list[count + 1], count = v:GetName(), count + 1
		end

		return count
	end

	--- DOCME
	-- @string name
	-- @treturn iterator I
	function M.Sublinks (name)
		return IterStrList(EnumSublinks, name)
	end
end

do
	-- Enumerator body
	local function EnumTagAndChildren (str_list, name, count)
		for _, tname in _Children_(name) do
			count = EnumTagAndChildren(str_list, tname, count)
		end

		str_list[count + 1] = name

		return count + 1
	end

	--- DOCME
	-- @string name
	-- @bool as_set
	-- @treturn iterator I
	function M.TagAndChildren (name, as_set)
		return IterStrList(EnumTagAndChildren, name, as_set)
	end
end

do
	-- Enumerator body
	local function EnumTagAndParents (str_list, name, count)
		for _, tname in _Parents_(name) do
			count = EnumTagAndParents(str_list, tname, count)
		end

		str_list[count + 1] = name

		return count + 1
	end

	--- Iterator.
	-- @string name Tag name.
	-- @bool as_set
	-- @treturn iterator Supplies, in some order without duplication, at each iteration:
	--
	-- * Iteration variable, of dubious practical use.
	-- * Tag name, which may be _name_ itself; a parent tag name, as assigned in @{New} for
	-- _name_; the parent tag name, in turn, of such a parent, etc.
	function M.TagAndParents (name, as_set)
		return IterStrList(EnumTagAndParents, name, as_set)
	end
end

do
	-- Enumerator body
	local function EnumTags (str_list, _, count)
		for k in pairs(Tags) do
			str_list[count + 1], count = k, count + 1
		end

		return count
	end

	--- Iterator.
	-- @treturn iterator Supplies, in some order without duplication, at each iteration:
	--
	-- * Iteration variable, of dubious practical use.
	-- * Tag name, as assigned in @{New}.
	function M.Tags ()
		return IterStrList(EnumTags, true)
	end
end

-- Cache module members.
_Children_ = M.Children
_Is_ = M.Is
_Parents_ = M.Parents
_TagAndChildren_ = M.TagAndChildren

-- Export the module.
return M