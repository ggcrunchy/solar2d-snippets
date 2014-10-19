--- A section is a callback used to represent current program state, e.g. the current
-- screen or as the procedure for the main window.
--
-- A section group serves as a repository of loaded sections, as well as a basic control
-- center for navigating between them. More powerful functionality can be built atop it.
-- @module SectionGroup

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
local error = error
local format = string.format
local pairs = pairs
local remove = table.remove
local tostring = tostring

-- Modules --
local class = require("tektite_core.class")
local table_funcs = require("tektite_core.table.funcs")
local var_preds = require("tektite_core.var.predicates")

-- Imports --
local Find = table_funcs.Find
local IsCallable = var_preds.IsCallable

-- Unique member keys --
local _sections = {}
local _stack = {}

-- Internal proc states --
local Internal = table_funcs.MakeSet{
	"load", "unload",
	"move",
	"open", "close",
	"resume", "suspend"
}

-- SectionGroup class definition --
return class.Define(function(SectionGroup)
	-- Calls a section proc
	local function Proc (section, what, ...)
		if section then
			return section(what, ...)
		end
	end

	--- Sends a message to the current section as
	--    proc(what, ...).
	-- If the stack is empty, this is a no-op.
	-- @param what Message, which may be any non-**nil** value not used by another method.
	-- @param ... Message payload.
	-- @see SectionGroup:Send
	function SectionGroup:__call (what, ...)
		assert(what ~= nil, "state == nil")
		assert(not Internal[what], "Cannot call proc with internal message")

		local stack = self[_stack]

		Proc(stack[#stack], what, ...)
	end

	-- Removes a section from the stack
	local function Remove (G, where, type, ...)
		Proc(remove(G[_stack], where), type, ...)
	end

	--- Clears the active section stack.
	--
	-- Each section, from top to bottom, is called as
	--    proc("close", true)
	-- where the **true** indicates that the close was during a clear.
	function SectionGroup:Clear ()
		local stack = self[_stack]

		while #stack > 0 do
			Remove(self, nil, "close", true)
		end
	end

	-- Section acquire helper
	local function GetSection (G, name)
		local section = G[_sections][name]

		if section then
			return section
		else
			error(format("Section \"%s\" does not exist", tostring(name)))
		end
	end

	--- Closes an active section.
	--
	-- The section is called as
	--    proc("close", false, ...)
	-- where the **false** indicates that the close was not in @{SectionGroup:Clear}.
	--
	-- If the current section is closed, and another is below it on the stack, that section
	-- is called as
	--    other_proc("resume")
	-- This is a no-op if the stack is empty or the section is not open.
	-- @param name Name of section to close. If **nil**, uses the current section.
	-- @param ... Close arguments.
	-- @see SectionGroup:Open
	function SectionGroup:Close (name, ...)
		local stack = self[_stack]

		-- Close the section if it was loaded.
		local where = name == nil and #stack or Find(stack, GetSection(self, name), true)

		if where and where > 0 then
			Remove(self, where, "close", false, ...)

			-- If the section was topmost, resume the lower section, if it exists.
			if where == #stack + 1 then
				Proc(stack[#stack], "resume")
			end
		end
	end

	--- Getter.
	-- @return Current section name, or **nil** if the stack is empty.
	function SectionGroup:Current ()
		local stack = self[_stack]

		return Find(self[_sections], stack[#stack])
	end

	--- Predicate.
	-- @param name Section name.
	-- @treturn boolean The named section is somewhere in the stack?
	function SectionGroup:IsOpen (name)
		assert(name ~= nil)

		return not not Find(self[_stack], self[_sections][name], true)
	end

	--- Metamethod.
	-- @treturn uint Number of open sections.
	function SectionGroup:__len ()
		return #self[_stack]
	end

	--- Adds a section to the group.
	--
	-- If a section is already registered under _name_, it is called as
	--    old_proc("unload")
	-- and replaced with the new one, which is called as
	--    proc("load", ...)
	-- @param name Section name.
	-- @callable proc Section procedure, whose first parameter will be the current callback
	-- message; any others are input associated with the message.
	-- @param ... Load arguments.
	function SectionGroup:Load (name, proc, ...)
		assert(name ~= nil)
		assert(IsCallable(proc), "Uncallable proc")

		-- Unload any section already loaded under the given name.
		Proc(self[_sections][name], "unload")

		-- Install the section.
		self[_sections][name] = proc

		-- Load the section.
		proc("load", ...)
	end

	--- Opens a section and makes it current.
	--
	-- If another section is already current, it is called as
	--    other_proc("suspend")
	-- If the new section is already open, it is called as
	--    proc("move")
	-- The section is moved or pushed to the top of the stack, and finally called as
	--    proc("open", ...)
	-- This is a no-op if the section is already open and current.
	-- @param name Name of section to open.
	-- @param ... Open arguments.
	function SectionGroup:Open (name, ...)
		assert(name ~= nil)

		local stack = self[_stack]
		local section = GetSection(self, name)

		-- Proceed if the section is not already topmost, suspending any current section.
		local top = stack[#stack]

		if top ~= section then
			Proc(top, "suspend")

			-- If the section is already loaded, report the move.
			local where = Find(stack, section, true)

			if where then
				Remove(self, where, "move")
			end

			-- Push the section onto the stack.
			stack[#stack + 1] = section

			-- Open the section.
			section("open", ...)
		end
	end

	--- Sends a message to any section directly, called as
	--    return proc(what, ...)
	-- The section need not be open.
	-- @param name Section name.
	-- @param what Message, which may be any non-**nil** value not used by another method.
	-- @param ... Message payload.
	-- @return Results of _proc_, if any.
	-- @see SectionGroup:__call
	function SectionGroup:Send (name, what, ...)
		assert(name ~= nil)
		assert(what ~= nil)
		assert(not Internal[what], "Cannot call proc with internal message")

		return GetSection(self, name)(what, ...)
	end

	--- Unloads all registered sections, removing them from the group in arbitrary order.
	--
	-- Each section is called as
	--    proc("unload", ...)
	-- @param ... Unload arguments.
	function SectionGroup:Unload (...)
		self[_stack] = {}

		for name, section in pairs(self[_sections]) do
			self[_sections][name] = nil

			section("unload", ...)
		end
	end

	--- Class constructor.
	function SectionGroup:__cons ()
		self[_sections] = {}
		self[_stack] = {}
	end
end)