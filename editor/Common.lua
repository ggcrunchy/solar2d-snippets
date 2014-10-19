--- Components shared throughout the editor.

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
local format = string.format
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs

-- Modules --
local require_ex = require("tektite_core.require_ex")
local adaptive = require("tektite_core.table.adaptive")
local sheet = require("corona_ui.utils.sheet")
local tags = require_ex.Lazy("editor.Tags")

-- Corona globals --
local display = display
local transition = transition

-- Exports --
local M = {}

-- Buttons that editor elements need to access --
local Buttons

--- Registers a button for general editor use.
-- @string name Name used to access button.
-- @pgroup button @{corona_ui.widgets.button} object.
function M.AddButton (name, button)
	Buttons = Buttons or {}

	Buttons[name] = button
end

-- Full-screen dummy widgets used to implement modal behavior --
-- CONSIDER: Can the use cases be subsumed into an overlay?
local Nets

-- Nets intercept all input
local function NetTouch (event)
	event.target.m_caught = true

	return true
end

-- Removes nets whose object is invisible or has been removed
local function WatchNets ()
	for net, object in pairs(Nets) do
		if net.m_caught and net.m_hide_object then
			object.isVisible = false
		end

		if not object.isVisible then
			net:removeSelf()

			Nets[net] = nil
		end
	end
end

--- DOCMAYBE
-- @pgroup group
-- @pobject object
-- @bool hide
function M.AddNet (group, object, hide)
	if not Nets then
		Nets = {}

		Runtime:addEventListener("enterFrame", WatchNets)
	end

	local net = M.NewRect(group, 0, 0, display.contentWidth, display.contentHeight)

	net.m_hide_object = not not hide

	net:addEventListener("touch", NetTouch)
	net:setFillColor(1, .125)
	net:toFront()
	object:toFront()
	net:translate(display.contentCenterX, display.contentCenterY)

	Nets[net] = object
end

-- --
local RepToValues, ValuesToRep

--
local function BackBind (values, rep)
	if values ~= nil then
		ValuesToRep[values] = rep
	end
end

--- DOCME
function M.BindRepAndValues (rep, values)
	local prev

	if rep then
		prev = RepToValues[rep]

		BackBind(prev, nil)
		BackBind(values, rep)

		RepToValues[rep] = values
	end

	return prev
end

--- Cleans up various state used pervasively by the editor.
function M.CleanUp ()
	if Nets then
		for net in pairs(Nets) do
			net:removeSelf()
		end

		Runtime:removeEventListener("enterFrame", WatchNets)
	end

	Buttons, Nets, RepToValues, ValuesToRep = nil
end

--- Copies into one table from another.
-- @ptable dt Destination table.
-- @ptable t Source table. If absent, _dt_.
-- @param ignore If present, a key to skip during copying.
-- @return table _dt_.
function M.CopyInto (dt, t, ignore)
	for k, v in M.PairsIf(t) do
		if k ~= ignore then
			dt[k] = v
		end
	end

	return dt
end

-- Are there changes in need of saving? --
local IsDirty

-- Is the working level game-ready? --
local IsVerified

--- Sets the editor dirty state, if clear, and updates dirty-related features.
--
-- The working level must also be re-verified.
-- @see IsDirty, IsVerified, Undirty, Verify
function M.Dirty ()
	M.FadeButton("Save", not IsDirty, 1)
	M.FadeButton("Verify", IsVerified, 1)

	IsDirty, IsVerified = true, false
end

-- Button fade transition --
local FadeParams = {}

--- Fades a button, if available, in or out to a given opacity.
-- @param name Name of a button added by @{AddButton}.
-- @bool check If false, no fade is performed.
-- @number alpha Final alpha value &isin; [0, 1].
function M.FadeButton (name, check, alpha)
	if check and Buttons[name] then
		FadeParams.alpha = alpha

		transition.to(Buttons[name], FadeParams)
	end
end

-- How many columns wide and how many rows tall is the working level? --
local NCols, NRows

--- Getter.
-- @treturn uint Number of columns in working level...
-- @treturn uint ...and number of rows.
function M.GetDims ()
	return NCols, NRows
end

--- DOCME
function M.GetTag (etype, on_editor_event)
	local tname = on_editor_event(etype, "get_tag")

	if tname and not tags.Exists(tname) then
		local topts, ret1, ret2 = on_editor_event(etype, "new_tag")

		if topts == "sources_and_targets" then
			local sub_links = {}

			for k in adaptive.IterSet(ret1) do
				sub_links[k] = "event_target"
			end

			for k in adaptive.IterSet(ret2) do
				sub_links[k] = "event_source"
			end

			topts = { sub_links = sub_links }
		-- Others?
		end

		tags.New(tname, topts)
	end

	return tname
end

--- DOCME
-- @ptable values
-- @treturn pobject O
function M.GetRepFromValues (values)
	return ValuesToRep[values]
end

--- DOCME
-- @pobject rep
-- @treturn table T
function M.GetValuesFromRep (rep)
	return RepToValues[rep]
end

-- Common "current selection" position --
local CurrentX, CurrentY

--- Initializes various state used pervasively by the editor.
-- @uint ncols How many columns will be in the working level...
-- @uint nrows ...and how many rows?
function M.Init (ncols, nrows)
	NCols, NRows, CurrentX, CurrentY = ncols, nrows

	if Buttons.Save then
		Buttons.Save.alpha = .4
	end

	if Buttons.Verify then
		Buttons.Verify.alpha = .4
	end

	RepToValues, ValuesToRep, IsDirty, IsVerified = {}, {}, false, false
end

--
local function NoOp () end

--- DOCME
function M.IpairsIf (t)
	if t then
		return ipairs(t)
	else
		return NoOp
	end
end

--- Predicate.
-- @treturn boolean Are there unsaved changes to the working level?
-- @see Dirty, Undirty
function M.IsDirty ()
	return IsDirty
end

--- Predicate.
-- @treturn boolean Is the working level game-ready?
-- @see Verify
function M.IsVerified ()
	return IsVerified
end

--- DOCMEMORE
-- Circle helper: since "group" may not be a group...
function M.NewCircle (group, x, y, radius)
	local circle = display.newCircle(x, y, radius)

	group:insert(circle)

	return circle
end

--- DOCMEMORE
-- ...rect helper...
function M.NewRect (group, x, y, w, h)
	local rect = display.newRect(x, y, w, h)

	group:insert(rect)

	return rect
end

--- DOCMEMORE
-- ...rounded rect helper
function M.NewRoundedRect (group, x, y, w, h, corner)
	local rrect = display.newRoundedRect(x, y, w, h, corner)

	group:insert(rrect)

	return rrect
end

--- DOCME
function M.PairsIf (t)
	if t then
		return pairs(t)
	else
		return NoOp
	end
end

--- DOCME
function M.Proxy (group, ...)
	local minx, miny, maxx, maxy

	for _, widget in M.IpairsIf{ ... } do
		local bounds = widget.contentBounds

		if minx then
			minx, miny, maxx, maxy = min(minx, bounds.xMin), min(miny, bounds.yMin), max(maxx, bounds.xMax), max(maxy, bounds.yMax)
		else
			minx, miny, maxx, maxy = bounds.xMin, bounds.yMin, bounds.xMax, bounds.yMax
		end
	end

	return minx and M.ProxyRect(group, minx, miny, maxx, maxy)
end

--- DOCME
function M.ProxyRect (group, minx, miny, maxx, maxy)
	local rect = M.NewRect(group, .5 * (minx + maxx), .5 * (miny + maxy), maxx - minx, maxy - miny)

	rect.isVisible = false

	rect.m_is_proxy = true

	return rect
end

--- Shows or hides the current selection widget. As a convenience, the last position of a
-- widget when hidden is applied to the next widget shown.
-- @pobject current Widget to show or hide.
-- @bool show If true, show the current item.
function M.ShowCurrent (current, show)
	if current.isVisible ~= not not show then
		if not show then
			CurrentX, CurrentY = current.x, current.y
		elseif CurrentX and CurrentY then
			current.x, current.y = CurrentX, CurrentY
		end

		current.isVisible = show
	end
end

--- DOCMAYBE
-- @string prefix
-- @array types
-- @treturn SpriteImages Y
function M.SpriteSetFromThumbs (prefix, types)
	local thumbs = {}

	for _, name in ipairs(types) do
		thumbs[#thumbs + 1] = format("%s_Assets/%s_Thumb.png", prefix, name)
	end

	return sheet.NewSpriteSetFromImages(thumbs)
end

--- Clears the editor dirty state, if set, and updates dirty-related features.
-- @see Dirty, IsDirty
function M.Undirty ()
	M.FadeButton("Save", IsDirty, .4)

	IsDirty = false
end

--- Sets the editor verified state, if clear, and updates verification-related features.
-- @see IsVerified
function M.Verify ()
	M.FadeButton("Verify", not IsVerified, .4)

	IsVerified = true
end

-- Export the module.
return M