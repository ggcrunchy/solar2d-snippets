--- Image sheet UI utilities.

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
local ipairs = ipairs
local max = math.max
local tonumber = tonumber

-- Modules --
local grid_iterators = require("iterator_ops.grid")

-- Corona globals --
local display = display
local graphics = graphics

-- Exports --
local M = {}

--- DOCME
-- @pobject image
-- @treturn uint A
function M.GetSpriteSetImageFrame (image)
	return tonumber(image.sequence)
end

-- Detection for multisheet sprites --
local IsMultiSheet = setmetatable({}, { __index = "k" })

--
local function AuxNewImage (group, images, x, y, w, h, frame)
	local image

	if IsMultiSheet[images] then
		image = display.newSprite(images[1].sheet, images)

		if frame then
			M.SetSpriteSetImageFrame(image, frame)
		end

		image.xScale = w and w / image.width or 1
		image.yScale = h and h / image.height or 1
	else
		image = display.newImage(images, frame)
	end

	group:insert(image)

	image.x, image.y = x or 0, y or 0

	return image
end

--- DOCME
-- @pgroup group
-- @ptable images
-- @number x
-- @number y
-- @number w
-- @number h
-- @treturn DisplayObject X
function M.NewImage (group, images, x, y, w, h)
	return AuxNewImage(group, images, x, y, w, h)
end

--- DOCME
-- @pgroup group
-- @ptable images
-- @uint frame
-- @number x
-- @number y
-- @number w
-- @number h
-- @treturn DisplayObject X
function M.NewImageAtFrame (group, images, frame, x, y, w, h)
	return AuxNewImage(group, images, x, y, w, h, frame)
end

-- --
local OnlyFrame = { 1 }

--
local function FrameName (index)
	return ("%i"):format(index)
end

--- DOCME
-- @array files
-- @return
function M.NewSpriteSetFromImages (files)
	local pieces, sheet = {}, { numFrames = 1 }

	for i, file in ipairs(files) do
		local image = display.newImage(file)

		sheet.width, sheet.height = image.width, image.height

		image:removeSelf()

		pieces[#pieces + 1] = { sheet = graphics.newImageSheet(file, sheet), frames = OnlyFrame, name = FrameName(i) }
	end

	IsMultiSheet[pieces] = true

	return pieces
end

--- DOCME
-- @pobject image
-- @uint frame
function M.SetSpriteSetImageFrame (image, frame)
	image:setSequence(FrameName(frame))
end

-- --
local Factories = {}

--- DOCMAYBE
-- @param sheet_image
-- @param sheet
-- @treturn function X
function M.NewSpriteFactory (sheet_image, sheet)
	local factory = {}

	--- DOCME
	function factory:Load ()
		self.m_isheet = self.m_isheet or graphics.newImageSheet(sheet_image, sheet)
	end

	--- DOCME
	-- @pgroup group
	-- @treturn DisplayObject X
	function factory:NewSprite (group)
		self:Load()

		return display.newSprite(group, self.m_isheet, sheet.m_sprites)
	end

	Factories[#Factories + 1] = factory

	return factory
end

-- Widths of each column (same for each row; may be 0) during tiling --
local Widths = {}

-- Adds a row of frames to the tiling
local function DoRow (name, frames, row, ncols, x, y, h)
	h = max(h, 1)

	for col = 1, ncols do
		local w = Widths[col]

		frames[#frames + 1] = { x = x, y = y, width = max(w, 1), height = h }

		x = x + w
	end
end

--- Converts an image into a tileset.
-- @string name Image filename.
-- @uint ncols How many columns will the image be tiled into, left to right?
-- @uint nrows How many rows will the image be tile into, top to bottom?
-- @int[opt=0] x1 Upper-left corner of sub-image to tile, x-coordinate.
-- @int[opt=0] y1 ...and y-coordinate.
-- @int[opt] x2 Lower-right corner of sub-image to tile, x-coordinate. If absent, image width - 1.
-- @int[opt] y2 ...and y-coordinate. If absent, image height - 1
-- @treturn ImageSheet Tiled image sheet, with _ncols_ * _nrows_ frames.
function M.TileImage (name, ncols, nrows, x1, y1, x2, y2)
	x1, y1 = x1 or 0, y1 or 0

	-- If necessary, open the image temporarily to poll the rect size.
	if not (x2 and y2) then
		local temp = display.newImage(name)

		x2 = x2 or temp.width - 1
		y2 = y2 or temp.height - 1

		temp:removeSelf()
	end

	-- CONSIDER: Option to scale up snapshot and carve that up instead?
	-- May yield better results owing to filtering

	-- Do a "line" walk from point (1, x1) to (ncols, x2). The "y" deltas are the widths
	-- of each column; accumulate these into the widths list.
	local curcol, prevx = -1, x1

	for col, xoff in grid_iterators.LineIter(1, x1, ncols, x2) do
		if col > curcol then
			if col >= 2 then
				Widths[col - 1], prevx = xoff - prevx, xoff
			end

			if col == ncols then
				Widths[col] = x2 - xoff
			end

			curcol = col
		end
	end

	-- Do the same sort of walk over the y and row values. The "y" deltas will now be the
	-- heights of each row. We already have the column widths (which are the same at every
	-- row), so we can build all the frames along the row.
	local frames, currow, prevy = {}, -1, y1

	for row, yoff in grid_iterators.LineIter(1, y1, nrows, y2) do
		if row > currow then
			if row >= 2 then
				DoRow(name, frames, row - 1, ncols, x1, prevy, yoff - prevy)

				prevy = yoff
			end

			if row == nrows then
				DoRow(name, frames, row, ncols, x1, yoff, y2 - yoff)
			end

			currow = row
		end
	end

	-- Finally, make the sheet.
	return graphics.newImageSheet(name, { frames = frames })
end

-- Leave Level response
local function LeaveLevel ()
	for _, factory in ipairs(Factories) do
		factory.m_isheet = nil
	end
end

-- Listen to events.
for k, v in pairs{
	-- Leave Level --
	leave_level = LeaveLevel,

	-- Leave Menus --
	leave_menus = LeaveLevel
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M