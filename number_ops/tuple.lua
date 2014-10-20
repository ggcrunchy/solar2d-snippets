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

--- Builds helpers to aggregate pairs and then operate on the same.
-- @callable base_new Called as `item = base_new(arg)` to obtain aggregate data structure,
-- which will typically be a table.
-- @param k1 Key of value #1 in pair...
-- @param k2 ...and key of value #2.
-- @bool second_getter Return the second getter?
-- @treturn function Pair constructor, called as `pair = cons(a, b, arg)`.
--
-- A pair aggregate is obtained via _base\_new_, keys _k1_ and _k2_ are assigned _a_ and _b_,
-- respectively, and the aggregate is returned.
--
-- In particular, this function may be used as the _make_ routine for a cache, as created by
-- @{tektite_core.var.cache.Factory}. In this case, _new_ would be passed in as _base\_new_, and
-- _uncached_ would end up in _arg_.
-- @treturn function Called as `a, b = get(func, pair)`, where _get_ is defined as
-- `return func(pair[k1], pair[k2])`.
-- @treturn ?function Called as `a, b = get2(pair)`. If _pair_ is a number, _get2_ is defined
-- as `return pair, 0`; otherwise, it behaves as `return pair[k1], pair[k2]`.
function M.PairMethods_ConsGet (base_new, k1, k2, second_getter)
	return function(a, b, arg)
		local pair = base_new(arg)

		pair[k1], pair[k2] = a, b

		return pair
	end, function(func, pair)
		return func(pair[k1], pair[k2])
	end, second_getter and function(pair)
		if type(pair) == "number" then
			return pair, 0
		else
			return pair[k1], pair[k2]
		end
	end
end

--- Helper to convert two-argument (one pair) functions into a pair type's unary methods,
-- i.e. functions called as `func(a, b)` become ones called as `Func(pair)` or `pair:Func()`.
--
-- Here, _cons_ and _get_ have the signature and semantics of @{PairMethods_ConsGet}'s first
-- and second return values, respectively (indeed, those will be ideal arguments).
-- @callable cons Aggregate constructor.
-- @callable get Gets the results of calling _func_ on a pair's components.
-- @treturn function Called as `method = wrap1(func)` to wrap a unary function which returns
-- a new instance, e.g. `new_pair = pair:Method()`.
-- @treturn function Called as `method = wrap2(func)` to wrap a unary function which returns
-- arbitrary results, e.g. `result1, ..., resultn = pair:Method()`.
function M.PairMethods_Unary (cons, get)
	return function(func)
		return function(pair)
			return cons(get(func, pair))
		end
	end, function(func)
		return function(pair)
			return get(func, pair)
		end
	end
end

--- Helper to convert four-argument (two pairs) functions into a pair type's binary methods,
-- i.e. functions called as `func(a1, b1, a2, b2)` become ones called as `Func(pair1, pair2)`
-- or `pair1:Func(pair2)`.
--
-- Here, _cons_ and _get_ have the signature and semantics of @{PairMethods_ConsGet}'s first
-- and third return values, respectively (indeed, those will be ideal arguments).
-- @callable cons Aggregate constructor.
-- @callable get Gets the results of calling _func_ on a pair's components.
-- @treturn function Called as `method = wrap1(func)` to wrap a unary function which returns
-- a new instance, e.g. `new_pair = pair1:Method(pair2)`.
-- @treturn function Called as `method = wrap2(func)` to wrap a unary function which returns
-- arbitrary results, e.g. `result1, ..., resultn = pair1:Method(pair2)`.
function M.PairMethods_Binary (cons, get)
	return function(func)
		return function(pair1, pair2)
			local a, b = get(pair1)

			return cons(func(a, b, get(pair2)))
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