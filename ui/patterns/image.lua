--- Some useful UI patterns based on images.

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
local pairs = pairs

-- Modules --
local require_ex = require("tektite.require_ex")
local jpeg = require("image_ops.jpeg")
local png = require("image_ops.png")
local string_utils = require("utils.String")
local table_view_patterns = require_ex.Lazy("ui.patterns.table_view")

-- Corona globals --
local display = display
local system = system

-- Cached module references --
local _Thumbnail_

-- Exports --
local M = {}

--
local function Failure () return false end

--
local function GetFunc (name, func)
	if string_utils.EndsWith_AnyCase(name, ".png") then
		return png[func]
	elseif string_utils.EndsWith_AnyCase(name, ".jpg") or string_utils.EndsWith_AnyCase(name, ".jpeg") then
		return jpeg[func]
	else
		return Failure
	end
end

-- --
local Exts = { ".jpg", ".jpeg", ".png" }

--- DOCME
function M.ImageList (group, x, y, options)
	--
	local new_opts = {}

	for k, v in pairs(options) do
		new_opts[k] = v
	end

	new_opts.exts = Exts

	options = new_opts

	--
	local path, base, preview = options.path, options.base

	if options.add_preview or options.preview_width or options.preview_height then
		local press = options.press

		-- Updates the thumbnail in the preview pane.
		local function Press (event)
			preview:SetImageFromMemory(event.listbox:GetContents(), path .. "/" .. event.str, base)
			-- TODO: ^^ This is sort of awkward...
		end

		if press then
			options.press = function(event)
				Press(event)
				press(event)
			end
		else
			options.press = Press
		end

		-- Make a small preview pane for the currently chosen image.
		preview = _Thumbnail_(group, options.preview_width or 64, options.preview_height or 64)
	end

	--
	local filter_info = options.filter_info

	if filter_info then
		function options.filter (file, contents, fl)
			local func = contents and GetFunc(file, "GetInfoString")

			if func then
				local good, w, h, data = func(contents)

				return good and filter_info(file, w, h, data, fl)
			end
		end
	end

	--
	local ImageList = table_view_patterns.FileList(group, x, y, options)

	--- DOCME
	function ImageList:GetDims ()
		local ok, w, h = GetFunc(self:GetSelection() or "", "GetInfoString")(self:GetContents())

		if ok then
			return w, h
		else
			return 0, 0
		end
	end

	--- DOCME
	function ImageList:GetImageLoader (yfunc)
		local func = GetFunc(self:GetSelection() or "", "LoadString")
		local contents = func ~= Failure and self:GetContents()

		return function()
			return func(contents, yfunc)
		end
	end

	--
	if preview then
		--- DOCME
		function ImageList:GetPreview ()
			return preview
		end

		ImageList:addEventListener("finalize", function()
			if preview.parent then
				preview:removeSelf()
			end
		end)
	end

	--- DOCME
	function ImageList:LoadImage (yfunc)
		return GetFunc(self:GetSelection() or "", "LoadString")(self:GetContents(), yfunc)
	end

	return ImageList
end

--- DOCME
-- @pgroup group
-- @uint w Thumbnail width...
-- @uint h ...and height.
-- @ptable[opt] opts
-- @treturn DisplayGroup Thumbnail.
function M.Thumbnail (group, w, h, opts)
	local Thumbnail = display.newGroup()

	group:insert(Thumbnail)

	--
	local color, image = display.newRect(Thumbnail, 0, 0, w, h)
	local frame = not (opts and opts.no_frame) and display.newRect(Thumbnail, 0, 0, w, h)

--	if opts then
		color:setFillColor{ type = "gradient", color1 = { 0, 0, 1 }, color2 = { .3 }, direction = "down" }

		if frame then
			frame:setFillColor(0, 0)

			frame.strokeWidth = 3
		end
--	end
	-- ^^ TODO: Make these configurable...

	--- Clears the thumbnail image, if any.
	function Thumbnail:Clear ()
		display.remove(image)

		image = nil
	end

	--- DOCME
	function Thumbnail:GetDims ()
		return w, h
	end

	--- DOCME
	function Thumbnail:GetPos ()
		return self:localToContent(color.x, color.y)
	end

	--
	local function AuxSetImage (into, name, base, exists, iw, ih)
		if exists then
			display.remove(image)

			if iw <= w and ih <= h then
				image = display.newImage(into, name, base)
			else
				image = display.newImageRect(into, name, base, w, h)
			end

			image.x, image.y = color.x, color.y

			-- Keep the frame in front of the new image.
			if frame then
				frame:toBack()
			end
		end

		return exists
	end

	--- DOCME
	-- @string name Image filename.
	-- @param[opt=system.ResourceDirectory] base Base directory.
	-- @treturn boolean If true, the image was set.
	function Thumbnail:SetImage (name, base)
		base = base or system.ResourceDirectory

		return AuxSetImage(self, name, base, GetFunc(name, "GetInfo")(system.pathForFile(name, base)))
	end

	--- DOCME
	-- TODO: Kind of clumsy, this one is under probation :/
	function Thumbnail:SetImageFromMemory (stream, name, base)
		return AuxSetImage(self, name, base, GetFunc(name, "GetInfoString")(stream))
	end

	return Thumbnail
end

-- Cache module members.
_Thumbnail_ = M.Thumbnail

-- Export the module.
return M