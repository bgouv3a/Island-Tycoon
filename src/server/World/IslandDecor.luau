--!strict
--[[
	Decoração de uma ilha: caminho, flores, arbustos, pedras, placa e píer.
	Só visual: nada aqui tem regra de jogo. Posições escolhidas para não cobrir árvores,
	pontos de construção nem a chegada do jogador (ver IslandService e Config/Gameplay).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Models = require(ReplicatedStorage:WaitForChild("Shared").Art.Models)
local Environment = require(script.Parent.Environment)

local IslandDecor = {}

-- Posições relativas ao centro da ilha (X, Z). A frente da ilha é +Z.
local ROCKS: { Vector3 } = { -- (X, Z, escala)
	Vector3.new(-34, 6, 1.6),
	Vector3.new(32, 14, 1.3),
	Vector3.new(-21, 31, 1.1),
	Vector3.new(25, -27, 1.8),
	Vector3.new(-31, -19, 1.4),
	Vector3.new(36, 5, 1.2), -- fora da faixa de areia da Enseada Leste (z = -5)
	Vector3.new(14, 33, 0.9),
}
local BUSHES: { Vector2 } = {
	Vector2.new(-20, 19),
	Vector2.new(20, 19),
	Vector2.new(-9, -16),
	Vector2.new(11, -15),
	Vector2.new(-18, -9),
	Vector2.new(19, -11),
	Vector2.new(-6, 27),
}
local FLOWERS: { Vector2 } = {
	Vector2.new(-4, 7),
	Vector2.new(4, 9),
	Vector2.new(-4, 13),
	Vector2.new(4, 16),
	Vector2.new(-4, 20),
	Vector2.new(-21, 14),
	Vector2.new(21, 14),
	Vector2.new(-25, 12),
	Vector2.new(9, -19),
}
local PATH_Z = { 6, 9.5, 13, 16.5, 20, 23.5, 27 }
local SIGN_OFFSET = Vector2.new(5.5, 21)
local DOCK_START = Vector2.new(0, 31)
local DOCK_LENGTH = 15

-- Monta a decoração dentro de `model`. Devolve a peça usada como âncora do nome da ilha.
function IslandDecor.Build(model: Model, origin: Vector3, seed: number): BasePart
	local rng = Random.new(seed)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model

	local function ground(offset: Vector2): CFrame
		local x, z = origin.X + offset.X, origin.Z + offset.Y
		local y = Environment.GroundY(x, z, origin.Y)
		return CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end

	for index, z in PATH_Z do
		local spot = ground(Vector2.new(rng:NextNumber(-0.6, 0.6), z))
		Models.SteppingStone(decor, spot, rng:NextNumber(2.4, 3) + (if index == 1 then 0.4 else 0))
	end
	for index, rock in ROCKS do
		Models.Rock(ground(Vector2.new(rock.X, rock.Y)), rock.Z, seed * 31 + index).Parent = decor
	end
	for index, spot in BUSHES do
		Models.Bush(ground(spot), rng:NextNumber(0.9, 1.25), seed * 17 + index).Parent = decor
	end
	for index, spot in FLOWERS do
		Models.Flowers(ground(spot), seed * 13 + index).Parent = decor
	end

	-- Placa de boas-vindas virada para a chegada (frente da placa para +Z).
	local signX, signZ = origin.X + SIGN_OFFSET.X, origin.Z + SIGN_OFFSET.Y
	local signY = Environment.GroundY(signX, signZ, origin.Y)
	local signBase = CFrame.new(signX, signY, signZ) * CFrame.Angles(0, math.pi, 0)
	Models.Sign(signBase).Parent = decor

	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = signBase * CFrame.new(0, 5.4, 0)
	anchor.Parent = model

	-- Píer avançando para o mar a partir da praia da frente (+Z).
	local dockBase = CFrame.new(origin.X + DOCK_START.X, origin.Y - 0.1, origin.Z + DOCK_START.Y)
		* CFrame.Angles(0, math.pi, 0)
	Models.Dock(dockBase, DOCK_LENGTH).Parent = decor

	return anchor
end

-- Decoração das áreas de expansão (X, Z relativos ao centro da ilha), fora dos pontos de
-- construção, dos nós de coleta e do caminho de areia.
local EXPANSION_DECOR: { [string]: { Bushes: { Vector2 }, Flowers: { Vector2 } } } = {
	E1 = {
		Bushes = { Vector2.new(50, -15), Vector2.new(57, 9), Vector2.new(71, -15) },
		Flowers = { Vector2.new(47, 1), Vector2.new(58, -1), Vector2.new(69, 7) },
	},
}

-- Passadiço da Enseada Leste: trechos de 4 studs de x = 33 a 49 ao longo de z = -5 (faixa de areia
-- de 9 de largura) e plantas de praia nas bordas da faixa, fora do piso do passadiço.
local BOARDWALK_X = { 33, 37, 41, 45, 49 }
local BOARDWALK_Z = -5
local BEACH_PLANTS: { Vector2 } = {
	Vector2.new(35, -8.4),
	Vector2.new(39, -1.7),
	Vector2.new(43, -8.3),
	Vector2.new(46.5, -1.8),
	Vector2.new(48.5, -8.2),
}

-- Monta a decoração de uma área de expansão dentro de `parent`.
function IslandDecor.BuildExpansion(parent: Instance, origin: Vector3, area: string, seed: number)
	local spots = EXPANSION_DECOR[area]
	if spots == nil then
		return
	end
	local rng = Random.new(seed * 41)
	local function ground(offset: Vector2): CFrame
		local x, z = origin.X + offset.X, origin.Z + offset.Y
		local y = Environment.GroundY(x, z, origin.Y)
		return CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	end
	for index, spot in spots.Bushes do
		Models.Bush(ground(spot), rng:NextNumber(0.9, 1.2), seed * 19 + index).Parent = parent
	end
	for index, spot in spots.Flowers do
		Models.Flowers(ground(spot), seed * 23 + index).Parent = parent
	end

	-- Passadiço de madeira e corda sobre a faixa de areia, ligando a ilha à área (centro livre).
	if area == "E1" then
		local segments = #BOARDWALK_X - 1
		for index = 1, segments do
			local x = origin.X + BOARDWALK_X[index]
			local z = origin.Z + BOARDWALK_Z
			local y = Environment.GroundY(x + 2, z, origin.Y)
			local segment = Models.BoardwalkSegment(CFrame.new(x, y, z), index % 2 == 1, index == segments)
			segment.Parent = parent
		end
		for index, spot in BEACH_PLANTS do
			Models.BeachPlant(ground(spot), seed * 29 + index).Parent = parent
		end
	end
end

return IslandDecor
