--- Various glow-based utilities.

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

-- Corona globals --
local transition = transition

-- Exports --
local M = {}

-- Ping-pong params used to make things glow --
local GlowParams = { time = 1100, t = 1, transition = easing.inOutQuad, iterations = 0 }

-- Common glow interpolation factor --
local Glow = {}

--- Factory.
-- @byte r1 Red #1.
-- @byte g1 Green #1.
-- @byte b1 Blue #1.
-- @byte r2 Red #2.
-- @byte g2 Green #2.
-- @byte b2 Blue #2.
-- @treturn function Getter, which returns the red, green, and blue values interpolated to
-- the current glow time.
-- @see GetGlowTime
function M.ColorInterpolator (r1, g1, b1, r2, g2, b2)
	return function()
		local u = 1 - (1 - 2 * Glow.t)^2
		local s, t = 1 - u, u

		return s * r1 + t * r2, s * g1 + t * g2, s * b1 + t * b2
	end
end

--- Getter.
-- @treturn number Current glow time, &isin; [0, 1].
function M.GetGlowTime ()
	return Glow.t
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function()
		Glow.t = 0

		transition.to(Glow, GlowParams)
	end,

	-- Leave Level --
	leave_level = function()
		transition.cancel(Glow)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M