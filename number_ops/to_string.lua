--- Some number -> string conversion utilities.

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
local concat = table.concat
local reverse = string.reverse

-- Exports --
local M = {}

-- --
local Acc

--- DOCME
function M.Binary (n, block_size, pad)
	if n == 0 then
		return "0"
	else
		Acc = Acc or {}

		--
		if n < 0 then
			n = n % 2^32
		end

		--
		local bit, pos, size = 1, 0, (block_size or 4) + 1

		repeat
			--
			pos = pos + 1

			if pos % size == 0 then
				Acc[pos], pos = " ", pos + 1
			end

			--
			local char, next = "0", 2 * bit

			if n % next >= bit then
				char, n = "1", n - bit
			end

			Acc[pos], bit = char, next
		until n == 0

		-- If desired, pad the result to the block size.
		if pad then
			while (pos + 1) % size > 0 do
				Acc[pos + 1], pos = "0", pos + 1
			end
		end

		return reverse(concat(Acc, "", 1, pos))
	end
end

-- Export the module.
return M