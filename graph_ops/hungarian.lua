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
local min = math.min

-- Modules --
local labels = require("graph_ops.labels")

-- Exports --
local M = {}

-- --
local Costs = {}

-- --
local Mark = {}
local oc=os.clock
local A1, A2
-- Finds the smallest element in each row and subtracts it from every row element
local function SubtractSmallestRowCosts (from, n, ncols, dcols)
A1=oc()
	for ri = 1, n, ncols do
		local rmin = from[ri]

		for i = 1, dcols do
			rmin = min(rmin, from[ri + i])
		end

		for i = ri, ri + dcols do
			Costs[i], Mark[i] = from[i] - rmin, 0
		end
	end
A2=oc()
end

-- --
local Column, Row = {}, {}

-- --
local Covered = 0

-- --
local Star = 1

-- --
local ColStar = {}

local CovColumn = {}
local CovRow = {}

local UncovColumn = {}
local UncovRow = {}

local NCovC, NUncovC
local NCovR, NUncovR

--
local function ClearCoverage (ncols, nrows)
	NCovC, NUncovC = 0, ncols
	NCovR, NUncovR = 0, nrows

	for i = 1, ncols do
		UncovColumn[i] = i - 1
		Column[i] = i
	end

	local ri = 1

	for i = 1, nrows do
		UncovRow[i] = ri
		Row[i] = i

		ri = ri + ncols
	end
end

-- --
local RowStar = {}
local B1,B2
-- Stars the first zero found in each uncovered row or column
local function StarSomeZeroes (n, ncols, dcols)
B1=oc()
	for ri = 1, n, ncols do
RowStar[ri] = ncols
		for i = 0, dcols do
			if Costs[ri + i] == 0 and Column[i + 1] ~= Covered then
				Mark[ri + i], Column[i + 1] = Star, Covered
ColStar[i + 1], RowStar[ri] = ri, i
				break
			end
		end
	end

for i = 1, ncols do
	if Column[i] ~= Covered then
		ColStar[i] = n + 1
	end
end
--vdump(RowStar)
--vdump(ColStar)
	-- Clear covers.
--	Covered = Covered + 1
B2=oc()
end

-- Counts how many columns contain a starred zero
local function CountCoverage (out, n, ncols, dcols)
---[=[
	local row, ncovered = 1, 0
local cov={}
	for ri = 1, n, ncols do
		local col = RowStar[ri]

		if col < ncols then
			if cov[col+1]--[[Column[col + 1] ]] ~= Covered then
				ncovered = ncovered + 1
			end
--- ^^^ Check necessary?
			--[[Column[col + 1] ]]cov[col+1], out[row] = Covered, col + 1
		end
--[==[
		for i = RowStar[ri]--[[0]], dcols do
			if Mark[ri + i] == Star then
				Column[i + 1], out[row] = Covered, i + 1
			end
		end
--]==]
		row = row + 1
	end
	-- ^^ TODO: Can invert
--]=]
--	local ncovered = 0
--[[
	for i = 1, ncols do
		if Column[i] == Covered then
			ncovered = ncovered + 1
		end
	end
--]]
--[[
	for i = 1, ncols do
		if ColStar[i] <= n then
			ncovered = ncovered + 1
		end
	end
--]]
	return ncovered
end

--
local function FindStarInRow (ri, ncols)
	for i = 1, ncols do
		if Mark[ri + i] == Star then
			return i
		end
	end
end
local FZ,FZN=0,0
--
local function FindZero (ncols, n)
local fz=oc()
	for i = 1, NUncovR do
		local ri = UncovRow[i]

		for j = 1, NUncovC do
			local col = UncovColumn[j]

			if Costs[ri + col] == 0 then
				return (ri - 1) / ncols + 1, col + 1, ri - 1
			end
		end
	end
--[[
	local row, dcols = 1, ncols - 1

	for ri = 1, n, ncols do
		if Row[row] ~= Covered then
			for i = 0, dcols do
				if Costs[ri + i] == 0 and Column[i + 1] ~= Covered then
					return row, i + 1, ri - 1
				end
			end
		end

		row = row + 1
	end
]]
FZ=FZ+oc()-fz
FZN=FZN+1
end
local PZ,PZN=0,0
-- --
local Prime = 2
local PP = {}
-- Prime some uncovered zeroes
local function PrimeZeroes (n, ncols)
local pz=oc()
--print("PZ")
	repeat
		local row, col, ri = FindZero(ncols, n)

		if row then
--			Mark[ri + col] = Prime
PP[ri]=col
		--	local scol = FindStarInRow(ri, ncols)
--local scol_true = FindStarInRow(ri, ncols)
local scol = RowStar[ri + 1]
--[[
if scol_true then
	print("scol TRUE", scol_true == scol + 1)
else
	print("scol FALSE", scol == ncols)
end
]]
			if scol--[[ ]] < ncols then
--				Row[row], Column[scol--[[ ]] + 1] = Covered, false
local rindex, cindex = Row[row], Column[scol + 1]

if rindex > 0 then
	local at, rtop = NCovR + 1, UncovRow[NUncovR]
	local top = (rtop - 1) / ncols + 1

	CovRow[at] = UncovRow[rindex]
	UncovRow[rindex] = rtop
	Row[row] = -at
	Row[top] = -rindex

	NUncovR, NCovR = NUncovR - 1, at
end

if cindex < 0 then
	local at, ctop = NUncovC + 1, CovColumn[NCovC]
	local col = -cindex

	UncovColumn[at] = CovColumn[col]
	CovColumn[col] = ctop
	Column[scol + 1] = at
	Column[ctop + 1] = col

	NCovC, NUncovC = NCovC - 1, at
end

			else
				return ri, col
			end
		end
	until not row
PZ=PZ+oc()-pz
PZN=PZN+1
end

--
local function FindStarInCol (col, ncols, nrows)
	local ri = col

	for _ = 1, nrows do
		if Mark[ri] == Star then
			return ri - col
		end

		ri = ri + ncols
	end
end
local BP,BPN=0,0
local RC,RCN=0,0
local AP,APN=0,0
--
local function BuildPath (prow0, pcol0, path, n, ncols, nrows)
local bp=oc()
	-- Construct a series of alternating primed and starred zeros as follows, given uncovered
	-- primed zero Z0 produced in the previous step. Let Z1 denote the starred zero in the
	-- column of Z0 (if any), Z2 the primed zero in the row of Z1 (there will always be one).
	-- Continue until the series terminates at a primed zero that has no starred zero in its
	-- column. Unstar each starred zero of the series, star each primed zero of the series,
	-- erase all primes and uncover every line in the matrix.
	path[1], path[2] = prow0, pcol0
--print("RC", path[1], path[2])
	local count = 2
--[=[
local j = 0
if not AA then
		local ri_true = FindStarInCol(path[count], ncols, nrows)
local ri = ColStar[path[count]]

		if ri_true then
			print("ri TRUE", ri_true == ri - 1)
		else
			print("ri FALSE", ri, n, ri > n)
	end
end
]=]
	repeat
--j=j+1
	--	local ri = FindStarInCol(path[count], ncols, nrows)
--	local ri_true = FindStarInCol(path[count], ncols, nrows)
local ri = ColStar[path[count]]
--[[
if BB then
		if ri_true then
			print("ri TRUE", ri_true == ri - 1)
		else
			print("ri FALSE", ri, n, ri > n)
	end
end

--print(j, ri)
if not ri then
--	print("?", j, path[count], count)
end
]]
if not ri then
	print(count, path[count])
	vdump(ColStar)
	vdump(path)
	vdump(PP)
else
	print("!", ri)
end
local ok = ri <= n

		if ok then--ri then
			ri=ri-1
			path[count + 1] = ri
			path[count + 2] = path[count]
			path[count + 3] = ri
local i=0
--[[
			for i = 1, ncols do
				if Mark[ri + i] == Prime then
					path[count + 4] = i

					break
				end
			end
]]
--[[
			repeat
				i = i + 1
			until Mark[ri+i]==Prime
				]]
				print("ACCESS",ri)
				path[count+4]=PP[ri]--i
			count = count + 4
		end
	until not ok --ri
--AA=true
local ap=oc()
	-- Augment path.
	for i = 1, count, 2 do
		local ri, col = path[i], path[i + 1]

	--	Mark[ri + col] = Mark[ri + col] ~= Star and Star
local index, colp1 = ri + col, col

ri, col = ri + 1, col - 1

if Mark[index] == Star then
local rc=oc()
	if col == RowStar[ri] then
		local c=col
		repeat
			c=c+1--col = col + 1
		until c--[[col]] == ncols or Mark[ri + c--[[col]] ] == Star

		RowStar[ri] = c--col
	end

	if ri == ColStar[colp1] then
		repeat
			ri = ri + ncols
		until ri > n or Mark[ri + col] == Star

		ColStar[colp1] = ri
	end

	Mark[index] = false
RC=RC+oc()-rc
RCN=RCN+1
else
--	print(ri, col, colp1)
	if col < RowStar[ri] then
		RowStar[ri] = col
	end

	if ri < ColStar[colp1] then
		ColStar[colp1] = ri
	end

	Mark[index] = Star
end
	end
AP=AP+oc()-ap
APN=APN+1
	-- Clear covers and erase primes.
--	Covered, Prime = Covered + 1, Prime + 1
	ClearCoverage(ncols, nrows)
BP=BP+oc()-bp
BPN=BPN+1
end
local UC,UCN=0,0
-- Updates the cost matrix to reflect the new minimum
local function UpdateCosts (n, ncols, dcols)
local uc=oc()
	-- Find the smallest uncovered value.
	local vmin, row = 1 / 0, 1
--[[
	for ri = 1, n, ncols do
		if Row[row] ~= Covered then
			for i = 0, dcols do
				if Column[i + 1] ~= Covered then
					vmin = min(vmin, Costs[ri + i])
				end
			end
		end

		row = row + 1
	end
]]
	for i = 1, NUncovR do
		local ri = UncovRow[i]

		for j = 1, NUncovC do
			vmin = min(vmin, Costs[ri + UncovColumn[j]])
		end
	end

	-- Add the value to every element of each covered row, subtracting it from every element
	-- of each uncovered column.
	row = 1
--[[
	for ri = 1, n, ncols do
		local radd = Row[row] == Covered and vmin or 0

		for i = 0, dcols do
			local add = radd + (Column[i + 1] == Covered and 0 or -vmin)

			if add ~= 0 then
				Costs[ri + i] = Costs[ri + i] + add
			end
		end

		row = row + 1
	end
]]
	for i = 1, NCovR do
		local ri = CovRow[i]

		for j = 1, NCovC do
			local index = ri + CovColumn[j]

			Costs[index] = Costs[index] + vmin
		end
	end


	for i = 1, NUncovR do
		local ri = UncovRow[i]

		for j = 1, NUncovC do
			local index = ri + UncovColumn[j]

			Costs[index] = Costs[index] - vmin
		end
	end

UC=UC+oc()-uc
UCN=UCN+1
end
local LP,LPN=0,0
--- DOCME
-- @array costs
-- @uint ncols
-- @ptable[opt] out
-- @treturn array out
function M.Run (costs, ncols, out)
	out = out or {}
local t0=oc()
	local n, from = #costs, costs
	local dcols, nrows = ncols - 1, ceil(n / ncols)

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
	SubtractSmallestRowCosts(from, n, ncols, dcols)
	StarSomeZeroes(n, ncols, dcols)
ClearCoverage(ncols, nrows)
	--
	local check_solution, path = true

	while true do
local lp=oc()
		-- Check if the starred zeroes describe a complete set of unique assignments.
		if check_solution then
			local ncovered = CountCoverage(out, n, ncols, dcols)

			if ncovered >= ncols or ncovered >= nrows then
				if from == Costs then
					-- Inverted, do something...
				end
--Covered=Covered+1
LP=LP+oc()-lp
LPN=LPN+1
print("Sub smallest row costs", A2 - A1)
print("Star some zeroes", B2 - B1)
print("Loop", LP / LPN, LP)
print("  Prime zeroes", PZ / PZN, PZ)
print("    Find zero", FZ / FZN, FZ)
print("  Build path", BP / BPN, BP)
print("    Augment path", AP / APN, AP)
print("      Recompute", RC / RCN, RC)
print("  Update costs", UC / UCN, UC)
print("TOTAL", oc()-t0)
				return out
			else
				check_solution = false
			end
		end

		-- Find a noncovered zero and prime it.
		local prow0, pcol0 = PrimeZeroes(n, ncols)

		-- If there was no starred zero in the row containing the primed zero, try to build up a
		-- solution. On the next pass, check if this has produced a valid assignment.
		if prow0 then
			path, check_solution = path or {}, true

			BuildPath(prow0, pcol0, path, n, ncols, nrows)

		-- Otherwise, no uncovered zeroes remain. Update the matrix and do another pass, without
        -- altering any stars, primes, or covered lines.
		else
			UpdateCosts(n, ncols, dcols)
		end
LP=LP+oc()-lp
LPN=LPN+1
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