--- Tree tiles.

local tiles = {
	{ name = "BottomT.png", x = 0, y = 0, width = 64, height = 60 },
	{ name = "FourWays.png", x = 65, y = 0, width = 64, height = 64 },
	{ name = "Horizontal.png", x = 130, y = 0, width = 64, height = 40, sourceY = 13 },
	{ name = "LeftT.png", x = 195, y = 0, width = 50, height = 64, sourceX = 14 },
	{ name = "LowerLeft.png", x = 0, y = 65, width = 46, height = 54, sourceX = 18 },
	{ name = "LowerRight.png", x = 47, y = 65, width = 56, height = 56 },
	{ name = "RightT.png", x = 104, y = 65, width = 54, height = 64 },
	{ name = "TopT.png", x = 159, y = 65, width = 64, height = 52, sourceY = 12 },
	{ name = "UpperLeft.png", x = 0, y = 130, width = 48, height = 50, sourceX = 16, sourceY = 14 },
	{ name = "UpperRight.png", x = 49, y = 130, width = 52, height = 52, sourceY = 12 },
	{ name = "Vertical.png", x = 102, y = 130, width = 32, height = 64, sourceX = 16 }
}

for _, tile in ipairs(tiles) do
	tile.sourceWidth, tile.sourceHeight = 64, 64
end

return tiles