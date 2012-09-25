--- Some useful transition utilities.

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

-- Modules --
local flow_ops = require("flow_ops")
local frames = require("game.Frames")

-- Corona globals --
local transition = transition

-- Exports --
local M = {}

--- Looks for a named transition, and if found cancels it and clears its key.
-- @param target Object; presumably, the target of the transition.
-- @param name Key under which transition may be found, in _target_.
-- @treturn boolean Was the transition found in _target_?
function M.Cancel (target, name)
	local handle = target[name]

	if handle then
		transition.cancel(handle)

		target[name] = nil
	end

	return handle ~= nil
end

--- Kicks off a transition and waits until it has finished.
--
-- This must be called within a coroutine.
-- @param name Optional name for the transition, for use by @{Cancel}.
-- @param target Object to transition.
-- @ptable params Transition parameters, as per `transition.to`.
-- @callable update Optional update routine, cf. @{flow_ops.WaitWhile}.
function M.DoAndWait (name, target, params, update)
	local handle = transition.to(target, params)

	if name then
		target[name] = handle
	end

	if not M.WaitForTransition(handle, update) then
		transition.cancel(handle)
	end

	if name then
		target[name] = nil
	end
end

-- Helper to report to flow operation when a transition has completed
-- TODO: Clearly this is a hack...
local function DoingTransition (handle)
	return not handle._cancel and frames.GetFrameTime() - handle._timeStart < handle._duration
end

--- Waits for a transition to finish.
--
-- This must be called within a coroutine.
-- @tparam TransitionHandle handle As returned by the `transition` functions.
-- @callable update Optional update routine, cf. @{flow_ops.WaitWhile}.
-- @treturn boolean Did the transition finish?
function M.WaitForTransition (handle, update)
	return flow_ops.WaitWhile(DoingTransition, update, handle)
end

-- Export the module.
return M