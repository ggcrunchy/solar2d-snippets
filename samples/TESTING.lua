--- Staging area.

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

-- Corona modules --
local composer = require("composer")

-- --
local Scene = composer.newScene()

--
function Scene:create ()
	--
end

Scene:addEventListener("create")

--
function Scene:show (e)
	if e.phase == "will" then return end








do
	local links = require("s3_editor.Links")
	local tags = require("s3_editor.Tags")

	local Objs = {}

	local function C (name, tag)
		local c = display.newCircle(self.view, 0, 0, 5)

		c.isVisible = false

		c.m_name = name

		links.SetTag(c, tag)

		Objs[#Objs + 1] = c
	end

	local function print1 (...)
		print("  ", ...)
	end

	local function print2 (...)
		print("  ", "  ", ...)
	end

	links.SetRemoveFunc(function(object)
		print1("Goodbye, " .. object.m_name)
	end)

	-- Define tag: so far so good
	tags.New("MIRBLE", { sub_links = { Burp = true, Slerp = true, Derp = true } })
	tags.New("ANIMAL")
	tags.New("DOG", { "ANIMAL" })
	tags.New("CAT", { "ANIMAL", "MIRBLE" })
	tags.New("WOB", { "CAT" })

	-- Create and Set tags: so far so good
	C("j", "MIRBLE")
	C("k", "ANIMAL")
	C("l", "DOG")
	C("m", "CAT")
	C("n", "WOB")

	for _, v in ipairs(Objs) do
		local tag = links.GetTag(v) -- Get tag: good

		print("object:", v.m_name)
		print("tag:", tag)

		local function P (tt)
			if type(tt) ~= "string" then
				print2(tt.m_name)
			elseif tt ~= tag then
				print2(tt)
			end
		end

		-- Children: good
		print1("CHILDREN!")

		for _, tt in tags.TagAndChildren(tag) do
			P(tt)
		end

		-- Multi-children: good
		print1("MULTI-CHILDREN (tag + ANIMAL)")

		for _, tt in tags.TagAndChildren--[[_Multi]]({ tag, "ANIMAL" }) do
			P(tt)
		end

		-- Parents: good
		print1("PARENTS!")

		for _, tt in tags.TagAndParents(tag) do
			P(tt)
		end

		-- Multi-parents: good
		print1("MULTI-PARENTS (tag + WOB)")

		for _, tt in tags.TagAndParents--[[_Multi]]({ tag, "WOB" }) do
			P(tt)
		end

		print("")

		-- Sublinks: good
		print1("Sublinks")

		for _, tt in tags.Sublinks(tag) do
			P(tt)
		end

		-- Has child: good
		print1("Has child: WOB", tags.HasChild(tag, "WOB"))
		print1("Has child: DOG", tags.HasChild(tag, "DOG"))
		print1("Has child: MOOP", tags.HasChild(tag, "MOOP"))

		-- Is: good
		print1("Is: MIRBLE", tags.Is(tag, "MIRBLE"))
		print1("Is: WOB", tags.Is(tag, "WOB"))
		print1("Is: GOOM", tags.Is(tag, "GOOM"))

		-- Has sublink: good
		print1("Has sublink: Derp", tags.HasSublink(tag, "Derp"))
		print1("Has sublink: nil", tags.HasSublink(tag, nil))
		print1("Has sublink: OOMP", tags.HasSublink(tag, "OOMP"))

		-- Tagged: good
		print1("Tagged")

		for _, tname in tags.TagAndChildren(tag) do
			for tt in links.Tagged(tname) do
				P(tt)
			end
		end
	end

	local Messages = {}

	local function Print (message)
		if not Messages[message] then
			print1(message)

			Messages[message] = true
		end
	end

	-- Create links with can_link, sub_links
	local SubLinks = {}

	local From = #Objs

	for i = 1, 20 do
		local options = {}
		local sub_links = {}

		for j = 1, i % 3 do
			sub_links[j] = "SL_" .. ((i + 2) % 5)
		end

	--	options.sub_links = sub_links

		local can_link = true

		if i > 5 then
			function can_link (o1, o2, sub1, sub2)
				local num, message = (sub2 and sub2:GetName() or ""):match("SL_(%d+)") or 0 / 0

				if i <= 10 then
					message = num % 2 == 0 and "5 to 10, link to evens"
				elseif i <= 15 then
					message = num % 2 == 1 and "11 to 15, link to odds"
				else
					message = (sub2 == nil or num % 3 == 0) and "16 to 20, link to 3 * n / nil"
				end

				if message and Print then
					Print(message .. ": (" .. tostring(sub1:GetName()) .. ", " ..tostring(sub2:GetName()) .. ")")
				end

				return not not message
			end
		end

		local links = {}

		for _, v in ipairs(sub_links) do
			links[v] = can_link
		end

		options.sub_links = links

		SubLinks[i] = sub_links

		tags.New("tag_" .. i, options)

		C("object_" .. i, "tag_" .. i)
	end

	-- Can link: good?
	print("What can link?")

	local Links = {}

	for i = 1, 20 do
		for j = 1, 20 do
			if i ~= j then
				local o1, o2 = Objs[From + i], Objs[From + j]

				for k = 1, #SubLinks[i] + 1 do
					for l = 1, #SubLinks[j] + 1 do
						local sub1, sub2 = SubLinks[i][k], SubLinks[j][l]

						if links.CanLink(o1, o2, sub1, sub2) then
							Links[#Links + 1] = { From + i, From + j, link = links.LinkObjects(o1, o2, sub1, sub2) }

							assert(Links[#Links].link, "Invalid link")
						end
					end
				end
			end
		end
	end

	Print = nil

	print("Number of links: ", #Links)
	print("Let's break some!")

	local function LinkIndex (i)
		return i % #Links + 1
	end

	for _, v in ipairs{ 100, 200, 300, 400, 500, 600 } do
		local i = LinkIndex(v)
		local intact, o1, o2, sub1, sub2 = Links[i].link:GetObjects()

		print1("Link " .. i .. " intact?", intact, o1 and o1.m_name, o2 and o2.m_name, sub1, sub2)

		Links[i].link:Break()
	end

	print("State of one of those...")

	print1("Link ", LinkIndex(21--[[200]]), Links[LinkIndex(21--[[200]])].link:GetObjects())

	print("Let's destroy some objects!")

	for _, v in ipairs{ 50, 150, 250, 350, 450 } do
		local i = LinkIndex(v)
		local intact, o1, o2 = Links[i].link:GetObjects()

		if intact then
			local which

			if i % 2 == 0 then
				print("Link " .. i .. ", breaking object 1")

				which = o1
			else
				print("Link " .. i .. ", breaking object 2")

				which = o2
			end

			print1("Valid before?", Links[i].link:IsValid())

			which:removeSelf()

			print1("Valid after?", Links[i].link:IsValid())
		end
	end

	-- Links...
	local index = LinkIndex(14--[[173]])
	local link = Links[index].link
	local intact, lo, _, s1 = link:GetObjects()

	local function Obj (obj, sub, self)
		if obj == self then
			return "SELF"
		else
			return obj.m_name .. " (" .. tostring(sub) .. ")"
		end
	end

	print("Links belonging to link " .. index .. ", SELF = " .. Obj(lo, s1))

	for link in links.Links(lo, s1) do
		local _, obj1, obj2, sub1, sub2 = link:GetObjects()

		print1("LINK: ", Obj(obj1, sub1, lo) .. " <-> " .. Obj(obj2, sub2, lo))
	end

	for i = -1, 7 do
		local sub = i ~= -1 and "SL_" .. i or nil

		print("Has links (" .. tostring(sub) .. ")?", links.HasLinks(lo, sub))
	end
end









print("")
print("")
print("")







do
	local LinksClass = require("tektite_base_classes.Link.Links")
	local TagsClass = require("tektite_base_classes.Link.Tags")


	local TagsInstance = TagsClass()
	local LinksInstance = LinksClass(TagsInstance, function(object)
		return object.parent
	end)

	local Objs = {}

	local function C (name, tag)
		local c = display.newCircle(self.view, 0, 0, 5)

		c.isVisible = false

		c.m_name = name

		LinksInstance:SetTag(c, tag)

		Objs[#Objs + 1] = c
	end

	local function print1 (...)
		print("  ", ...)
	end

	local function print2 (...)
		print("  ", "  ", ...)
	end

	LinksInstance:SetRemoveFunc(function(object)
	print(object, debug.traceback())
		print1("Goodbye, " .. object.m_name)
	end)

	-- Define tag: so far so good
	TagsInstance:New("MIRBLE", { sub_links = { Burp = true, Slerp = true, Derp = true } })
	TagsInstance:New("ANIMAL")
	TagsInstance:New("DOG", { "ANIMAL" })
	TagsInstance:New("CAT", { "ANIMAL", "MIRBLE" })
	TagsInstance:New("WOB", { "CAT" })

	-- Create and Set tags: so far so good
	C("j", "MIRBLE")
	C("k", "ANIMAL")
	C("l", "DOG")
	C("m", "CAT")
	C("n", "WOB")

	for _, v in ipairs(Objs) do
		local tag = LinksInstance:GetTag(v) -- Get tag: good

		print("object:", v.m_name)
		print("tag:", tag)

		local function P (tt)
			if type(tt) ~= "string" then
				print2(tt.m_name)
			elseif tt ~= tag then
				print2(tt)
			end
		end

		-- Children: good
		print1("CHILDREN!")

		for _, tt in TagsInstance:TagAndChildren(tag) do
			P(tt)
		end

		-- Multi-children: good
		print1("MULTI-CHILDREN (tag + ANIMAL)")

		for _, tt in TagsInstance:TagAndChildren--[[_Multi]]({ tag, "ANIMAL" }) do
			P(tt)
		end

		-- Parents: good
		print1("PARENTS!")

		for _, tt in TagsInstance:TagAndParents(tag) do
			P(tt)
		end

		-- Multi-parents: good
		print1("MULTI-PARENTS (tag + WOB)")

		for _, tt in TagsInstance:TagAndParents--[[_Multi]]({ tag, "WOB" }) do
			P(tt)
		end

		print("")

		-- Sublinks: good
		print1("Sublinks")

		for _, tt in TagsInstance:Sublinks(tag) do
			P(tt)
		end

		-- Has child: good
		print1("Has child: WOB", TagsInstance:HasChild(tag, "WOB"))
		print1("Has child: DOG", TagsInstance:HasChild(tag, "DOG"))
		print1("Has child: MOOP", TagsInstance:HasChild(tag, "MOOP"))

		-- Is: good
		print1("Is: MIRBLE", TagsInstance:Is(tag, "MIRBLE"))
		print1("Is: WOB", TagsInstance:Is(tag, "WOB"))
		print1("Is: GOOM", TagsInstance:Is(tag, "GOOM"))

		-- Has sublink: good
		print1("Has sublink: Derp", TagsInstance:HasSublink(tag, "Derp"))
		print1("Has sublink: nil", TagsInstance:HasSublink(tag, nil))
		print1("Has sublink: OOMP", TagsInstance:HasSublink(tag, "OOMP"))

		-- Tagged: good
		print1("Tagged")

		for _, tname in TagsInstance:TagAndChildren(tag) do
			for tt in LinksInstance:Tagged(tname) do
				P(tt)
			end
		end
	end

	local Messages = {}

	local function Print (message)
		if not Messages[message] then
			print1(message)

			Messages[message] = true
		end
	end

	-- Create links with can_link, sub_links
	local SubLinks = {}

	local From = #Objs

	for i = 1, 20 do
		local options = {}
		local sub_links = {}

		for j = 1, i % 3 do
			sub_links[j] = "SL_" .. ((i + 2) % 5)
		end

	--	options.sub_links = sub_links

		local can_link = true

		if i > 5 then
			function can_link (o1, o2, sub1, sub2)
				local num, message = (sub2 and sub2:GetName() or ""):match("SL_(%d+)") or 0 / 0

				if i <= 10 then
					message = num % 2 == 0 and "5 to 10, link to evens"
				elseif i <= 15 then
					message = num % 2 == 1 and "11 to 15, link to odds"
				else
					message = (sub2 == nil or num % 3 == 0) and "16 to 20, link to 3 * n / nil"
				end

				if message and Print then
					Print(message .. ": (" .. tostring(sub1:GetName()) .. ", " ..tostring(sub2:GetName()) .. ")")
				end

				return not not message
			end
		end

		local links = {}

		for _, v in ipairs(sub_links) do
			links[v] = can_link
		end

		options.sub_links = links

		SubLinks[i] = sub_links

		TagsInstance:New("tag_" .. i, options)

		C("object_" .. i, "tag_" .. i)
	end

	-- Can link: good?
	print("What can link?")

	local Links = {}

	for i = 1, 20 do
		for j = 1, 20 do
			if i ~= j then
				local o1, o2 = Objs[From + i], Objs[From + j]

				for k = 1, #SubLinks[i] + 1 do
					for l = 1, #SubLinks[j] + 1 do
						local sub1, sub2 = SubLinks[i][k], SubLinks[j][l]

						if LinksInstance:CanLink(o1, o2, sub1, sub2) then
							Links[#Links + 1] = { From + i, From + j, link = LinksInstance:LinkObjects(o1, o2, sub1, sub2) }

							assert(Links[#Links].link, "Invalid link")
						end
					end
				end
			end
		end
	end

	Print = nil

	print("Number of links: ", #Links)
	print("Let's break some!")

	local function LinkIndex (i)
		return i % #Links + 1
	end

	for _, v in ipairs{ 100, 200, 300, 400, 500, 600 } do
		local i = LinkIndex(v)
		local intact, o1, o2, sub1, sub2 = Links[i].link:GetObjects()

		print1("Link " .. i .. " intact?", intact, o1 and o1.m_name, o2 and o2.m_name, sub1, sub2)

		Links[i].link:Break()
	end

	print("State of one of those...")

	print1("Link ", LinkIndex(21--[[200]]), Links[LinkIndex(21--[[200]])].link:GetObjects())

	print("Let's destroy some objects!")

	for _, v in ipairs{ 50, 150, 250, 350, 450 } do
		local i = LinkIndex(v)
		local intact, o1, o2 = Links[i].link:GetObjects()

		if intact then
			local which

			if i % 2 == 0 then
				print("Link " .. i .. ", breaking object 1")

				which = o1
			else
				print("Link " .. i .. ", breaking object 2")

				which = o2
			end

			print1("Valid before?", Links[i].link:IsValid())

			which:removeSelf()

			print1("Valid after?", Links[i].link:IsValid())
		end
	end

	-- Links...
	local index = LinkIndex(14--[[173]])
	local link = Links[index].link
	local intact, lo, _, s1 = link:GetObjects()

	local function Obj (obj, sub, self)
		if obj == self then
			return "SELF"
		else
			return obj.m_name .. " (" .. tostring(sub) .. ")"
		end
	end

	print("Links belonging to link " .. index .. ", SELF = " .. Obj(lo, s1))

	for link in LinksInstance:Links(lo, s1) do
		local _, obj1, obj2, sub1, sub2 = link:GetObjects()

		print1("LINK: ", Obj(obj1, sub1, lo) .. " <-> " .. Obj(obj2, sub2, lo))
	end

	for i = -1, 7 do
		local sub = i ~= -1 and "SL_" .. i or nil

		print("Has links (" .. tostring(sub) .. ")?", LinksInstance:HasLinks(lo, sub))
	end
end






end

Scene:addEventListener("show")

--[[
	Near / not-too-far future TODO list:

	- Finish off seams sample, including dealing with device-side problems (PARTIAL)
	- Do the colored corners sample (PARTIAL)

	- Proceed with editor, finally implement some things like the background view
	- Refine link system, make more linkables (FSM's? All those things I was making before...)
	- Editor-wise, generally just make everything prettier, cleaner
	- Improve custom widgets (Bitmap, Grid1D, Grid2D, Keyboard, Link, LinkGroup, etc.)
	- Make some dialogs to stress-test the section feature
	- Decouple dialogs from the editor
	- Decouple links / tags from editor? Instancing? (PROBATION... classes have been defined)

--[=[
	Links:

-- In the dots, in the "new_tag" case, links could go in arg2
-- For verify, should be passed along in the verify structure, I suppose

dot\Switch.lua(36,31), dot\Warp.lua(40,31)

-- Editor cases probably fine, just another abstraction

editor\views\EventBlocks.lua(40,23), editor\views\GlobalEvents.lua(37,23),
editor\Events.lua(37,23), editor\GridViews.lua(52,23)

-- PROBABLY just an extension of the editor?

overlay\Link.lua(36,23)
]=]

--[=[
	Tags:

-- These I think would facilitate the editor abstraction I mentioned...

editor\Common.lua(37,30), editor\Events.lua(39,22)

-- If the rest was done, fairly easy; takes tags in constructor, then just need to
00 deal with a couple Corona-isms: "alive" predicate, and cleanup system (PROBATION)

editor\Links.lua(39,22)

-- Already mentioned

overlay\Link.lua(38,22)

-- Would be where it's all instantiated, perhaps? If not in events...

scene\MapEditor.lua(58,30)
]==]

	- Some sort of stuff for recurring UI tasks: save / load dialogs, listbox, etc. especially ones that recur outside the editor (PARTIAL)
	- Kill off redundant widgets (button, checkbox)

	- Play with input devices

	- Fix formatting, which is rather off on tablets and probably more high-definition phones

	- Make the resource system independent of Corona, then start using it more pervasively

	- Figure out if quaternions ARE working, if so promote them

	- ID-occupied array op module
	- Finally finish mesh ops / Delaunay
	- Finish up the dart-throwing stuff
	- Finish up the union-find-delete, some of those other data structures
	- Do a CMV or Poisson MVC sample?
	- Start something with geometric algebra, a la Lengyel
]]

return Scene