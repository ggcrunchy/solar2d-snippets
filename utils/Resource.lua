--- This module wraps up some useful resource functionality.

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

-- Corona globals --
local system = system
local timer = timer

-- Exports --
local M = {}

-- List of ephemeral resources --
local Res

-- Resource timer period --
local Period = 5000

-- Default timeout: survive one timeout, and probably a second --
local Timeout = math.floor(1.8 * Period)

--- Mechanism to manage user-defined resources that should loaded on demand and unloaded
-- if unused for some period of time. A typical example would be something that consumed
-- a lot of memory but was used only sporadically.
-- @callable load Called (without arguments) during a refresh, if the resource has been
-- unloaded (or was never loaded in the first place). Generally, this should create (or
-- restore) the state that constitutes the resource.
-- @callable unload Called (without arguments) if cleanup occurs while the resource is
-- stale. Generally, this should clean up at least the on-demand portion of the state.
-- Furthermore, it should be safe to call _load_ again after this call.
-- @uint[opt] timeout How many milliseconds the resource can go idle without being removed.
--
-- If absent, some reasonable default is used.
--
-- **N.B.** The cleanup is not immediate, so this is only a lower bound. In the meantime,
-- a stale resource will behave like any other if refreshed.
-- @treturn function Called (without arguments) to refresh the resource, i.e. the resource
-- can go at least _timeout_ milliseconds longer before being unloaded. The resource will
-- be loaded, if necessary.
function M.EphemeralResource (load, unload, timeout)
	local probation = 0

	timeout = timeout or Timeout

	-- Unload the resource if it went stale
	local function CheckProbation ()
		probation = probation - Period

		if probation <= 0 then
			unload()

			return true
		end
	end

	-- Provide the refresh routine.
	return function()
		if probation <= 0 then
			-- No resources yet: make the list and the timer.
			if not Res then
				Res = {}

				timer.performWithDelay(Period, function(event)
					-- Unload any timed-out resources, back-filling over them.
					local n = #Res

					for i = n, 1, -1 do
						if Res[i]() then
							Res[i] = Res[n]
							Res[n] = nil

							n = n - 1
						end
					end

					-- List empty: remove it and the timer itself.
					if n == 0 then
						timer.cancel(event.source)

						Res = nil
					end
				end, 0)
			end

			-- Load the resource. If that went all right, add its cleanup logic.
			load()

			Res[#Res + 1] = CheckProbation
		end

		-- Resource still in use: reset the probation period.
		probation = system.getTimer() + timeout
	end
end

-- Export the module.
return M