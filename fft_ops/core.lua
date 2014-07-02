--- Core routines used to build the various FFT modules.

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
local pi = math.pi
local setmetatable = setmetatable
local sin = math.sin

-- Cached module references --
local _Transform_

-- Exports --
local M = {}

-- Helper to build cached cosine / sine wave functions
local function WaveFunc (get, init, flip)
	local cur, ai, bi, da, s1, s2, wt, n

	return function()
		-- A negative index access will populate the corresponding positive index in the wavetable,
		-- together with the next positive index, whereas positive indices will access already-
		-- loaded wavetable values.
		local a = wt[ai]

		ai, bi = ai + da, bi + 2

		return a, wt[bi]
	end, function(id)
		if id ~= cur then
			-- If the ID merely changed sign, perform a flip behavior, if one exists.
			if flip and -id == cur then
				flip(wt, n)
				
			-- Dirty: initialize the state and walk one index in the negative direction.
			else	
				ai, da, n = -1, -2, 0
				s1, s2 = init(id)

				-- On the first preparation, generate a wavetable and bind a metatable to populate it
				-- when its negative keys are accessed.
				if not wt then
					wt, bi = {
						__index  = function(t, k)
							local a, b, ns = get(s1, s2)

							t[-k], t[1 - k], s1, n = a, b, ns, n + 2

							return a
						end
					}, 0

					setmetatable(wt, wt)
				end
			end

			cur = id
		end
	end, function()
		-- Reset the indices, walking both in the positive direction.
		ai, bi, da = 1, 0, 2
	end
end

-- Sines-based pairs method, i.e. sin(theta), 1 - cos(theta)
local GetSines, BeginSines, ResetSines = WaveFunc(function(theta)
	local half = .5 * theta

	return sin(theta), 2.0 * sin(half)^2, half
end, function(n)
	return n < 0 and -pi or pi
end, function(wt, n)
	for i = 1, n, 2 do
		wt[i] = -wt[i]
	end
end)

--- DOCME
-- @function BeginSines
M.BeginSines = BeginSines

-- Scrambles input vector by swapping elements: v[abc...z] <-> v[z...cba] (abc...z is some lg(n)-bit pattern of the respective indices)
-- Adapted from LuaJIT's FFT benchmark:
-- http://luajit.org/download/scimark.lua (also MIT license)
local function BitReverse (v, n, offset)
	local j = 0

	for i = 0, 2 * n - 4, 2 do
		if i < j then
			local io, jo = i + offset, j + offset

			v[io + 1], v[io + 2], v[jo + 1], v[jo + 2] = v[jo + 1], v[jo + 2], v[io + 1], v[io + 2]
		end

		local k = n

		while k <= j do
			j, k = j - k, k / 2
		end

		j = j + k
	end
end

--- DOCME
-- Butterflies: setup and divide-and-conquer (two-point transforms)
-- Adapted from LuaJIT's FFT benchmark:
-- http://luajit.org/download/scimark.lua (also MIT license)
function M.Transform (v, n, offset)
	if n <= 1 then
		return
	end

	BitReverse(v, n, offset)

	local n2, dual, dual2, dual4 = 2 * n, 1, 2, 4

	repeat
		for k = 1, n2 - 1, dual4 do
			local i = offset + k
			local j = i + dual2
			local ir, ii = v[i], v[i + 1]
			local jr, ji = v[j], v[j + 1]

			v[j], v[j + 1] = ir - jr, ii - ji
			v[i], v[i + 1] = ir + jr, ii + ji
		end

		local wr, wi, s1, s2 = 1.0, 0.0, GetSines()

		for a = 3, dual2 - 1, 2 do
			wr, wi = wr - s1 * wi - s2 * wr, wi + s1 * wr - s2 * wi

			for k = a, a + n2 - dual4, dual4 do
				local i = offset + k
				local j = i + dual2
				local jr, ji = v[j], v[j + 1]
				local dr, di = wr * jr - wi * ji, wr * ji + wi * jr
				local ir, ii = v[i], v[i + 1]

				v[j], v[j + 1] = ir - dr, ii - di
				v[i], v[i + 1] = ir + dr, ii + di
			end
		end

		dual, dual2, dual4 = dual2, dual4, 2 * dual4
	until dual >= n

	ResetSines()
end

-- Temporary store, used to transpose columns --
local Column = {}

--- DOCME
-- Helper to do column part of 2D transforms
function M.TransformColumns (m, w2, h, area, last)
	for i = 1, last or w2, 2 do
		local n, ri = 1, i

		repeat
			Column[n], Column[n + 1], n, ri = m[ri], m[ri + 1], n + 2, ri + w2
		until ri > area

		_Transform_(Column, h, 0)

		repeat
			n, ri = n - 2, ri - w2
			m[ri], m[ri + 1] = Column[n], Column[n + 1]
		until ri == i
	end
end

--- DOCME
-- @function WaveFunc
M.WaveFunc = WaveFunc

-- Cache module members.
_Transform_ = M.Transform

-- Export the module.
return M