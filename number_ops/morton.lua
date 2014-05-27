--- Some Morton number utilities.

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
local operators = require("bitwise_ops.operators")

-- Imports --
local band = operators.band
local bor = operators.bor
local lshift = operators.lshift
local rshift = operators.rshift

-- Exports --
local M = {}

--
local function AuxPair (mnum)
	-- STUFF
end

--- DOCME
function M.MortonPair (mnum)
	-- TODO!
end

-- Helper to extract a component from a Morton triple
-- The shift and mask constants are those same ones used in AuxMorton, but in reverse order
local function AuxTriple (mnum)
	mnum = band(0x24924924, mnum)
	mnum = band(0x2190C321, bor(mnum, rshift(mnum, 2)))
	mnum = band(0x03818703, bor(mnum, rshift(mnum, 4)))
	mnum = band(0x000F801F, bor(mnum, rshift(mnum, 6)))
	mnum = band(0x000003FF, bor(mnum, rshift(mnum, 10))) -- 0x3FF = 1023, i.e. mask of low 10 bits

	return mnum
end

--- Decomposes a Morton number into its three parts.
-- @uint mnum 30-bit Morton number.
-- @treturn uint 10-bit number (i.e. &isin; [0, 1023]) from bits 2, 5, etc.
-- @treturn uint ...from bits 1, 4, etc.
-- @treturn uint ...and from bits 0, 3, etc.
-- @see Morton3
function M.MortonTriple (mnum)
	return AuxTriple(lshift(mnum, 2)), AuxTriple(lshift(mnum, 1)), AuxTriple(mnum)
end

--
local function AuxMorton2 (x)
	-- STUFF
end

--- DOCME
function M.Morton2 (x, y)
	-- TODO!
end

-- Helper to prepare a component for a Morton triple
-- The right-hand side comments show how the shifts and masks spread a given 10-bit number across 30 bits 
local function AuxMorton3 (x)
	x = band(0x000F801F, bor(x, lshift(x, 10))) -- 000 000 000 011 111 000 000 000 011 111
	x = band(0x03818703, bor(x, lshift(x, 6)))  -- 000 011 100 000 011 000 011 100 000 011
	x = band(0x2190C321, bor(x, lshift(x, 4)))  -- 100 001 100 100 001 100 001 100 100 001
	x = band(0x24924924, bor(x, lshift(x, 2)))  -- 100 100 100 100 100 100 100 100 100 100

	return x
end

--- Builds a Morton number out of three parts.
-- @uint x 10-bit number (i.e. &isin; [0, 1023]), which will be spread across bits 2, 5, etc.
-- @uint y ...across bits 1, 4, etc.
-- @uint z ...and across bits 0, 3, etc.
-- @treturn uint 30-bit Morton number.
-- @see MortonTriple
function M.Morton3 (x, y, z)
	return rshift(AuxMorton3(x), 2) + rshift(AuxMorton3(y), 1) + AuxMorton3(z)
end

-- Export the module.
return M