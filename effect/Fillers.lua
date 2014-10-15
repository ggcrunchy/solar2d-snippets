--- Various space-filling operations.
--
-- This module lays claim to the **"filler"** set, cf. @{effect.Stash}.

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
local ceil = math.ceil
local format = string.format
local pairs = pairs

-- Modules --
local audio = require("corona_utils.audio")
local circle = require("fill.Circle")
local pixels = require("utils.Pixels")
local quantize = require("geom2d_ops.quantize")
local sheet = require("ui.Sheet")
local stash = require("effect.Stash")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local transition = transition

-- Exports --
local M = {}

-- Tile dimensions --
local TileW, TileH

-- Image sheets, cached from fill images used on this level --
local ImageCache

-- Current fill color for non-images --
local R, G, B = 1, 1, 1

-- Name of fill image --
local UsingImage

-- Fade-in transition --
local FadeInParams = {
	time = 300, alpha = 1, transition = easing.inOutExpo,

	onComplete = function(rect)
		local rgroup = rect.parent

		rgroup.m_unfilled = rgroup.m_unfilled - 1
	end
}

-- Sound played when shape is filled --
local Sounds = audio.NewSoundGroup{ shape_filled = { file = "ShapeFilled.mp3", wait = 1000 } }

-- Fill transition --
local FillParams = {
	time = 1350, transition = easing.outBounce,

	onComplete = function()
		Sounds:PlaySound("shape_filled")
	end
}

--
local function NewPixelRect (group)
	return display.newImage(group, pixels.GetPixelSheet(), 1)
end

--
local function StashPixels (event)
	stash.PushRect("filler", event.m_object, "is_group")
end

--- Fills a rectangular region gradually over time, according to a fill process.
--
-- If an image has been assigned with @{SetImage}, it will be used to fill the region.
-- Otherwise, the region is filled with a solid rectangle, tinted according to @{SetColor}.
--
-- Calling @{SetColor} or @{SetImage} will not affect a fill already in progress.
-- @pgroup group Group into which fill graphics are loaded.
-- @string[opt="circle"] how The fill process, which currently may be **"circle"**.
-- @number ulx Upper-left x-coordinate...
-- @number uly ...and y-coordinate.
-- @number lrx Lower-right x-coordinate...
-- @number lry ...and y-coordinate.
-- @treturn DisplayObject "Final" result of fill. Changing its parameters during the fill
-- may lead to strange results. It can be removed to cancel the fill.
function M.Fill (group, how, ulx, uly, lrx, lry)
	-- Lazily load sounds on first fill.
	Sounds:Load()

	-- Prepare the "final" object, that graphically matches the composite fill elements
	-- and will be left behind in their place once the fill operation is complete. Kick
	-- off the fill transition; as the object scales, the fill process will update to
	-- track its dimensions.
	local filler

	if UsingImage then
		filler = display.newImage(group, UsingImage)
	else
		filler = display.newRect(group, 0, 0, 1, 1)
	end

	local cx, w = (ulx + lrx) / 2, TileW / 2
	local cy, h = (uly + lry) / 2, TileH / 2

	filler.x, filler.width = cx, w
	filler.y, filler.height = cy, h

	FillParams.width = lrx - ulx
	FillParams.height = lry - uly

	transition.to(filler, FillParams)

	-- Extract useful effect values from the fill dimensions.
	local tilew, tileh = TileW / 2.5, TileH / 2.5
	local halfx, halfy = ceil(FillParams.width / tilew - 1), ceil(FillParams.height / tileh - 1)
	local nx, ny = halfx * 2 + 1, halfy * 2 + 1
	local dw, dh = FillParams.width / nx, FillParams.height / ny

	-- Save the current fill color or image. In the image case, tile it, then cache the
	-- tiling, since it may be reused, e.g. on level reset; if a tiling already exists,
	-- use that.
	local r, g, b = R, G, B
	local cur_image

	if UsingImage then
		local key = format("%s<%i,%i>", UsingImage, nx, ny)

		cur_image = ImageCache[key]

		if not cur_image then
			cur_image = { mid = halfy * nx + halfx + 1 }

			cur_image.isheet = sheet.TileImage(UsingImage, nx, ny)

			ImageCache[key] = cur_image
		end
	else
		filler:setFillColor(r, g, b)
	end

	-- Circle --
	if how == "circle" then
		local rgroup = display.newGroup()

		group:insert(rgroup)

		rgroup.m_unfilled = nx * ny

		-- A circle, quantized into subrectangles, which are faded in as the radius grows.
		-- In the image case, the rect will be an unanimated (??) sprite generated by the
		-- image tiling; otherwise, we pull the rect from the stash, if available. On each
		-- addition, a "spots remaining" counter is decremented. 
		local spread = circle.SpreadOut(halfx, halfy, function(x, y)
			local rx, ry, rect = cx + (x - .5) * dw, cy + (y - .5) * dh

			if cur_image then
				local index = cur_image.mid + y * nx + x

				rect = sheet.NewImageAtFrame(rgroup, cur_image.isheet, index, rx, ry, dw, dh)

				rect.xScale = dw / rect.width
				rect.yScale = dh / rect.height
			else
				rect = stash.PullRect("filler", rgroup)

				rect.x, rect.width = rx + dw / 2, dw
				rect.y, rect.height = ry + dh / 2, dh

				rect:setFillColor(r, g, b)
			end

			rect.alpha = .05

			transition.to(rect, FadeInParams)
		end)

		-- The final object begins hidden, since it will be built up visually from the fill
		-- components. Over time, fit its current shape to a circle and act in that region.
		filler.isVisible = false

		timers.RepeatEx(function()
			if filler.parent then
				local radius = quantize.ToBin_RoundUp(filler.width / dw, filler.height / dh, 1.15, .01)

				spread(radius)

				-- If there are still spots in the region to fill, quit. Otherwise, show the
				-- final result and go on to the next steps.
				if rgroup.m_unfilled ~= 0 then
					return
				end

				filler.isVisible = true
			end

			-- If the fill finished or was cancelled, we remove the intermediate components.
			-- In the case of an image, it's too much work to salvage anything, so just remove
			-- the group. Otherwise, stuff the components back into the stash.
			timers.DeferIf(cur_image and "remove" or StashPixels, rgroup)

			return "cancel"
		end, 45)

	-- Other options: random fill, cross-fade, Hilbert...
	else
		
	end

	return filler
end

--- Setter.
-- @byte r Red component of fill color. If absent, old value is retained (by default, 1).
-- @byte g ...green component, likewise...
-- @byte b ...and blue component.
function M.SetColor (r, g, b)
	R, G, B = r or R, g or G, b or B
end

--- Setter.
-- @string name Filename of fill image, or **nil** to clear the image.
function M.SetImage (name)
	UsingImage = name
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		ImageCache = {}
		TileW = level.w
		TileH = level.h
	end,

	-- Leave Level --
	leave_level = function()
		ImageCache = nil
	end,

	-- Reset Level --
	reset_level = function()
		for k, v in pairs(ImageCache) do
			ImageCache[k] = nil
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M