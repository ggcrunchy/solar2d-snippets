--- Bitmap UI elements.
--
-- @todo Document skin...

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
local max = math.max
local min = math.min
local pairs = pairs
local remove = table.remove

-- Modules --
local color = require("ui.Color")

-- Corona globals --
local display = display
local timer = timer

-- Exports --
local M = {}

--
local function AddCapture (bitmap, capture)
	bitmap:insert(capture)

	capture.anchorX, capture.x = 0, 0
	capture.anchorY, capture.y = 0, 0

	bitmap.m_capture = capture
end

--
local function Cleanup (event)
	local bitmap = event.target

	bitmap.m_pending = nil

	timer.cancel(bitmap.m_update)
end

-- --
local Event = {}

--
local function Dispatch (name, target)
	Event.name = name
	Event.target = target

	target:dispatchEvent("name", Event)

	Event.target = nil
end

--
local function CanvasToStash (canvas, stash)
	for i = canvas.numChildren, 1, -1 do
		stash:insert(canvas[i])
	end
end

--- DOCME
function M.Bitmap (group)
	local bgroup = display.newGroup()

	group:insert(bgroup)

	--
	local white = display.newRect(bgroup, 0, 0, 1, 1)

	white.anchorX, white.x = 0, 0
	white.anchorY, white.y = 0, 0

	--
	local canvas = display.newGroup()

	bgroup:insert(canvas)

	--
	local stash = display.newGroup()

	bgroup:insert(stash)

	stash.isVisible = false

	--
	local cache, curw, curh = {}, 1, 1

	--- DOCME
	function bgroup:Clear ()
		display.remove(self.m_capture)

		self.m_capture = nil

		local pending = self.m_pending

		for k, v in pairs(pending) do
			cache[#cache + 1], pending[k] = v
		end

		CanvasToStash(canvas, stash)
		Dispatch("clear", self)
	end

	--- DOCME
	function bgroup:GetDims ()
		return curw, curh
	end

	--
	local quota = 150

	--- DOCME
	function bgroup:Resize (w, h)
		white.width, white.height = w, h

		--
		local old = self.m_capture

		if old and (w < curw or h < curh) then
			local new = display.captureBounds(white.contentBounds)

			old:removeSelf()

			AddCapture(self, new)
			CanvasToStash(canvas, stash)
		end

		--
		curw, curh, quota = w, h, max(5 * w, quota)

		--
		Event.w, Event.h = w, h

		Dispatch("resize", self)

		Event.w, Event.h = nil
	end

	--- DOCME
	function bgroup:SetPixel (x, y, ...)
		if x < curw and y < curh then
			local n = stash.numChildren

			if n > 0 then
				local pixel = stash[n]

				canvas:insert(pixel)
				pixel:setFillColor(...)

				pixel.x, pixel.y = x, y
			else
				local pending, key = self.m_pending, y * 2^16 + x
				local pcolor = pending[key] or remove(cache) or {}

				color.PackColor(pcolor, ...)

				pending[key], pcolor.x, pcolor.y = pcolor, x, y
			end
		end
	end

	--
	bgroup.m_pending = {}

	--
	local allocated = 0

	bgroup.m_update = timer.performWithDelay(30, function(event)
		--
		local extra = min(10, quota - allocated)

		for i = 1, extra do
			local pixel = display.newRect(stash, 0, 0, 1, 1)

			pixel.anchorX, pixel.anchorY = 0, 0
		end

		allocated = allocated + max(0, extra)

		--
		local pending, nstash = bgroup.m_pending, stash.numChildren

		for k, v in pairs(pending) do
			if nstash == 0 then
				break
			else
				local x, y = v.x, v.y

				if x < curw and y < curh then
					local pixel = stash[nstash]

					canvas:insert(pixel)

					pixel.x, pixel.y, nstash = x, y, nstash - 1

					color.SetFillColor(pixel, v)
				end

				cache[#cache + 1], pending[k] = v
			end
		end

		--
		local ncanvas = canvas.numChildren

		if ncanvas > 0 then
			local new = display.captureBounds(white.contentBounds)

			display.remove(bgroup.m_capture)

			AddCapture(bgroup, new)
			CanvasToStash(canvas, stash)

			--
			Dispatch("update", bgroup)
		end
	end, 0)

	--
	bgroup:addEventListener("finalize", Cleanup)

	return bgroup
end

-- Export the module.
return M