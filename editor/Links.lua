--- Object linking components.

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
local min = math.min
local next = next
local pairs = pairs
local type = type
local yield = coroutine.yield

-- Modules --
local array_funcs = require("tektite_core.array.funcs")
local coro = require("iterator_ops.coroutine")
local str_utils = require("tektite_core.string")
local tags = require("editor.Tags")
local timers = require("corona_utils.timers")

-- Classes --
local SparseArray = require("class.Container.SparseArray")

-- Exports --
local M = {}

-- Link-tagged objects --
local Objects = SparseArray()

-- Lists of links for each pair of objects --
local Links = {}

-- Object proxies --
local Proxies = {}

-- --
local function NoOp () end

--
local function NumberPairs (t, k)
	repeat
		k = next(t, k)
	until k == nil or type(k) == "number"

	return k, t[k]
end

-- Helper to visit a proxy's link keys
local function LinkKeys (proxy)
	if proxy then
		return NumberPairs, proxy
	else
		return NoOp
	end
end

-- Lists of proxies assigned a given link tag --
local TaggedLists = {}

--
local function SetInTaggedList (name, id, proxy)
	local list = TaggedLists[name]

	if list or proxy then
		list = list or {}

		list[id], TaggedLists[name] = proxy, list
	end
end

-- Routine called on object immediately before removal --
local OnRemove

--
local function RemoveObject (id, object)
	local proxy = Proxies[object]

	--
	Proxies[object], proxy.id = nil

	for _, v in LinkKeys(proxy) do
		for _, link in pairs(Links[v]) do
			link:Break()
		end
	end

	--
	SetInTaggedList(proxy.name, id, nil)

	--
	if OnRemove then
		OnRemove(object)
	end

	Objects:RemoveAt(id)
end

-- Is the object still valid?
local function Alive (object)
	return object.parent
end

-- Helper to clean up any dead objects in a range
local function AuxCleanUp (from, to)
	for i = from, to do
		if Objects:InUse(i) then
			local object = Objects:Get(i)

			if not Alive(object) then
				RemoveObject(i, object)
			end
		end
	end
end

--- Visits a range of objects, performing cleanup on any that have been removed, e.g. by
-- `object:removeSelf()`.
--
-- Cleanup of an object consists in breaking any links it has made, invalidating its proxy,
-- and removing it from its tag's list.
-- @uint from ID of first (possible) object.
-- @uint count Number of objects to check.
-- @treturn uint First ID after visited objects.
function M.CleanUp (from, count)
	local nobjs = #Objects
	local to = from + min(count, nobjs) - 1

	AuxCleanUp(from, min(to, nobjs))

	if to >= nobjs then
		to = to - nobjs

		AuxCleanUp(1, to)
	end

	return to + 1
end

--
local function Match1 (link, proxy, sub)
	return link.m_proxy1 == proxy and link.m_sub1 == sub
end

--
local function Match2 (link, proxy, sub)
	return link.m_proxy2 == proxy and link.m_sub2 == sub
end

-- Helper to get a proxy (if valid) from an object
local function Proxy (object)
	return object and Alive(object) and Proxies[object]
end

--- Getter.
-- @pobject object
-- @string sub
-- @treturn uint C
function M.CountLinks (object, sub)
	local proxy, count = Proxy(object), 0

	for _, v in LinkKeys(proxy) do
		for _, link in pairs(Links[v]) do
			if Match1(link, proxy, sub) or Match2(link, proxy, sub) then
				count = count + 1
			end
		end
	end

	return count
end

-- Gets the key for a proxy pairing
local function GetKey (p1, p2)
	return p1[p2.id]
end

--
local function LinksIter (p1, p2)
	local key = GetKey(p1, p2)
	local t = key and Links[key]

	if t then
		return ipairs(t)
	else
		return NoOp
	end
end

--
local function AlreadyLinked (p1, p2, sub1, sub2)
	for _, link in LinksIter(p1, p2) do
		if Match1(link, p1, sub1) and Match2(link, p2, sub2) then
			return true
		end
	end
end

--
local function SortProxies (p1, p2, sub1, sub2, obj1, obj2)
	if p2.id < p1.id then
		return p2, p1, sub2, sub1, obj2, obj1
	else
		return p1, p2, sub1, sub2, obj1, obj2
	end
end

--- DOCME
-- @pobject object1
-- @pobject object2
-- @string sub1
-- @string sub2
-- @treturn boolean X If true, this is the only return value.
-- @treturn ?string Reason link cannot be formed.
-- @treturn ?boolean This is a contradiction or "strong" failure, i.e. the predicate will
-- **always** fail, given the inputs?
function M.CanLink (object1, object2, sub1, sub2)
	local p1, p2 = Proxy(object1), Proxy(object2)

	-- Both objects are still valid?
	if p1 and p2 then
		p1, p2, sub1, sub2, object1, object2 = SortProxies(p1, p2, sub1, sub2, object1, object2)

		if p1 == p2 or AlreadyLinked(p1, p2, sub1, sub2) then
			return false, p1 == p2 and "Same object" or "Already linked"

		-- ...and not already linked?
		else
			-- ...pass all object1-object2 predicates?
			local passed, why, is_cont = tags.CanLink(p1.name, p2.name, object1, object2, sub1, sub2)

			if passed then
				-- ...and object2-object1 ones too?
				passed, why, is_cont = tags.CanLink(p2.name, p1.name, object2, object1, sub2, sub1)

				if passed then
					return true
				end
			end

			return false, why, is_cont
		end
	end

	return false, "Invalid object", true
end

--- Getter.
-- @pobject object
-- @bool is_proxy
-- @treturn string N
function M.GetTag (object, is_proxy)
	if not is_proxy then
		object = Proxy(object)
	end

	return object and object.name
end

--- Predicate.
-- @pobject object
-- @string sub
-- @treturn boolean X
function M.HasLinks (object, sub)
	local proxy = Proxy(object)

	for _, v in LinkKeys(proxy) do
		for _, link in pairs(Links[v]) do
			if Match1(link, proxy, sub) or Match2(link, proxy, sub) then
				return true
			end
		end
	end

	return false
end

-- --
local Link = {}

-- Helper to find a link for a proxy pair
local function FindLink (p1, p2, link)
	for i, v in LinksIter(p1, p2) do
		if v == link then
			return i
		end
	end
end

-- Helper to get an object (if valid) from a proxy
-- If the object has gone dead, it is removed, and considered to be nil
local function Object (proxy)
	local id = proxy and proxy.id

	if id then
		local object = Objects:Get(id)

		if Alive(object) then
			return object
		else
			RemoveObject(id, object)
		end
	end

	return nil
end

--- Breaks this line, after which it will be invalid.
--
-- If the link is already invalid, this is a no-op.
-- @see Link:IsValid
function Link:Break ()
	local p1, p2 = self.m_proxy1, self.m_proxy2

	-- With the proxies now safely cached (if still present), clear the proxy fields to abort
	-- recursion (namely, in case of dead objects).
	self.m_proxy1, self.m_proxy2 = nil

	-- If the objects were both valid, the link is still intact. In this case, remove it from
	-- the pair's list; if this empties the list, remove that as well, from both the master
	-- list and each proxy.
	local obj1 = Object(p1)
	local obj2 = Object(p2)

	if obj1 and obj2 then
		local key = GetKey(p1, p2)
		local links = Links[key]

		array_funcs.Backfill(links, FindLink(p1, p2, self))

		if #links == 0 then
			Links[key], p1[p2.id], p2[p1.id] = nil
		end
	end

	-- If this link went from intact to broken, call any handler.
	if p1 and self.m_on_break then
		self:m_on_break(obj1, obj2, self.m_sub1, self.m_sub2)
	end
end

--- Getter.
-- @treturn boolean The link is still intact?
--
-- When **false**, this is the only return value.
-- @treturn ?pobject Linked object #1...
-- @treturn ?pobject ...and #2.
-- @treturn ?string Sublink of object #1...
-- @treturn ?string ...and object #2.
-- @see Link:IsValid
function Link:GetObjects ()
	local obj1, obj2 = Object(self.m_proxy1), Object(self.m_proxy2)

	if obj1 and obj2 then
		return true, obj1, obj2, self.m_sub1, self.m_sub2
	end

	return false
end

--- Getter.
-- @pobject object Object, which may be paired in the link.
-- @treturn ?pobject If the link is valid and _object_ was one of its linked objects, the
-- other object; otherwise, **nil**.
-- @treturn ?string If an object was returned, its sublink; if absent, **nil**.
function Link:GetOtherObject (object)
	local _, obj1, obj2, sub1, sub2 = self:GetObjects()

	if obj1 == object then
		return obj2, sub2
	elseif obj2 == object then
		return obj1, sub1
	end

	return nil
end

--- Checks link validity. Links are invalid after @{Link:Break}, or if one or both of
-- the proxied objects has been removed by e.g. `object:removeSelf()`.
-- @treturn boolean The link is still intact?
function Link:IsValid ()
	return (Object(self.m_proxy1) and Object(self.m_proxy2)) ~= nil
end

--- Sets logic to call when a link becomes invalid, cf. @{Link:IsValid}.
--
-- Called as
--    func(link, object1, object2, sub1, sub2)
-- where _object1_ and _object2_ were the linked objects and _sub1_ and _sub2_ were their
-- respective sublinks. In the case that _object*_ has been removed, it will be **nil**.
--
-- **N.B.** This may be triggered lazily, i.e. outside of @{Link:Break}, either via one of
-- the other link methods or @{CleanUp}.
-- @callable func Function to assign, or **nil** to disable the logic.
function Link:SetBreakFunc (func)
	self.m_on_break = func
end

--- DOCME
-- @pobject object1
-- @pobject object2
-- @string sub1
-- @string sub2
-- @treturn LinkHandle L
-- @treturn string S
-- @treturn boolean B
function M.LinkObjects (object1, object2, sub1, sub2)
	local can_link, why, is_cont = M.CanLink(object1, object2, sub1, sub2) 

	if can_link then
		local p1, p2

		-- To limit a few checks later on, impose an order on the proxies.
		p1, p2, sub1, sub2 = SortProxies(Proxies[object1], Proxies[object2], sub1, sub2)

		-- Lookup the links already associated with this pairing. If this is the first,
		-- generate the key and list and hook everything up.
		local key = GetKey(p1, p2)
		local links = Links[key]

		if not key then
			key, links = str_utils.PairToKey(p1.id, p2.id), {}

			Links[key], p1[p2.id], p2[p1.id] = links, key, key
		end

		-- Install the link.
		local link = { m_proxy1 = p1, m_proxy2 = p2, m_sub1 = sub1, m_sub2 = sub2 }

		for k, v in pairs(Link) do -- TODO: If using class system, might make sense here too...
			link[k] = v
		end

		links[#links + 1] = link

		return link
	end

	return nil, why, is_cont
end

--- DOCME
-- @function M.Links
-- @pobject object
-- @string sub
-- @treturn iterator X
M.Links = coro.Iterator(function(object, sub)
	local proxy = Proxy(object)

	for _, v in LinkKeys(proxy) do
		for _, link in pairs(Links[v]) do
			if Match1(link, proxy, sub) or Match2(link, proxy, sub) then
				yield(link)
			end
		end
	end
end)

--- DOCME
-- @pobject object
function M.RemoveTag (object)
	local proxy = Proxy(object)

	if proxy then
		RemoveObject(proxy.id, object)
	end
end

--- Setter.
-- @callable func X
function M.SetRemoveFunc (func)
	OnRemove = func
end

-- Timer to purge dead objects --
local Purge

--- DOCME
-- @pobject object
-- @string name
function M.SetTag (object, name)
	assert(object and Alive(object), "Invalid object")
	assert(not Proxies[object], "Object already tagged")

	local proxy = { id = Objects:Insert(object), name = name }

	Proxies[object] = proxy

	--
	SetInTaggedList(name, proxy.id, proxy)

	-- Add a low-frequency timer to clean up after dead objects / proxies, unless one
	-- already happens to be running.
	if not Purge then
		local index = 1

		Purge = timers.RepeatEx(function()
			if #Objects == 0 then
				Purge = nil

				return "cancel"

			-- There may be many objects, so deal with just a slice at a time.
			else
				index = M.CleanUp(index, 15)
			end
		end, 5000)
	end
end

--- DOCME
-- @function M.Tagged
-- @string name N
-- @treturn iterator X
M.Tagged = coro.Iterator(function(name)
	local list = TaggedLists[name]

	if list then
		for _, proxy in pairs(list) do
			local object = Object(proxy)

			if object then
				yield(object)
			end
		end
	end
end)

-- Export the module.
return M