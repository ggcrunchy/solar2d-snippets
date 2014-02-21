--- Some Gray code utilities.

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
local bxor = operators.bxor
local rshift = operators.rshift

-- Cached module references --
local _BinaryToGray_
local _GrayToBinary_

-- Exports --
local M = {}

--- DOCME
function M.BinaryToGray (n)
	return bxor(rshift(n, 1), n)
end

--
local function AuxFirstN (n, gray)
	if gray then
		local index = _GrayToBinary_(gray)

		if index < n then
			return _BinaryToGray_(index + 1)
		end
	else
		return 0
	end
end

--- DOCME
function M.FirstN (n)
	return AuxFirstN, (n or 2^32) - 1, false
end

--- DOCME
function M.GrayToBinary (gray)
	gray = bxor(gray, rshift(gray, 16))
	gray = bxor(gray, rshift(gray, 8))
	gray = bxor(gray, rshift(gray, 4))
	gray = bxor(gray, rshift(gray, 2))

	return bxor(gray, rshift(gray, 1))
end

-- Cache module members.
_BinaryToGray_ = M.BinaryToGray
_GrayToBinary_ = M.GrayToBinary

-- Export the module.
return M