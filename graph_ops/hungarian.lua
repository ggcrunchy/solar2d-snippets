--- An implementation of the [Hungarian algorithm](http://en.wikipedia.org/wiki/Hungarian_algorithm).
--
-- Adapted from [here](http://csclab.murraystate.edu/bob.pilgrim/445/munkres.html).

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
local ceil = math.ceil
local huge = math.huge
local min = math.min
local pairs = pairs

-- Modules --
local labels = require("graph_ops.labels")
local log2 = require("bitwise_ops.log2")
local operators = require("bitwise_ops.operators")
local powers_of_2 = require("bitwise_ops.powers_of_2")

-- Imports --
local Lg_PowerOf2 = log2.Lg_PowerOf2

-- Forward declarations --
local ClearCoverage
local CoverColumn
local CoverRow
local FindZero
local GetCount
local UncoverColumn
local UpdateCosts

-- Exports --
local M = {}

--+++++++++++++++
local oc=os.clock
local AU,AUN=0,0
--+++++++++++++++

-- --
local Costs = {}

-- --
local Zeroes = {}

--
if operators.HasBitLib() then
	local band = operators.band
	local bnot = operators.bnot
	local bor = operators.bor
	local bxor = operators.bxor
	local lshift = operators.lshift
	local rshift = operators.rshift

	-- --
	local FreeCols, MaskCols = {}, {}
	local FreeRows, MaskRows = {}, {}

	-- --
	local ColN, RowN

	--
	function ClearCoverage (ncols, nrows, is_first)
		--
		if is_first then
			--
			ColN = rshift(powers_of_2.CLP2(ncols), 5)

			for i = 1, ColN do
				if i < ColN then
					MaskCols[i] = 0xFFFFFFFF
				else
					MaskCols[i] = lshift(1, ncols) - 1
				end
			end

			--
			RowN = rshift(powers_of_2.CLP2(nrows), 5)

			for i = 1, RowN do
				if i < RowN then
					MaskRows[i] = 0xFFFFFFFF
				else
					MaskRows[i] = lshift(1, nrows) - 1
				end
			end
		end

		--
		for i = 1, RowN do
			FreeCols[i] = MaskCols[i]
			FreeRows[i] = MaskRows[i]
		end

		for i = RowN + 1, ColN do
			FreeCols[i] = MaskCols[i]
		end
	end

	--
	local function AuxCover (i)
		return rshift(i, 5) + 1, lshift(1, i)
	end

	--
	function CoverColumn (col)
		local index, bit = AuxCover(col)

		FreeCols[index] = band(FreeCols[index], bnot(bit))
	end

	--
	function CoverRow (row)
		local index, bit = AuxCover(row)
		local old = FreeRows[index]
		local new = band(old, bnot(bit))

		FreeRows[index] = new

		return old ~= new
	end

	--
	local function AuxPowers (offset, bits)
		if bits ~= 0 then
			local bit = band(bits, -bits)

			return bxor(bits, bit), (bit > 0 and Lg_PowerOf2(bit) or 0x1F) + offset
		end
	end

	--
	local function Powers (bits, offset)
		return AuxPowers, offset, bits
	end

	--
	function FindZero (ncols)
		local roff, vmin = 0, huge

		for i = 1, RowN do
			for _, rpos in Powers(FreeRows[i], roff) do
				local coff, ri = 0, rpos * ncols + 1

				for j = 1, ColN do
					for _, col in Powers(FreeCols[j], coff) do
						local cost = Costs[ri + col]

						if cost < vmin then
							if cost == 0 then
								return ri, col
							else
								vmin = cost
							end
						end
					end

					coff = coff + 32
				end
			end

			roff = roff + 32
		end
print("NUTS")
		return vmin
	end

	--
	function GetCount (ncols)
		local bits = 0

		for i = 1, ColN do
			bits = bor(FreeCols[i], bits)
		end

		return bits == 0 and ncols or 0
	end

	--
	function UncoverColumn (col)
		local index, bit = AuxCover(col)

		FreeCols[index] = bor(FreeCols[index], bit)
	end

	--
	function UpdateCosts (vmin, ncols)
		local roff = 0
print("UPDATING")
		for i = 1, RowN do
			local rbits = band(bnot(FreeRows[i]), MaskRows[i])

			for _, rpos in Powers(rbits, roff) do
				local coff = rpos * ncols + 1

				for j = 1, ColN do
					local cbits = band(bnot(FreeCols[j]), MaskCols[j])

					for _, index in Powers(cbits, coff) do
						Costs[index] = Costs[index] + vmin
					end

					coff = coff + 32
				end
			end

			roff = roff + 32
		end
print("ONE")
		roff = 0

		for i = 1, RowN do
			for _, rpos in Powers(FreeRows[i], roff) do
				local coff, ri = 0, rpos * ncols + 1

				for j = 1, ColN do
					for _, col in Powers(FreeCols[j], coff) do
						local index = ri + col
						local cost = Costs[index] - vmin

						Costs[index] = cost

						if cost == 0 then
							local zn = Zeroes.n

							Zeroes[zn + 1], Zeroes[zn + 2], Zeroes.n = ri, col, zn + 2
						end
					end

					coff = coff + 32
				end
			end

			roff = roff + 32
		end
print("TWO")
	end

-- 
else
	-- --
	local Column, Row = {}, {}

	-- --
	local CovCol, UncovCol = {}, {}
	local CovRow, UncovRow = {}, {}

	--
	function ClearCoverage (ncols, nrows)
		CovCol.n, UncovCol.n = 0, ncols
		CovRow.n, UncovRow.n = 0, nrows

		--
		local ri = 1

		for i = 1, nrows do
			UncovCol[i], Column[i] = i - 1, i
			UncovRow[i], Row[i], ri = ri, i, ri + ncols
		end

		--
		for i = nrows + 1, ncols do
			UncovCol[i], Column[i] = i - 1, i
		end
	end

	--
	function CoverColumn (col)
		local cindex = Column[col + 1]

		if cindex > 0 then
			local nucols = UncovCol.n
			local at, top = CovCol.n + 1, UncovCol[nucols]

			CovCol[at] = UncovCol[cindex]
			UncovCol[cindex] = top
			Column[col + 1] = -at
			Column[top + 1] = cindex

			UncovCol.n, CovCol.n = nucols - 1, at
		end
	end

	--
	function CoverRow (row, ncols)
		local rindex = Row[row + 1]

		if rindex > 0 then
			local nurows = UncovRow.n
			local at, rtop = CovRow.n + 1, UncovRow[nurows]
			local top = (rtop - 1) / ncols

			CovRow[at] = UncovRow[rindex]
			UncovRow[rindex] = rtop
			Row[row + 1] = -at
			Row[top + 1] = rindex

			UncovRow.n, CovRow.n = nurows - 1, at

			return true
		end
	end

	--
	function FindZero ()
		local nuc, vmin = UncovCol.n, huge

		for i = 1, UncovRow.n do
			local ri = UncovRow[i]

			for j = 1, nuc do
				local col = UncovCol[j]
				local cost = Costs[ri + col]

				if cost < vmin then
					if cost == 0 then
						return ri, col
					else
						vmin = cost
					end
				end
			end
		end

		return vmin
	end

	--
	function GetCount ()
		return CovCol.n
	end

	--
	function UncoverColumn (col)
		local cindex = Column[col + 1]

		if cindex < 0 then	
			local nccols = CovCol.n
			local at, top = UncovCol.n + 1, CovCol[nccols]
			local pcol = -cindex

			UncovCol[at] = CovCol[pcol]
			CovCol[pcol] = top
			Column[col + 1] = at
			Column[top + 1] = cindex

			CovCol.n, UncovCol.n = nccols - 1, at
		end
	end

	-- Updates the cost matrix to reflect the new minimum
	function UpdateCosts (vmin)
--+++++++++++
local au=oc()
--+++++++++++

		-- Add the minimum value to every element of each covered row...
		local ncc, nuc = CovCol.n, UncovCol.n

		for i = 1, CovRow.n do
			local ri = CovRow[i]

			for j = 1, ncc do
				local index = ri + CovCol[j]

				Costs[index] = Costs[index] + vmin
			end
		end

		-- ...subtracting it from every element of each uncovered column.
		for i = 1, UncovRow.n do
			local ri = UncovRow[i]

			for j = 1, nuc do
				local col = UncovCol[j]
				local index = ri + col
				local cost = Costs[index] - vmin

				Costs[index] = cost

				if cost == 0 then
					local zn = Zeroes.n

					Zeroes[zn + 1], Zeroes[zn + 2], Zeroes.n = ri, col, zn + 2
				end
			end
		end

--+++++++++++
AU=AU+oc()-au
AUN=AUN+1
--+++++++++++
	end
end

-- Finds the smallest element in each row and subtracts it from every row element
local function SubtractSmallestRowCosts (from, n, ncols)
	local dcols = ncols - 1

	for ri = 1, n, ncols do
		local rmin = from[ri]

		for i = 1, dcols do
			rmin = min(rmin, from[ri + i])
		end

		for i = ri, ri + dcols do
			Costs[i] = from[i] - rmin
		end
	end
end

-- --
local ColStar, RowStar = {}, {}

-- Stars the first zero found in each uncovered row or column
local function StarSomeZeroes (n, ncols)
	--
	local np1 = n + 1

	for i = 1, ncols do
		ColStar[i] = np1
	end

	--
	local dcols = ncols - 1

	for ri = 1, n, ncols do
		RowStar[ri] = ncols

		for i = 0, dcols do
			if Costs[ri + i] == 0 and ColStar[i + 1] == np1 then
				ColStar[i + 1], RowStar[ri] = ri, i

				break
			end
		end
	end
end

-- Counts how many columns contain a starred zero
local function CountCoverage (n, ncols)
	for ri = 1, n, ncols do
		local col = RowStar[ri]

		if col < ncols then
			CoverColumn(col)
		end
	end

	return GetCount(ncols)
end

-- --
local Primes = {}

-- Prime some uncovered zeroes
local function PrimeZeroes (ncols)
	while true do
		--
		local zn, col, ri = Zeroes.n

		if zn > 0 then
			ri, col, Zeroes.n = Zeroes[zn - 1], Zeroes[zn], zn - 2
		else
			ri, col = FindZero(ncols)
		end

		--
		if col then
			Primes[ri] = col

			local scol = RowStar[ri]

			--
			if scol < ncols then
				if CoverRow((ri - 1) / ncols, ncols) then
					-- Evict any remaining zeroes in the row.
					for i = zn, 1, -2 do
						if Zeroes[i - 1] == ri then
							Zeroes[i - 1], Zeroes[i], zn = Zeroes[zn - 1], Zeroes[zn], zn - 2
						end

						Zeroes.n = zn
					end
				end

				UncoverColumn(scol)

			--
			else
				return ri, col
			end

		--
		else
			return false, ri
		end
	end
end

--
local function RemoveStar (n, ri, col, ncols)
	RowStar[ri] = ncols

	if ri == ColStar[col + 1] then
		repeat
			ri = ri + ncols
		until ri > n or RowStar[ri] == col

		ColStar[col + 1] = ri
	end
end

--
local function BuildPath (ri, col, n, ncols, nrows)
	repeat
		local rnext = ColStar[col + 1]

		-- Star the current primed zero (on the first pass, this is the uncovered input).
		RowStar[ri] = col

		if ri < rnext then
			ColStar[col + 1] = ri
		end

		-- If there is one, go to the starred zero in the column of the last primed zero. Unstar
		-- it, then move to the primed zero in the same row.
		ri = rnext

		if ri <= n then
			RemoveStar(n, ri, col, ncols)

			col = Primes[ri]
		end
	until ri > n

	ClearCoverage(ncols, nrows)

	for k in pairs(Primes) do
		Primes[k] = nil
	end
end

--++++++++++++++
local LP,LPN=0,0
local PZ,PZN=0,0
--++++++++++++++

--
local function BuildSolution_Square (out, n, ncols)
	local row = 1

	for ri = 1, n, ncols do
		out[row], row = RowStar[ri] + 1, row + 1
	end
end

--
local function DefYieldFunc () end

--- DOCME
-- @array costs
-- @uint ncols
-- @ptable[opt] opts
-- @treturn array out
function M.Run (costs, ncols, opts)
	local out = (opts and opts.into) or {}
	local yfunc = (opts and opts.yfunc) or DefYieldFunc

--+++++++++++
local lp=oc()
local sum=0
--+++++++++++

	local n, from = #costs, costs
	local nrows = ceil(n / ncols)

	--
	if ncols < nrows then
		local index = 1

		for i = 1, ncols do
			for j = i, n, ncols do
				Costs[index], index = costs[j], index + 1
			end
		end

		ncols, nrows, from = nrows, ncols, Costs
-- TODO: ^^^ Works? (Add resolve below, too...)
	end

	-- Kick off the algorithm with a first round of zeroes, starring as many as possible.
	SubtractSmallestRowCosts(from, n, ncols)
	StarSomeZeroes(n, ncols)
	ClearCoverage(ncols, nrows, true)

	--
	local do_check = true

	Zeroes.n = 0

	while true do
--+++++++++++++
sum=sum+oc()-lp
--+++++++++++++
		yfunc()
--+++++
lp=oc()
--+++++
		-- Check if the starred zeroes describe a complete set of unique assignments.
		if do_check then
			local ncovered = CountCoverage(n, ncols)

			if ncovered >= ncols or ncovered >= nrows then
				if from == Costs then
					-- Inverted, do something...
				end

				--
				if ncols == nrows then
					BuildSolution_Square(out, n, ncols)
				end

--++++++++++++++++++++++++++++++++++++
local left=oc()-lp
LP=LP+left
LPN=LPN+1

print("Loop", LP / LPN, LP)
print("  Prime zeroes", PZ / PZN, PZ)
print("  Actual update", AU / AUN, AU)
print("TOTAL", sum+left)
LP,LPN=0,0
PZ,PZN=0,0
AU,AUN=0,0
--++++++++++++++++++++++++++++++++++++
				return out
			else
				do_check = false
			end
		end
--+++++++++++
local pz=oc()
--+++++++++++
		-- Find a noncovered zero and prime it.
		local prow0, pcol0 = PrimeZeroes(ncols)

		Zeroes.n = 0
--+++++++++++
PZ=PZ+oc()-pz
PZN=PZN+1
--+++++++++++

		-- If there was no starred zero in the row containing the primed zero, try to build up a
		-- solution. On the next pass, check if this has produced a valid assignment.
		if prow0 then
			do_check = true

			BuildPath(prow0, pcol0, n, ncols, nrows)

		-- Otherwise, no uncovered zeroes remain. Update the matrix and do another pass, without
        -- altering any stars, primes, or covered lines.
		else
			UpdateCosts(pcol0, ncols)
		end
--+++++++++++
LP=LP+oc()-lp
LPN=LPN+1
--+++++++++++
	end
end

--- DOCME
-- @ptable t
-- @treturn array out
function M.Run_Labels (t)
	-- Set up the and do Run()
end

-- Export the module.
return M