--!strict
--[[
	Paleta visual do Island Tycoon: tropical, clara e consistente.
	Usada pelo mundo (servidor) e pela interface (cliente). Só cores, sem lógica.
]]

local Palette = {
	-- Mundo
	Grass = Color3.fromRGB(124, 176, 98),
	GrassDark = Color3.fromRGB(92, 146, 78),
	Sand = Color3.fromRGB(242, 218, 160),
	SandWet = Color3.fromRGB(222, 192, 132),
	Water = Color3.fromRGB(40, 170, 200),
	RockLight = Color3.fromRGB(176, 178, 184),
	Rock = Color3.fromRGB(150, 154, 162),
	RockDark = Color3.fromRGB(118, 124, 136),
	Trunk = Color3.fromRGB(168, 118, 72),
	TrunkDark = Color3.fromRGB(132, 88, 52),
	Leaf = Color3.fromRGB(70, 152, 82),
	LeafLight = Color3.fromRGB(104, 170, 88),
	LeafDark = Color3.fromRGB(48, 120, 70),
	Coconut = Color3.fromRGB(120, 78, 46),
	Bush = Color3.fromRGB(70, 146, 84),
	TrunkMid = Color3.fromRGB(152, 106, 66),
	Metal = Color3.fromRGB(172, 180, 190),
	MetalDark = Color3.fromRGB(104, 112, 124),
	Sawdust = Color3.fromRGB(230, 200, 146),
	FlowerPink = Color3.fromRGB(255, 120, 170),
	FlowerYellow = Color3.fromRGB(255, 214, 80),
	FlowerWhite = Color3.fromRGB(255, 250, 240),
	Plank = Color3.fromRGB(196, 140, 86),
	PlankDark = Color3.fromRGB(150, 100, 60),
	Wall = Color3.fromRGB(250, 232, 196),
	Roof = Color3.fromRGB(226, 96, 72),
	RoofDark = Color3.fromRGB(190, 72, 56),
	Door = Color3.fromRGB(120, 76, 48),
	Window = Color3.fromRGB(140, 210, 240),
	Marker = Color3.fromRGB(255, 236, 140),
	MarkerRing = Color3.fromRGB(255, 196, 70),
	Gold = Color3.fromRGB(246, 196, 64),
	Ore = Color3.fromRGB(255, 220, 120),
	Awning = Color3.fromRGB(64, 178, 196),
	-- Pátio de trabalho e destaque industrial (construções produtivas)
	Dirt = Color3.fromRGB(184, 144, 98),
	DirtDark = Color3.fromRGB(158, 120, 80),
	Industrial = Color3.fromRGB(240, 146, 44),
	IndustrialDark = Color3.fromRGB(192, 104, 30),
	-- Rocha de minério (violeta-acinzentada, distinta das pedras decorativas)
	OreRock = Color3.fromRGB(134, 128, 150),
	OreRockLight = Color3.fromRGB(172, 166, 190),
	OreRockDark = Color3.fromRGB(98, 94, 114),
	GoldDark = Color3.fromRGB(204, 150, 44),
	BuoyRed = Color3.fromRGB(240, 96, 80),
	-- Pedreira, Carpintaria e passadiço (passe de arte)
	QuarryYard = Color3.fromRGB(176, 166, 150),
	WorkshopYard = Color3.fromRGB(214, 194, 150),
	ThatchRoof = Color3.fromRGB(214, 176, 96),
	ThatchDark = Color3.fromRGB(176, 136, 70),
	WorkshopWall = Color3.fromRGB(92, 170, 164),
	WorkshopTrim = Color3.fromRGB(58, 124, 126),
	PlankLight = Color3.fromRGB(226, 184, 128),
	RopeFiber = Color3.fromRGB(222, 200, 150),

	-- Interface
	UiPanel = Color3.fromRGB(255, 249, 236),
	UiPanelDark = Color3.fromRGB(64, 46, 34),
	UiText = Color3.fromRGB(70, 50, 36),
	UiTextLight = Color3.fromRGB(255, 255, 255),
	UiMuted = Color3.fromRGB(150, 128, 108),
	UiAccent = Color3.fromRGB(255, 178, 60),
	UiAccentDark = Color3.fromRGB(214, 128, 28),
	UiGood = Color3.fromRGB(86, 196, 104),
	UiGoodDark = Color3.fromRGB(52, 150, 74),
	UiBad = Color3.fromRGB(236, 92, 82),
	UiNeutral = Color3.fromRGB(196, 184, 170),
	UiWood = Color3.fromRGB(196, 132, 74),
	UiStone = Color3.fromRGB(132, 140, 156),
	UiCoin = Color3.fromRGB(232, 176, 40),
}

return Palette
