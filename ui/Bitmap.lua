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
local system = system
local timer = timer

-- Exports --
local M = {}

-- Adds (or updates) the canvas capture
local function AddCapture (bitmap, capture)
	bitmap:insert(capture)

	capture.anchorX, capture.x = 0, 0
	capture.anchorY, capture.y = 0, 0

	bitmap.m_capture = capture
end

-- Bitmap finalizer
local function Cleanup (event)
	local bitmap = event.target

	timer.cancel(bitmap.m_update)

	bitmap.m_capture, bitmap.m_pending, bitmap.m_update = nil
end

-- Event to dispatch --
local Event = {}

-- Dispatch events to bitmap
local function Dispatch (name, target)
	Event.name = name
	Event.target = target

	target:dispatchEvent("name", Event)

	Event.target = nil
end

-- Makes the canvas ready for reuse
local function ResetCanvas (canvas, stash)
	for i = canvas.numChildren, 1, -1 do
		stash:insert(canvas[i])
	end

	canvas:toFront()
end

-- Multiplier used to build unique keys for (x, y) pairs --
local MaxSize = system.getInfo("maxTextureSize")

-- Default stash quota --
local Quota = 150

--- DOCME
function M.Bitmap (group)
	local bgroup = display.newGroup()

	group:insert(bgroup)

	-- Use a white backdrop for uninitialized pixels.
	local curw, curh = 1, 1
	local white = display.newRect(bgroup, 0, 0, curw, curh)

	white.anchorX, white.x = 0, 0
	white.anchorY, white.y = 0, 0

	-- Add a canvas to track dirty pixels.
	local canvas = display.newGroup()

	bgroup:insert(canvas)

	-- Keep an invisible stash to recycle canvas pixels.
	local stash = display.newGroup()

	bgroup:insert(stash)

	stash.isVisible = false

	--- DOCME
	function bgroup:Clear ()
		display.remove(self.m_capture)

		self.m_pending, self.m_capture = {}

		ResetCanvas(canvas, stash)
		Dispatch("clear", self)
	end

	--- DOCME
	function bgroup:GetDims ()
		return curw, curh
	end

	-- Initialize the stash quota.
	local quota = Quota

	--- DOCME
	function bgroup:Resize (w, h)
		if w ~= curw or h ~= curh then
			white.width, white.height = w, h

			-- If at least one of the dimensions shrunk, capture the reduced contents and replace
			-- the current capture (also evicting the canvas). If one dimension also grew, the white
			-- backdrop will get captured, achieving the intended effect.
			local old = self.m_capture

			if old and (w < curw or h < curh) then
				local new = display.captureBounds(white.contentBounds)

				old:removeSelf()

				AddCapture(self, new)
				ResetCanvas(canvas, stash)
			end

			-- Update state and send an event.
			curw, curh, quota = w, h, max(w, quota)

			Event.w, Event.h = w, h

			Dispatch("resize", self)

			Event.w, Event.h = nil
		end
	end

	--- DOCME
	function bgroup:SetPixel (x, y, ...)
		if x < curw and y < curh then
			local n = stash.numChildren

			-- If the stash has pixels available, grab one and write it directly to the canvas.
			if n > 0 then
				local pixel = stash[n]

				canvas:insert(pixel)
				pixel:setFillColor(...)

				pixel.x, pixel.y = x, y

			-- Otherwise, add it to the waiting list.
			else
				self.m_pending[y * MaxSize + x] = color.PackColor_Number(...)
			end
		end
	end

	-- Create a waiting list.
	bgroup.m_pending = {}

	-- Watch for dirty pixels.
	local allocated = 0

	bgroup.m_update = timer.performWithDelay(30, function(event)
		-- Allocate some pixels, until a reasonable amount are available.
		local extra = min(10, quota - allocated)

		for i = 1, extra do
			local pixel = display.newRect(stash, 0, 0, 1, 1)

			pixel.anchorX, pixel.anchorY = 0, 0
		end

		allocated = allocated + max(0, extra)

		-- Service pending pixel set requests, until either the waiting list or the pixel stash is
		-- empty. Ignore requests for pixels that have become invalid due to resizes.
		local pending, nstash = bgroup.m_pending, stash.numChildren

		for k, v in pairs(pending) do
			if nstash == 0 then
				break
			else
				local x = k % MaxSize
				local y = (k - x) / MaxSize

				if x < curw and y < curh then
					local pixel = stash[nstash]

					canvas:insert(pixel)

					pixel.x, pixel.y, nstash = x, y, nstash - 1

					color.SetFillColor_Number(pixel, v)
				end

				pending[k] = nil
			end
		end

		-- If the canvas is dirty, capture its contents (overwriting any old capture), and put the
		-- canvas back in a clean state. Send an event.
		if canvas.numChildren > 0 then
			local new = display.captureBounds(white.contentBounds)

			display.remove(bgroup.m_capture)

			AddCapture(bgroup, new)
			ResetCanvas(canvas, stash)
			Dispatch("update", bgroup)
		end
	end, 0)

	-- Handle cleanup on removal.
	bgroup:addEventListener("finalize", Cleanup)

	return bgroup
end

-- Export the module.
return M