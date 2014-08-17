--- Ticker demo.

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
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs

-- Corona globals --
local display = display
local native = native
local network = network
local timer = timer

-- Corona modules --
local json = require("json")
local composer = require("composer")

-- Ticker demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

-- --
local LastTime = {}

-- --
local Cur, Max, Min = {}, {}, {}

--
local function MakeListener (what)
	local a, b = (what):match("(%a+)_(%a+)")
	local str = b:upper() .. " per " .. a:upper() .. ": %f"

	return function(event)
		if event.isError then
			-- ??
		else
			local ticker = json.decode(event.response).ticker

			if ticker.server_time > LastTime[what] then
				Cur[what] = str:format(ticker.avg)
				Max[what] = max(Max[what], ticker.high)
				Min[what] = min(Min[what], ticker.low)

				-- STUFF = { avg, buy, sell, last, low, high, vol, vol_cur }

				LastTime[what] = ticker.server_time
			end
		end
	end
end

--
local Tickers = {}

for _, what in ipairs{ "btc_usd", "ltc_btc", "ltc_usd", "btc_eur", "btc_rur" } do
	LastTime[what] = false

	--
	Tickers[#Tickers + 1] = {
		listener = MakeListener(what),
		url = "https://btc-e.com/api/2/" .. what .. "/ticker"
	}
end

--
function Scene:show (event)
	if event.phase == "did" then
		self.str = display.newText(self.view, "", 150, 100, native.systemFontBold, 30)
		self.update_ticker = timer.performWithDelay(300, function()
			--
			for _, ticker in ipairs(Tickers) do
				network.request(ticker.url, "GET", ticker.listener)
			end

			--
			self.str.text = Cur.btc_usd

			-- Plot!
			-- ...
		end, 0)

		--
		for what in pairs(LastTime) do
			Cur[what], LastTime[what], Max[what], Min[what] = "", -1, -1, 0
		end
	end
end

Scene:addEventListener("show")

--[=[
	print("address", event.address )
	print("isReachable", event.isReachable )
	print("isConnectionRequired", event.isConnectionRequired)
	print("isConnectionOnDemand", event.isConnectionOnDemand)
	print("IsInteractionRequired", event.isInteractionRequired)
	print("IsReachableViaCellular", event.isReachableViaCellular)
	print("IsReachableViaWiFi", event.isReachableViaWiFi)
]=]
--
function Scene:hide (event)
	if event.phase == "did" then
		timer.cancel(self.update_ticker)

		--
		for what in pairs(LastTime) do
			LastTime[what] = 0 / 0
		end
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "(DEPRECATED?) This demo was meant to interact with a REST API to show a cryptocurrency ticker."


return Scene