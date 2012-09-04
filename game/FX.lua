--- A library of special effects.

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
local pi = math.pi
local random = math.random

-- Corona globals --
local display = display
local graphics = graphics
local transition = transition

-- Imports --
local newImage = display.newImage

-- Exports --
local M = {}

do -- Flag effect
end

do -- POOF! effect
	-- Effect params --
	local Params = { alpha = 1, transition = easing.inOutQuad, onComplete = display.remove }

	-- Helper to size particles
	local function Size ()
		return 1 + random() * .2
	end

	--- A small poof! cloud.
	-- @pgroup group Display group that will hold display objects produced by effect.
	-- @number x Approximate x-coordinate of effect.
	-- @number y Approximate y-coordinate of effect.
	-- @treturn uint Death time of poof.
	function M.Poof (group, x, y)
		local poof = newImage(group, "FX_Assets/Poof.png", x, y)

		poof.xScale = .2
		poof.yScale = .2
		poof.alpha = .4

		Params.delay = random(0, 400)
		Params.time = random(400, 700)
		Params.rotation = pi * (-10 + random() * 20)
		Params.xScale = 1 + math.random() * .2
		Params.yScale = 1 + math.random() * .2

		transition.to(poof, Params)

		return Params.delay + Params.time
	end
end

do -- POW! effect
	-- Fade-out part of effect --
	local Done = { time = 100, delay = 50, alpha = .25, transition = easing.outExpo, onComplete = display.remove }

	-- Fade-in part of effect --
	local Params = {
		time = 350, alpha = 1, transition = easing.inOutExpo,

		onComplete = function(object)
			if object.parent then
				transition.to(object, Done)
			end
		end
	}

	-- Helper for common effect logic
	local function AuxPOW (object, xs, ys, rot)
		object.alpha = .25

		Params.xScale = xs
		Params.yScale = ys
		Params.rotation = rot

		transition.to(object, Params)
	end

	--- A quick "POW!" effect.
	-- @pgroup group Display group that will hold display objects produced by effect.
	-- @number x Approximate x-coordinate of effect.
	-- @number y Approximate y-coordinate of effect.
	function M.Pow (group, x, y)
		x = x + 32

		local star = newImage(group, "FX_Assets/BonkStar.png", x, y)
		local word = newImage(group, "FX_Assets/Pow.png", x, y)

		AuxPOW(star, 2, 2, 180)
		AuxPOW(word, 2, 2)
	end
end

do -- Ripple effect
end

do -- Sparkles effect
	-- Fade-out part of effect --
	local Done = { time = 400, alpha = .25,	onComplete = display.remove }

	-- Helper to displace particle paths
	local function Offset ()
		return (.5 - random()) * 2
	end

	-- Fade-in part of effect --
	local Params = {
		alpha = 1,

		onComplete = function(object)
			if object.x then
				Done.x = object.x + Offset() * 2.5
				Done.y = object.y - 8

				transition.to(object, Done)
			end
		end
	}	

	-- Helper to size particles
	local function Size ()
		return .2 + random() * .4
	end

	--- A small particle effect to indicate that the map has been tapped.
	-- @pgroup group Display group that will hold display objects produced by effect.
	-- @number x Approximate x-coordinate of effect.
	-- @number y Approximate y-coordinate of effect.
	function M.Sparkle (group, x, y)
		for _ = 1, 3 do
			local sparkle = newImage(group, "FX_Assets/Sparkle.png", 0, 0)

			sparkle.x, sparkle.xScale = x, Size()
			sparkle.y, sparkle.yScale = y, Size()
			sparkle.alpha = .4

			Params.x = x + Offset() * 32
			Params.y = y - Offset() * 4 - 32
			Params.time = random(250, 400)

			transition.to(sparkle, Params)
		end
	end
end

do -- Warp effects
	-- Mask clearing onComplete
	local function ClearMask (object)
		object:setMask(nil)
	end

	-- Scales an object's mask relative to its body to get a decent warp look
	local function ScaleObject (body, object)
		object = object or body

		object.maskScaleX = body.width / 4
		object.maskScaleY = body.height / 2
	end

	-- Mask-in transition --
	local MaskIn = { time = 900, transition = easing.inQuad }

	--- Performs a "warp in" effect on an object (using its mask, probably set by @{WarpOut}).
	-- @pobject object Object to warp in.
	-- @callable on_complete Optional **onComplete** handler for the transition. If absent,
	-- a default clears the object's mask; otherwise, the handler should also do this.
	-- @treturn TransitionHandle A handle for pausing or cancelling the transition.
	function M.WarpIn (object, on_complete)
		ScaleObject(object, MaskIn)

		MaskIn.onComplete = on_complete or ClearMask

		local handle = transition.to(object, MaskIn)

		MaskIn.onComplete = nil

		return handle
	end

	-- Mask-out transition --
	local MaskOut = { maskScaleX = 0, maskScaleY = 0, time = 900, transition = easing.outQuad }

	--- Performs a "warp out" effect on an object, via masking.
	-- @pobject object Object to warp out.
	-- @callable on_complete Optional **onComplete** handler for the transition.
	-- @treturn TransitionHandle A handle for pausing or cancelling the transition.
	-- @see WarpIn
	function M.WarpOut (object, on_complete)
		object:setMask(graphics.newMask("Dot_Assets/WarpMask.png"))

		ScaleObject(object)

		MaskOut.onComplete = on_complete

		local handle = transition.to(object, MaskOut)

		MaskOut.onComplete = nil

		return handle
	end
end

-- Export the module.
return M