--- This module provides some per-frame logic.

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
local abs = math.abs

-- Corona globals --
local system = system

-- Cached module references --
local _GetFrameID_

-- Exports --
local M = {}

-- Unique frame ID (lazily evaluated) --
local FrameID = 0

-- Frame difference; last frame time --
local Diff, Last = 0

--- Getter.
-- @treturn number Difference in time since last frame.
function M.DiffTime ()
	return Diff
end

--- Getter.
-- @treturn uint Current frame ID.
function M.GetFrameID ()
	if FrameID <= 0 then
		FrameID = 1 - FrameID
	end

	return FrameID
end

--- Getter.
-- @treturn number Time for this frame.
function M.GetFrameTime ()
	return Last
end

--- Enforces that a function is only called once per frame, e.g. for lazy updates.
-- @callable func One-argument function to be called.
-- @treturn function Wrapper. On the first call in a frame, _func_ is called with the
-- wrapper's argument.
--
-- This wrapper returns **true** on the first call in a frame, **false** otherwise.
function M.OnFirstCallInFrame (func)
	local id

	return function(arg)
		local is_first = id ~= _GetFrameID_()

		if is_first then
			id = FrameID

			func(arg)
		end

		return is_first
	end
end

-- "enterFrame" listener --
Runtime:addEventListener("enterFrame", function(event)
	-- Update the time difference.
	Diff, Last = Last and (event.time - Last) / 1000 or 0, event.time

	-- Invalidate any ID from last frame.
	FrameID = -abs(FrameID)
end)

-- "system" listener --
Runtime:addEventListener("system", function(event)
	if event.type == "applicationStart" or event.type == "applicationResume" then
--		Last, Diff = system.getTimer(), 0
	elseif event.type == "applicationExit" then
--		SG:Clear()
	end
end)

-- Cache module members.
_GetFrameID_ = M.GetFrameID

-- Export the module.
return M