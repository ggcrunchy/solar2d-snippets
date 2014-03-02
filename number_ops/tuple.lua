--- Operations on tuples of numbers.

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
local type = type

-- Exports --
local M = {}

--- DOCME
function M.PairMethods_NewGet (base_new, k1, k2, get2)
	return function(a, b, arg)
		local pair = base_new(arg)

		pair[k1], pair[k2] = a, b

		return pair
	end, function(func, pair)
		return func(pair[k1], pair[k2])
	end, get2 and function(pair)
		if type(pair) == "number" then
			return pair, 0
		else
			return pair[k1], pair[k2]
		end
	end
end

--- DOCME
function M.PairMethods_Unary (new, call)
	return function(func)
		return function(pair)
			return new(call(func, pair))
		end
	end, function(func)
		return function(pair)
			return call(func, pair)
		end
	end
end

--- DOCME
function M.PairMethods_Binary (new, get)
	return function(func)
		return function(pair1, pair2)
			local a, b = get(pair1)

			return new(func(a, b, get(pair2)))
		end
	end, function(func)
		return function(pair1, pair2)
			local a, b = get(pair1)

			return func(a, b, get(pair2))
		end
	end
end

-- Export the module.
return M