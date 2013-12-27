--- UI utilities.

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
local remove = os.remove

-- Modules --
local mask = require("utils.Mask")

-- Corona globals --
local graphics = graphics
local system = system

-- Exports --
local M = {}

--- Getter.
-- @pobject object Object with a target group.
-- @treturn DisplayGroup Target assigned to _object_ by @{SetTarget}, or **nil** if absent.
function M.GetTarget (object)
	return object.m_target
end

--- Assigns a mask to an object.
-- @pobject object Object to assign the mask.
-- @pobject ref Reference object, used (at least) to set _object_'s **maskX** and **maskY**
-- properties.
-- @string name As a string, this is the filename of the mask to assign.
--
-- If _name_ = **true**, a rectangular mask is generated for _object_, using _ref_'s size.
--
-- If absent, this call only clears _object_'s mask.
-- @string dir Directory where mask file may be found (when _name_ is a string).
--
-- **CONSIDER**: Replace remove() by some LRU behavior?
function M.SetMask (object, ref, name, dir)
	object:setMask(nil)

	if name then
		local xscale, yscale = object.maskScaleX, object.maskScaleY

		if name == true then
			dir, name, xscale, yscale = system.TemporaryDirectory, mask.NewMask(ref.width, ref.height)
		end

		object:setMask(graphics.newMask(name, dir))

		if name == true then
			remove(system.pathForFile(name, system.TemporaryDirectory))
		end

		object.maskX = ref.x
		object.maskY = ref.y
		object.maskScaleX = xscale ~= 0 and xscale or 1
		object.maskScaleY = yscale ~= 0 and yscale or 1
	end
end

--- Sets a target group to an object.
--
-- This is useful for e.g. widgets that may switch between multiple views.
-- @pobject object Object to assign target.
-- @pgroup target Target to assign, or **nil** to clear the target.
-- @pgroup current Group into which _target_ is loaded.
-- @pgroup reserve If provided, acts as a cache. If _object_ already had a target, and it
-- differs from _target_, the old target will be sent to this group and not removed.
function M.SetTarget (object, target, current, reserve)
	if object.m_target == target then
		return
	elseif object.m_target then
		if reserve then
			reserve:insert(object.m_target)
		else
			object.m_target:removeSelf()
		end
	end

	if target then
		current:insert(target)
		target:toBack()
	end

	object.m_target = target
end

-- Export the module.
return M