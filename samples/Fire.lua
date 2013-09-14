--- Fire demo.

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

	local NCols = 60

	local Stash = display.newGroup()

	--Stash.isVisible = false

	local Cols, Swap = {}, {}

	for _ = 1, NCols do
	--	for _ = 1, 10 do
			local fire = display.newRect(Stash, 0, 0, 5, 20)
	--	end

		Cols[#Cols + 1], Swap[#Swap + 1] = { h = 0 }, {}
	end

	timer.performWithDelay(90, function()
		for j = 1, math.random(1, 2) do
			local i = math.random(NCols)

			Cols[i].h = math.min(Cols[i].h + 200, 300)
		end
	end, 0)

	timer.performWithDelay(15, function()
		for i = 1, NCols do
			if i == 1 then
				Swap[i].h = .9 * Cols[i + 1].h
			elseif i == NCols then
				Swap[i].h = .9 * Cols[i - 1].h
			else
				Swap[i].h = .5 * (Cols[i - 1].h + Cols[i + 1].h)
			end

			local fire = Stash[i]

			fire.x = display.contentWidth / NCols * i
			fire.y = display.contentHeight - Swap[i].h / 2
			fire.width = display.contentWidth / NCols
			fire.height = Swap[i].h

			fire:setFillColor(255, 0, 0)
		end

		Cols, Swap = Swap, Cols
	end, 0)