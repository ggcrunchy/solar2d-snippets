--- Shadow-based effects.

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
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Shadow methods --
local Shadow = {}

--- Fits a shadow property to a curve.
--
-- The final value of the property at a time _t_ will be `v0 + scale * dv`.
-- @string name Property name, which should correspond to some numeric property of the
-- shadow (typically, this will be a display object property).
-- @callable curve Curve function, called as
--    scale = curve(t)
-- @number v0 Original value of property.
-- @number dv Value delta.
-- @see Shadow:ResolveProperties
function Shadow:AddProperty (name, curve, v0, dv)
	local props = self.m_props or {}

	props[name] = function(t)
		return v0 + curve(t) * dv
	end

	self.m_props = props
end

--- Convenience method to add several properties using the same curve.
-- @callable curve Curve function.
--
-- In case of side effects, note that this function is called once per property.
-- @ptable args Key-value pairs, with each key corresponding to _name_ and each value a
-- table of the form { **v0** = _v0_, **dv** = _dv_ }, cf. @{Shadow:AddProperty}.
function Shadow:AddMultipleProperties (curve, args)
	for k, v in pairs(args) do
		self:AddProperty(k, curve, v.v0, v.dv)
	end
end

--- Resolves a shadow's properties at a given time.
-- @number t A time, passed as input to each property's curve function.
-- @see Shadow:AddProperty, Shadow:AddMultipleProperties
function Shadow:ResolveProperties (t)
	if self.m_props then
		for k, func in pairs(self.m_props) do
			self[k] = func(t)
		end
	end
end

-- Layer onto which shadows are added --
local DecalsLayer

--- Creates a shadow effect, along with some useful state.
-- @callable func Shadow function, called as
--    result = func(shadow, arg[, true])
-- This function is called on creation (this is when it receives the **true** argument),
-- and on each update; _shadow_ is the shadow object returned by this call.
--
-- If _result_ is ever **"quit"**, the object is removed and the effect cancelled.
--
-- If _result_ was **"report_quit"** on the initial call, then after quitting the call
-- `func("quitting", arg)` is performed, allowing e.g. for external cleanup.
-- @param arg Argument to _func_.
-- @treturn DisplayObject Shadow object. It can be removed to cancel the effect.
function M.Shadow (func, arg)
	local shadow = display.newCircle(DecalsLayer, 0, 0, 1)

	for k, v in pairs(Shadow) do
		shadow[k] = v
	end

	shadow:setFillColor(0, 0, 0)

	local result = func(shadow, arg, true)

	if result == "quit" then
		shadow:removeSelf()
	end

	timers.RepeatEx(function()
		if shadow.parent and func(shadow, arg) == "quit" then
			shadow:removeSelf()
		end

		if not shadow.parent then
			if result == "report_quit" then
				func("quitting", arg)
			end

			return "cancel"
		end
	end, 25)

	return shadow
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		DecalsLayer = level.decals_layer
	end,

	-- Leave Level --
	leave_level = function()
		DecalsLayer = nil
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M