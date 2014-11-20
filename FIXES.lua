--- Various workarounds.

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
local type = type

-- Exports --
local M = {}

-- Cache original functions.
local newContainer = display.newContainer
local newGroup = display.newGroup

-- remove() function: seems to be shared among all containers and groups --
local Remove

-- Installs new remove() function
local function SetRemoveFunc (object)
	if not Remove then
		local remove = object.remove

		function Remove (self, child)
			if type(child) == "number" then
				child = self[child]
			end

			child:removeSelf()
		end
	end

	object.remove = Remove
end

-- Creates new removeSelf() function
local function NewRemoveSelfFunc (object)
	local removeSelf = object.removeSelf

	return function(self)
		for i = self.numChildren, 1, -1 do
			self[i]:removeSelf()
		end

		removeSelf(self)
	end
end

-- removeSelf() function: seems to be shared among all containers --
local ContRemoveSelf

--- Override of `display.newContainer`, with fix for removals (namely, to ensure that
-- **"finalize"** events get dispatched to children.
-- @param ... Args passed along to original function.
-- @treturn Container Container object.
function display.newContainer (...)
	local cont = newContainer(...)

	SetRemoveFunc(cont)

	ContRemoveSelf = ContRemoveSelf or NewRemoveSelfFunc(cont)

	cont.removeSelf = ContRemoveSelf

	return cont
end

--- Override of `display.newGroup`, with fix as per `newContainer`.
-- @treturn Group Group object.
function display.newGroup ()
	local group = newGroup()

	SetRemoveFunc(group)

	group.removeSelf = NewRemoveSelfFunc(group)

	return group
end

-- Export the module.
return M