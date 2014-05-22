--- Bitmap UI elements.

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
local max = math.max
local min = math.min
local next = next
local pairs = pairs
local yield = coroutine.yield

-- Extension imports --
local indexOf = table.indexOf

-- Modules --
local color = require("ui.Color")
local operators = require("bitwise_ops.operators")

-- Corona globals --
local display = display
local system = system

-- Corona modules --
local composer = require("composer")

-- Exports --
local M = {}

-- Adds (or updates) the canvas capture
local function AddCapture (bitmap, capture)
	bitmap:insert(capture)

	capture.anchorX, capture.x = 0, 0
	capture.anchorY, capture.y = 0, 0

	bitmap.m_capture = capture
end

-- List of active bitmaps --
local UpdateList = {}

-- Activates a bitmap
local function AddToList (update)
	if not indexOf(UpdateList, update) then
		UpdateList[#UpdateList + 1] = update
	end
end

-- Deactivates a bitmap
local function RemoveFromList (update)
	local i, n = indexOf(UpdateList, update), #UpdateList

	if i then
		UpdateList[i] = UpdateList[n]
		UpdateList[n] = nil
	end
end

-- Bitmap finalizer
local function Cleanup (event)
	local bitmap = event.target

	RemoveFromList(bitmap.m_update)

	if bitmap.m_scene then
		local scene = composer.getScene(bitmap.m_name)

		scene:removeEventListener("hide", bitmap.m_scene)
		scene:removeEventListener("show", bitmap.m_scene)
	end

	bitmap.m_capture, bitmap.m_pending, bitmap.m_scene, bitmap.m_update = nil
end

-- Default wait function: no-op
local function DefWait () end

-- Event to dispatch --
local Event = {}

-- Dispatch events to bitmap
local function Dispatch (name, target)
	Event.name = name
	Event.target = target

	target:dispatchEvent("name", Event)

	Event.target = nil
end

-- Is the bitmap in a visible part of the hierarchy?
local function IsVisible (element)
	local stage = display.getCurrentStage()

	while element ~= stage and element.isVisible do
		element = element.parent
	end

	return element == stage and stage.isVisible
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

-- Operation to decompose a key
local FromKey

if operators.HasBitLib() then
	local band = operators.band
	local rshift = operators.rshift
	local nbits, power = 0, 1

	while power < MaxSize do
		nbits, power = nbits + 1, 2 * power
	end

	function FromKey (key)
		return band(key, power - 1), rshift(key, nbits)
	end

	-- With or without a bit library available, ToKey() involves a multiply-add. Since the
	-- maximum size is needed no longer, hijack it to streamline the operation.
	MaxSize = power
else
	function FromKey (key)
		local x = key % MaxSize

		return x, (key - x) / MaxSize
	end
end

-- Operation to compose a key
local function ToKey (x, y)
	return y * MaxSize + x
end

-- Default stash quota --
local Quota = 150

--- Creates a new 1-by-1 bitmap, with background enabled.
--
-- A bitmap will gradually incorporate changes to its pixels, while striving also to not
-- consume an inordinate amount of expensive (in time and / or space) per-pixel resources.
--
-- As with any display object, certain events are exposed via the **addEventListener** and
-- **removeEventListener** methods. Each such event provides the standard **name** key, along
-- with a reference to the bitmap itself under the **target** key.
--
-- If **composer** is being used, it is assumed that _group_ belongs to the current scene. If
-- this is not so, the bitmap will not be able to idle between scene switches.
-- @todo For correctness, the bitmap must currently be entirely on-screen and unobstructed.
-- In theory this can all be obviated with snapshots; otherwise it should be possible, though
-- quite a bit of effort, to work around this by building up the rest piece by piece, so long
-- as SOME region can be assumed to satisfy the aforementioned constraint... then the "dirty"
-- part of the image is updated here and patched in to its proper place once complete.
-- @pgroup group Group to which bitmap will be inserted.
-- @treturn DisplayObject Bitmap object.
function M.Bitmap (group)
	local Bitmap = display.newGroup()

	group:insert(Bitmap)

	-- Use a white backdrop for uninitialized pixels.
	local curw, curh = 1, 1
	local white = display.newRect(Bitmap, 0, 0, curw, curh)

	white.anchorX, white.x = 0, 0
	white.anchorY, white.y = 0, 0

	-- Add a canvas to track dirty pixels.
	local canvas = display.newGroup()

	Bitmap:insert(canvas)

	-- Keep an invisible stash to recycle canvas pixels.
	local stash = display.newGroup()

	Bitmap:insert(stash)

	stash.isVisible = false

	--- Cancels any pending sets. Dispatches a **"cancel"** event.
	function Bitmap:Cancel ()
		self.m_pending = {}

		Dispatch("cancel", self)
	end

	--- Clears all pixels, canceling any pending sets. Dispatches a **"clear"** event.
	function Bitmap:Clear ()
		display.remove(self.m_capture)

		self.m_pending, self.m_capture = {}

		ResetCanvas(canvas, stash)
		Dispatch("clear", self)
	end

	--- Getter.
	-- @treturn uint Bitmap width...
	-- @treturn uint ...and height.
	function Bitmap:GetDims ()
		return curw, curh
	end

	--- Predicate.
	-- @treturn boolean Set operations are pending?
	function Bitmap:HasPending ()
		return next(self.m_pending) ~= nil
	end

	-- Begin active.
	local is_paused = false

	--- Predicate.
	-- @treturn boolean The bitmap is paused?
	-- @see Bitmap:Pause, Bitmap:Resume
	function Bitmap:IsPaused ()
		return is_paused
	end

	--- Pauses bitmap updates. If already paused, this is a no-op.
	-- @see Bitmap:IsPaused, Bitmap:Resume
	function Bitmap:Pause ()
		is_paused = true
	end

	-- Initialize the stash quota.
	local quota = Quota

	--- Resizes the bitmap. If the size actually changed, dispatches a **"resize"** event,
	-- with the new width and height in keys **w** and **h**, respectively.
	-- @uint w New width, &gt; 0...
	-- @uint h ...and height.
	function Bitmap:Resize (w, h)
		assert(w > 0, "Invalid width")
		assert(h > 0, "Invalid height")

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

	--- Resumes bitmap updates. If not paused, this is a no-op.
	-- @see Bitmap:IsPaused, Bitmap:Pause
	function Bitmap:Resume ()
		is_paused = false
	end

	--- If possible, sets a pixel's color; otherwise, the assignment is put in a waiting list.
	--
	-- Each bitmap is periodically updated, during which some of the pending operations will be
	-- processed. The order in which these occur is unspecified; however, given the same _x_ and
	-- _y_, a **SetPixel** call will supercede any pending assignment.
	--
	-- If _x_ and _y_ refer to an out-of-bounds pixel, this is a no-op. A pending operation is
	-- similarly discarded, if out-of-bounds when being serviced (on account of resizes).
	--
	-- If any pixels were assigned, immediately or from the waiting list, since the previous
	-- timeout, an **"update"** event is dispatched at the end of the next / current timeout.
	-- @uint x Pixel x-coordinate...
	-- @uint y ...and y-coordinate.
	-- @param ... One to four numbers, &isin; [0, 1], as per the arguments to a display object's
	-- **setFillColor** or **setStrokeColor** methods. Gradients are not accepted.
	function Bitmap:SetPixel (x, y, ...)
		if x < curw and y < curh then
			local n = stash.numChildren

			-- If the stash has pixels available, grab one and write it directly to the canvas.
			local key = ToKey(x, y)

			if n > 0 and IsVisible(self) then
				local pixel = stash[n]

				canvas:insert(pixel)
				pixel:setFillColor(...)

				pixel.x, pixel.y, self.m_pending[key] = x, y

			-- Otherwise, add it to the waiting list.
			else
				self.m_pending[key] = color.PackColor_Number(...)
			end
		end
	end

	--- Enables or disables the background.
	--
	-- If enabled, unset pixels will be white, and transparent pixels will be partially white.
	--
	-- If disabled, the bitmap will capture the underlying background, which may have undesired
	-- results if there are many unset pixels, e.g. when the rest of the scene is quite dynamic.
	-- @bool show The background should be shown?
	function Bitmap:ShowBackground (show)
		white.isVisible = show
	end

	--- Yields the current coroutine until no more set operations are pending.
	-- @callable[opt] update Called (without arguments) before yielding, when set operations are
	-- still pending; if absent, a no-op.
	-- @see coroutine.yield, Bitmap:HasPending
	function Bitmap:WaitForPendingSets (update)
		update = update or DefWait

		while next(self.m_pending) do
			update()
			yield()
		end
	end

	-- Create a waiting list.
	Bitmap.m_pending = {}

	-- Watch for dirty pixels.
	local allocated = 0

	function Bitmap.m_update ()
		if not is_paused and IsVisible(Bitmap) then
			-- Allocate some pixels, until a reasonable amount are available.
			local extra = min(10, quota - allocated)

			for _ = 1, extra do
				local pixel = display.newRect(stash, 0, 0, 1, 1)

				pixel.anchorX, pixel.anchorY = 0, 0
			end

			allocated = allocated + max(0, extra)

			-- Service pending pixel set requests, until either the waiting list or the pixel stash is
			-- empty. Ignore requests for pixels that have become invalid due to resizes.
			local pending, nstash = Bitmap.m_pending, stash.numChildren

			for k, v in pairs(pending) do
				if nstash == 0 then
					break
				else
					local x, y = FromKey(k)

					if x < curw and y < curh then
						local pixel = stash[nstash]

						canvas:insert(pixel)

						pixel.x, pixel.y, nstash = x, y, nstash - 1

						color.SetFillColor_Number(pixel, v)
					end

					pending[k] = nil
				end
			end

			-- If the canvas is dirty, capture its contents (overwriting any old capture), and restore
			-- the canvas to a clean state. Send an event.
			if canvas.numChildren > 0 then
				local new = display.captureBounds(white.contentBounds)

				display.remove(Bitmap.m_capture)

				AddCapture(Bitmap, new)
				ResetCanvas(canvas, stash)
				Dispatch("update", Bitmap)
			end
		end
	end

	-- If the bitmap is being added to the current scene, hook into Composer's hide and show
	-- machinery to manage the update list on scene switches, keeping the scene name around
	-- for cleanup purposes. Connecting to a non-current scene is unsupported; however, being
	-- invisible, it would incur not much more than some listener overhead.
	local name = composer.getSceneName("current")
	local scene = name and composer.getScene(name)

	if scene then
		local stage, view = display.getCurrentStage(), scene.view

		while group ~= stage and group ~= view do
			group = group.parent
		end

		if group == view then
			function Bitmap.m_scene (event)
				if event.phase == "did" then
					if event.name == "show" then
						AddToList(Bitmap.m_update)
					else
						RemoveFromList(Bitmap.m_update)
					end
				end
			end

			Bitmap.m_name = name

			scene:addEventListener("hide", Bitmap.m_scene)
			scene:addEventListener("show", Bitmap.m_scene)
		end
	end

	-- If the bitmap was not added to a scene, it still needs to be updated.
	if not Bitmap.m_name then
		AddToList(Bitmap.m_update)
	end

	-- Handle cleanup on removal.
	Bitmap:addEventListener("finalize", Cleanup)

	return Bitmap
end

-- "enterFrame" listener --
Runtime:addEventListener("enterFrame", function()
	for i = 1, #UpdateList do
		UpdateList[i]()
	end
end)

-- Export the module.
return M