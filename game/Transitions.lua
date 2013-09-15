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

-- Standard library imports --
local newproxy = newproxy
local pairs = pairs
local remove = table.remove
local setmetatable = setmetatable

-- Modules --
local flow_ops = require("flow_ops")
local frames = require("game.Frames")

-- Corona globals --
local easing = easing
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

-- --
local Transitions = {}

--- DOCME
function M.CancelEx (handle)
	local trans = Transitions[handle]

	if trans then
		trans._cancel = true
	end
end

--
local function NoKeep () return false end

--- DOCME
function M.CancelExAll (keep)
	keep = keep or NoKeep

	for handle, trans in pairs(Transitions) do
		trans._cancel = trans._cancel or not keep(handle)
	end
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

--- DOCME
function M.DoAndWaitEx (name, target, params, update)
	local handle = M.ToEx(target, params)

	if name then
		target[name] = handle
	end

	if not M.WaitForTransitionEx(handle, update) then
		M.CancelEx(handle)
	end

	if name then
		target[name] = nil
	end
end

--- DOCME
function M.IsRunning (handle)
	local trans = Transitions[handle]

	return trans and not trans._cancel
end

do
	-- --
	local MT = {
		__index = function(proxy, _)
			return proxy.m_t
		end,

		__newindex = function(proxy, _, t)
			proxy.m_t = t

			proxy.m_func(t, proxy.m_arg)
		end
	}

	--
	local function OnDone (proxy)
		proxy.m_done(proxy.m_arg)
	end

	-- --
	local Params = {
		t = 1,

		onStart = function(proxy)
			proxy.m_t = 0
		end
	}

	--
	local function AuxProxy (func, options, arg, done)
		local proxy = setmetatable({ m_func = func, m_t = false, m_arg = arg or false, m_done = done or false }, MT)

		if options then
			Params.delay = options.delay
			Params.time = options.time
			Params.transition = options.transition
		end

		local handle = transition.to(proxy, Params)

		Params.delay, Params.time, Params.transition = nil

		return handle
	end

	--- DOCME
	function M.Proxy (func, options, arg)
		Params.onComplete = nil

		return AuxProxy(func, options, arg)
	end

	--- DOCME
	function M.Proxy_Done (func, on_done, options, arg)
		Params.onComplete = OnDone

		return AuxProxy(func, options, arg, on_done)
	end
end

-- Updates the target at a given time
local function UpdateTarget (trans, when)
	local target, duration, tfunc = trans._target, trans._duration, trans.transition or easing.linear

	for i = 1, trans._n, 3 do
		target[trans[i]] = tfunc(when, duration, trans[i + 1], trans[i + 2])
	end
end

-- --
local Cache = {}

-- --
local IdleFrames = -1

--
local Update = {}

function Update:enterFrame ()
	local now, updated = frames.GetFrameTime()

	--
	for handle, trans in pairs(Transitions) do
		local when = now - trans._timeStart

		--
		local target = trans._target
		local cancel = trans._cancel or (trans._had_parent and not target.parent)

		if not cancel and when >= 0 and trans.onStart then
			trans.onStart(target)

			trans.onStart = nil
		end

		-- Aborted or completed transition: in the latter case, update it for t = 1 and
		-- do any on-complete logic. The transition is not re-added to the list.
		if cancel or when >= trans._duration then
			if not cancel then
				UpdateTarget(trans, trans._duration)

				if trans.onComplete then
					trans.onComplete(target)
				end
			end

			trans.onComplete, trans.onStart, trans._target, trans.transition = nil

			Cache[#Cache + 1] = trans
			Transitions[handle] = nil

		-- Normal case: update the transition at the current time.
		elseif when >= 0 then
			UpdateTarget(trans, when)
		end

		--
		updated = true
	end

	--
	IdleFrames = updated and 0 or IdleFrames + 1

	if IdleFrames == 4 then
		IdleFrames = -1

		Runtime:removeEventListener("enterFrame", self)
	end
end

--- DOCME
function M.ToEx (target, params)
	--
	local trans, n, delay, delta, time = remove(Cache) or {}, 0, 0, params.delta

	for k, v in pairs(params) do
		if k == "time" then
			time = v
		elseif k == "delay" then
			delay = v
		elseif k == "onComplete" or k == "onStart" or k == "transition" then
			trans[k] = v
		elseif k ~= "delta" then
			local v0 = target[k]

			trans[n + 1] = k
			trans[n + 2] = v0
			trans[n + 3] = delta and v or v - v0

			n = n + 3
		end
	end

	--
	trans._cancel = false
	trans._duration = time or 500
	trans._had_parent = target.parent ~= nil
	trans._n = n
	trans._target = target
	trans._timeStart = delay + frames.GetFrameTime()

	--
	if IdleFrames < 0 then
		IdleFrames = 0

		Runtime:addEventListener("enterFrame", Update)
	end

	--
	local handle = newproxy()

	Transitions[handle] = trans

	return handle
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

--- DOCME
function M.WaitForTransitionEx (handle, update)
	local trans = Transitions[handle]

	return trans ~= nil and M.WaitForTransition(trans, update)
end

-- Export the module.
return M