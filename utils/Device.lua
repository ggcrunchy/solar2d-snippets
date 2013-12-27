--- This module wraps up some useful device functionality.

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
local pairs = pairs
local tonumber = tonumber

-- Modules --
local str_utils = require("utils.String")

-- Corona globals --
local system = system

-- Add persistence for configuring?

-- Exports --
local M = {}

-- --
local AxisMappings = {
	OUYA = {
		"left_x", "left_y", "left_trigger", "right_x", "right_y", "right_trigger"
	},
	PS3 = {
		"left_x", "left_y", "right_x", "right_y", [13] = "left_trigger", [14] = "right_trigger"
	}
}

-- --
local Axes

--
local function BindAxisNumbers (device, mapping)
	local axes = {}

	for i, axis in ipairs(device:getAxes()) do
		local amap = mapping[i]

		if amap then
			axes[amap] = i
		end
	end

	Axes[device.descriptor] = axes
end

--
local AddDevice = {}

-- --
local Joysticks

do
	-- --
	local OUYA = "OUYA Game Controller"

	-- --
	local PS3 = "PLAYSTATION(R)3 Controller"

	--
	function AddDevice:joystick (index)
		local name, joy, mapping = self.displayName, { device = self }

		if name:sub(1, #OUYA) == OUYA then
			mapping = Axes.OUYA
		elseif name == PS3 then
			mapping = Axes.PS3
		-- elseif in database, i.e. under `permanentId`... (limit this?)
			--
		end

		--
		if mapping then
			BindAxisNumbers(self, mapping)

			joy.mapping = mapping
		end

		--
		Joysticks[index] = joy
	end
end

-- --
local Keyboards

do
	--
	function AddDevice:keyboard (index)
		-- Do we care about particular keyboards?
			-- possible to omit built-ins?
		-- Load key mappings from database?
		-- Include default...
		Keyboards[index] = { device = self }
	end
end

-- --
local Mice

do
	--
	function AddDevice:mouse (index)
		-- Do we care about particular mice? (maybe just if they have a wheel...)
		-- Load button mappings?
		Mice[index] = { device = self }
	end
end

--- DOCME
function M.EnumerateDevices ()
	Axes, Joysticks, Keyboards, Mice = {}, {}, {}, {}

	for _, device in ipairs(system.getInputDevices()) do
		local func = AddDevice[device.type]

		if func then
			local index = device.descriptor:match("(%d+)$")

			func(device, tonumber(index))
		end
	end
end

--- DOCME
function M.GetAxisMapping (event)
	local axes, number = Axes[event.device.descriptor], event.axis.number

	if axes then
		for id, name in pairs(axes) do
			if id == number then
				return name
			end
		end
	end

	return "none"
end

-- same for button?

-- ouya, nvidia shield, gamestick
if false then
	local function KeyEvent (event)
		local key_name = event.keyName

		if event.phase == "down" then
			-- button mappings...
			-- button* = (A, B, X, Y) (O, A, U, Y = OUYA; X, Circle, Square, Triangle = PS3)
			-- "up", "down", "left", "right",
			-- "buttonSelect", "buttonStart", "buttonMode" (Power on / off)
			-- *shoulderButton? ("left", "right"; 1, 2)
			-- *joystickButton ("left", "right")
			-- "back", "volumeDown", "volumeUp"

			return true
		end

		return false
	end

	Runtime:addEventListener("key", KeyEvent)
end

--[[
	InputDevice:

Properties

object.androidDeviceId (temporary)
object.canVibrate
object.connectionState - "connected", "disconnected" (reserved: "-ing" versions)
object.descriptor
object.displayName
object.isConnected
object.permanentId (preferred, if available)
object.type (one of the following)

"keyboard"
"mouse"
"stylus"
"trackball"
"touchpad"
"touchscreen"
"joystick"
"gamepad"
"directionalPad"
"unknown"



Methods

object:getAxes() - {} of InputAxis
object:vibrate()
]]

--[[
	InputAxis:

object.accuracy (margin of error)
object.descriptor
object.maxValue
object.minValue
object.number
object.type ("unreliable")

min/maxValue:

A joystick typically has a maximum and minimum value range of 1.0 and -1.0 respectively.

A touchscreen's maximum value will usually be the length of the screen in pixels, with a minimum value of zero.

A touchpad's maximum value is typically a large value using an unknown unit of measure, meaning you have to evaluate the relative position of the received axis
data based on the min and max value properties.

number:

The number assigned to an input device's axis. This number is based on the number of axes found on one input device. For example, if an input device has 4 axes,
then they will be assigned numbers 1, 2, 3, and 4 in the order that they were found. You can use this number to uniquely identify an axis belonging to one input device.

This axis number is the only reliable means of identifying an axis belonging to one input device. This is because it is possible for the axis type property to return
duplicate type names, which is especially true if the types are "unknown". Also, because the type names do not always match what was actually pressed on the device, which
is especially true for gamepads and joysticks designed for another platform in mind. If you need to display the axis' name to the end-user, then you should display the axis
number instead of the type name.

This axis number can be used as an index with the array returned by its input device's getAxes() function.

]]

function M.Show ()
    local text = display.newText("WAITING", 0, 0, native.systemFontBold, 35)

    local T = {}
    local function print (a, b, c)
        T[#T+1]=tostring(a) .. "  " .. tostring(b or "") .. "  " .. tostring(c or "")
    end
    
    local function PrintDevice (device, i)
        print( i, "canVibrate", device.canVibrate )
		print( i, "connectionState", device.connectionState )
		print( i, "descriptor", device.descriptor )
		print( i, "displayName", device.displayName )
		print( i, "isConnected", device.isConnected )
		print( i, "type", device.type )
		print( i, "permenantid", tostring(device.permanentId) )
--		print( i, "androidDeviceid", device.androidDeviceId )
	end
	
	for i, device in ipairs(system.getInputDevices()) do
	    PrintDevice(device, i)
	end
	
    local function InputDeviceStatusChanged (event)
	   print(0, "STATUS CHANGE!")
	   PrintDevice(event.device, 0)
	end

	Runtime:addEventListener("inputDeviceStatus", InputDeviceStatusChanged)

    timer.performWithDelay(2500, function()
        if #T == 0 then
            text.text = "NO TEXT"
        else
            text.text = table.remove(T, 1)
        end
        text.x = display.contentCenterX
        text.y = display.contentHeight - 50
    end, 0)
end

-- Export the module.
return M