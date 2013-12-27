--- Operations to inject into @{VarFamily}'s **"nums"** namespace.
-- @module NumVars

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
local func_ops = require("func_ops")

--
return function(ops, NumVars)
	-- Number variable helpers --
	local Nums, Pair = ops.MakeMeta("nums", func_ops.Zero, true)

	--- Getter.
	-- @param name Number variable name.
	-- @return Value of number, 0 by default.
	-- @see NumVars:SetNumber
	function NumVars:GetNumber (name)
		return Nums(self)[name]
	end

	--- Setter.
	-- @param name Non-**nil** number variable name.
	-- @param value Value to assign.
	-- @see NumVars:GetNumber
	function NumVars:SetNumber (name, value)
		Nums(self)[name] = value
	end

	-- Optional upper-bounding helper
	local function UpperBounded (value, ubound)
		return (ubound and min or func_ops.Identity)(value, ubound)
	end

	--- Gets a number variable and adds to it.
	-- @param name Non-**nil** number variable name.
	-- @param amount Amount to add.
	-- @param ubound If present, sum is clamped to this amount.
	-- @see NumVars:GetNumber, NumVars:SubNumber
	function NumVars:AddNumber (name, amount, ubound)
		local nums = Nums(self)

		nums[name] = UpperBounded(nums[name] + amount, ubound)
	end

	--- Gets a number variable and increments it by 1.
	-- @param name Non-**nil** number variable name.
	-- @param ubound If present, sum is clamped to this amount.
	-- @see NumVars:DecNumber, NumVars:GetNumber
	function NumVars:IncNumber (name, ubound)
		local nums = Nums(self)

		nums[name] = UpperBounded(nums[name] + 1, ubound)
	end

	-- Optional lower-bounding helper
	local function LowerBounded (value, lbound)
		return (lbound and max or func_ops.Identity)(value, lbound)
	end

	--- Gets a number variable and subtracts from it.
	-- @param name Non-**nil** number variable name.
	-- @param amount Amount to subtract.
	-- @param lbound If present, sum is clamped to this amount.
	-- @see NumVars:AddNumber, NumVars:GetNumber
	function NumVars:SubNumber (name, amount, lbound)
		local nums = Nums(self)

		nums[name] = LowerBounded(nums[name] - amount, lbound)
	end

	--- Gets a number variable and decrements it by 1.
	-- @param name Non-**nil** number variable name.
	-- @param lbound If present, sum is clamped to this amount.
	-- @see NumVars:GetNumber, NumVars:IncNumber
	function NumVars:DecNumber (name, lbound)
		local nums = Nums(self)

		nums[name] = LowerBounded(nums[name] - 1, lbound)
	end

	--- Gets a number variable and divides it.
	-- @param name Non-**nil** number variable name.
	-- @param amount Amount by which number is divided.
	-- @see NumVars:GetNumber
	function NumVars:DivNumber (name, amount)
		local nums = Nums(self)

		nums[name] = nums[name] / amount
	end

	--- Gets a number variable and multiplies it.
	-- @param name Non-**nil** number variable name.
	-- @param amount Amount by which number is multiplied.
	-- @see NumVars:GetNumber
	function NumVars:MulNumber (name, amount)
		local nums = Nums(self)

		nums[name] = nums[name] * amount
	end

	--- Gets several number variables and multiplies them together.
	-- @function NumVars:Product_Array
	-- @param array Array of non-**nil** number variable names.
	-- @return Product of all numbers (or 0 if the array is empty). Given a single
	-- number, returns its value.
	-- @see NumVars:GetNumber

	--- Vararg variant of @{NumVars:Product_Array}.
	-- @function NumVars:Product_Varargs
	-- @param ... Non-**nil** number variable names.
	-- @return Product of all numbers (or 0 if the argument list is empty). Given a
	-- single number, returns its value.
	-- @see NumVars:GetNumber

	Pair("Product", function(nums, iter, s, v0)
		local product

		for _, name in iter, s, v0 do
			product = (product or 1) * nums[name]
		end

		return product or 0
	end)

	--- Gets several number variables and sums them together.
	-- @function NumVars:Sum_Array
	-- @param array Array of non-**nil** number variable names.
	-- @return Sum of all numbers (or 0 if the array is empty). Given a single number,
	-- returns its value.
	-- @see NumVars:GetNumber

	--- Vararg variant of @{NumVars:Sum_Array}.
	-- @function NumVars:Sum_Varargs
	-- @param ... Non-<b>nil</b> number variable names.
	-- @return Sum of all numbers (or 0 if the argument list is empty). Given a single
	-- number, returns its value.
	-- @see NumVars:GetNumber

	Pair("Sum", function(nums, iter, s, v0)
		local sum = 0

		for _, name in iter, s, v0 do
			sum = sum + nums[name]
		end

		return sum
	end)
end