--!strict
--[[
	Ambiente do mundo, gerado por código a cada início de servidor (reproduzível pelo Rojo):
	- iluminação, atmosfera e pós-processamento;
	- oceano e fundo de areia em Terrain;
	- relevo natural de cada ilha (praia, grama, colina, clareira de construção e caminho).

	Peças do template do lugar (Baseplate, SpawnLocation) não são apagadas: só ficam invisíveis
	e sem colisão durante o jogo, porque o terreno passa a ser o chão.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Art.Palette)

local Environment = {}

-- Observação: o Terrain trabalha em células de 4 studs e arredonda a superfície. A altura final
-- do chão não é exatamente a do preenchimento; por isso as ilhas medem o chão real (GroundY)
-- depois de moldadas, em vez de supor uma altura.

local GRASS = Enum.Material.LeafyGrass -- material do gramado das ilhas
local WATER_TOP = -2
local WATER_DEPTH = 14
local SEABED_DEPTH = 6

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
groundParams.IgnoreWater = true

function Environment.ConfigureLighting()
	Lighting.ClockTime = 15.3 -- sol mais baixo: sombras mais longas e definidas
	Lighting.Brightness = 2.7
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.15
	Lighting.Ambient = Color3.fromRGB(72, 80, 98)
	Lighting.OutdoorAmbient = Color3.fromRGB(116, 124, 142)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ColorShift_Top = Color3.fromRGB(255, 244, 226)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.22
	atmosphere.Color = Color3.fromRGB(200, 232, 255)
	atmosphere.Decay = Color3.fromRGB(120, 180, 225)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.3
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.7
	bloom.Parent = Lighting

	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.05
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting

	-- Desfoque de profundidade atrapalha a leitura e custa no celular.
	local depthOfField = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if depthOfField ~= nil then
		depthOfField.Enabled = false
	end

	local grading = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grading.Saturation = 0.14
	grading.Contrast = 0.06
	grading.Brightness = 0.02
	grading.TintColor = Color3.fromRGB(255, 251, 243)
	grading.Parent = Lighting
end

-- Esconde as peças do template sem apagá-las do lugar.
function Environment.HideTemplateParts()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local part = Workspace:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			for _, child in part:GetChildren() do
				if child:IsA("Decal") or child:IsA("Texture") then
					child.Transparency = 1
				end
			end
		end
	end
end

-- Oceano entre os dois cantos (X, Z), com fundo de areia.
function Environment.FillOcean(minCorner: Vector2, maxCorner: Vector2)
	local terrain = Workspace.Terrain
	terrain.WaterColor = Palette.Water
	terrain.WaterTransparency = 0.7
	terrain.WaterReflectance = 0.3
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	-- A ilha usa LeafyGrass: textura baixa e sem a grama decorativa alta do material Grass
	-- (Terrain.GrassLength só pode ser alterado por plugin, então não é reproduzível por código).
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Palette.Grass)
	terrain:SetMaterialColor(Enum.Material.Ground, Palette.SandWet)
	terrain:SetMaterialColor(Enum.Material.Sand, Palette.Sand)
	terrain:SetMaterialColor(Enum.Material.Rock, Palette.Rock)

	local center = (minCorner + maxCorner) / 2
	local span = maxCorner - minCorner
	terrain:FillBlock(
		CFrame.new(center.X, WATER_TOP - WATER_DEPTH / 2, center.Y),
		Vector3.new(span.X, WATER_DEPTH, span.Y),
		Enum.Material.Water
	)
	terrain:FillBlock(
		CFrame.new(center.X, WATER_TOP - WATER_DEPTH - SEABED_DEPTH / 2, center.Y),
		Vector3.new(span.X, SEABED_DEPTH, span.Y),
		Enum.Material.Sand
	)
end

-- Relevo de uma ilha centrada em `origin` (topo da grama em y = origin.Y).
-- A frente da ilha (píer e chegada) fica em +Z. Construção em clareira de areia no centro.
function Environment.ShapeIsland(origin: Vector3, rng: Random)
	local terrain = Workspace.Terrain
	local function cylinder(offset: Vector3, height: number, radius: number, material: Enum.Material)
		terrain:FillCylinder(CFrame.new(origin + offset), height, radius, material)
	end

	-- Encosta submersa e praia (contorno irregular com bolhas ao redor).
	cylinder(Vector3.new(0, -12, 0), 12, 46, Enum.Material.Sand)
	cylinder(Vector3.new(0, -8, 0), 14, 38, Enum.Material.Sand)
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local distance = rng:NextNumber(30, 34)
		cylinder(
			Vector3.new(math.cos(angle) * distance, -8, math.sin(angle) * distance),
			14,
			rng:NextNumber(8, 12),
			Enum.Material.Sand
		)
	end

	-- Grama, também com borda irregular. A frente (+Z) fica livre para a praia do píer.
	cylinder(Vector3.new(0, -3, 0), 6, 29, GRASS)
	for index = 1, 5 do
		local angle = math.pi + index / 6 * math.pi + rng:NextNumber(-0.2, 0.2) -- metade de trás (-Z)
		local distance = rng:NextNumber(20, 24)
		cylinder(
			Vector3.new(math.cos(angle) * distance, -3, math.sin(angle) * distance),
			6,
			rng:NextNumber(7, 10),
			GRASS
		)
	end

	-- Colina no fundo à esquerda e rochas no fundo à direita.
	terrain:FillBall(origin + Vector3.new(-17, -6, -19), 11, GRASS)
	terrain:FillBall(origin + Vector3.new(24, -3, -20), 5, Enum.Material.Rock)

	-- Clareira de construção e caminho até a praia da frente, em areia, no mesmo nível da grama.
	cylinder(Vector3.new(0, -2, -3), 4, 17, Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(origin + Vector3.new(0, -2, 17)), Vector3.new(7, 4, 26), Enum.Material.Sand)
	-- Clareiras dos pontos B5 a B8 (X, Z; ver Config/Gameplay), planas e no mesmo nível. Raio 6,
	-- acima do mínimo de 5 studs porque o Terrain arredonda em células de 4 studs.
	local clearings = { Vector2.new(-13, 12), Vector2.new(13, 12), Vector2.new(-23, -3), Vector2.new(23, -3) }
	for _, spot in clearings do
		cylinder(Vector3.new(spot.X, -2, spot.Y), 4, 6, Enum.Material.Sand)
	end

	-- A areia gravada sobre a grama nem sempre vence na célula do topo (o material continua grama,
	-- e não areia). Troca o material célula a célula, sem mudar a altura do terreno.
	-- `half` é a metade do lado (retângulo) ou o raio (círculo) da área, relativa ao centro.
	local function sandCells(center: Vector2, half: Vector2, round: boolean)
		local cell = 4
		local cx, cz = origin.X + center.X, origin.Z + center.Y
		for x = math.floor((cx - half.X) / cell) * cell, math.ceil((cx + half.X) / cell) * cell - cell, cell do
			for z = math.floor((cz - half.Y) / cell) * cell, math.ceil((cz + half.Y) / cell) * cell - cell, cell do
				local dx, dz = x + cell / 2 - cx, z + cell / 2 - cz
				local inside = if round then dx * dx + dz * dz <= half.X * half.X else math.abs(dx) <= half.X and math.abs(dz) <= half.Y
				if inside then
					local region = Region3.new(Vector3.new(x, origin.Y - 4, z), Vector3.new(x + cell, origin.Y + 4, z + cell))
					terrain:ReplaceMaterial(region, cell, GRASS, Enum.Material.Sand)
				end
			end
		end
	end
	for _, spot in clearings do
		sandCells(spot, Vector2.new(6, 6), true)
	end
	sandCells(Vector2.new(0, -3), Vector2.new(17, 17), true) -- clareira central
	sandCells(Vector2.new(0, 17), Vector2.new(4, 13), false) -- caminho até a praia
end

export type ExpansionShape = {
	Center: Vector2,
	Radius: number,
	BridgeFrom: number,
}

-- Área nova de uma expansão (gramado, praia e faixa de areia até a ilha principal), na mesma
-- altura do gramado da ilha. `step`, se informado, é chamado entre as etapas (o gramado sobe do
-- mar aos poucos) e pode cancelar a moldagem devolvendo false.
function Environment.ShapeExpansion(origin: Vector3, shape: ExpansionShape, rng: Random, step: (() -> boolean)?): boolean
	local terrain = Workspace.Terrain
	local center = origin + Vector3.new(shape.Center.X, 0, shape.Center.Y)
	local function proceed(): boolean
		return step == nil or step()
	end

	-- Encosta submersa e praia.
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -10, 0)), 12, shape.Radius + 9, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -8, 0)), 14, shape.Radius + 6, Enum.Material.Sand)
	-- Faixa de areia entre a praia da ilha principal e a área nova.
	local bridgeStart = origin.X + shape.BridgeFrom
	local bridgeEnd = center.X - shape.Radius + 2
	terrain:FillBlock(
		CFrame.new((bridgeStart + bridgeEnd) / 2, origin.Y - 2.5, center.Z),
		Vector3.new(bridgeEnd - bridgeStart, 5, 9),
		Enum.Material.Sand
	)
	if not proceed() then
		return false
	end

	-- O gramado sobe em etapas até o nível da ilha.
	local stages = 4
	for index = 1, stages do
		local top = -stages + index -- de -3 até 0, relativo ao gramado
		terrain:FillCylinder(
			CFrame.new(center + Vector3.new(0, top - 3, 0)),
			6,
			shape.Radius * (0.6 + 0.4 * index / stages),
			GRASS
		)
		if not proceed() then
			return false
		end
	end
	-- Borda irregular do gramado.
	for index = 1, 5 do
		local angle = index / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local distance = shape.Radius * rng:NextNumber(0.55, 0.75)
		terrain:FillCylinder(
			CFrame.new(center + Vector3.new(math.cos(angle) * distance, -3, math.sin(angle) * distance)),
			6,
			rng:NextNumber(5, 7),
			GRASS
		)
	end
	-- Caminho de areia vindo da faixa até o meio da área nova.
	terrain:FillBlock(
		CFrame.new((bridgeEnd + center.X) / 2 - 1, origin.Y - 2, center.Z),
		Vector3.new(center.X - bridgeEnd + 2, 4, 6),
		Enum.Material.Sand
	)
	for x = math.floor(bridgeEnd / 4) * 4, math.ceil(center.X / 4) * 4 - 4, 4 do
		local region = Region3.new(Vector3.new(x, origin.Y - 4, center.Z - 4), Vector3.new(x + 4, origin.Y + 4, center.Z + 4))
		terrain:ReplaceMaterial(region:ExpandToGrid(4), 4, GRASS, Enum.Material.Sand)
	end
	return true
end

-- Devolve ao mar a área de uma expansão (quando a ilha é liberada para outro jogador).
-- Só mexe além da praia da ilha principal; a faixa de areia junto à praia permanece.
function Environment.ClearExpansion(origin: Vector3, shape: ExpansionShape)
	local terrain = Workspace.Terrain
	local center = origin + Vector3.new(shape.Center.X, 0, shape.Center.Y)
	local minX = origin.X + 47 -- além da praia mais larga da ilha principal (raio 46)
	local maxX = center.X + shape.Radius + 12
	local half = shape.Radius + 12
	local sizeX = maxX - minX
	local midX = (minX + maxX) / 2
	terrain:FillBlock(CFrame.new(midX, origin.Y + 4, center.Z), Vector3.new(sizeX, 24, half * 2), Enum.Material.Air)
	terrain:FillBlock(
		CFrame.new(midX, WATER_TOP - WATER_DEPTH / 2, center.Z),
		Vector3.new(sizeX, WATER_DEPTH, half * 2),
		Enum.Material.Water
	)
	terrain:FillBlock(
		CFrame.new(midX, WATER_TOP - WATER_DEPTH - SEABED_DEPTH / 2, center.Z),
		Vector3.new(sizeX, SEABED_DEPTH, half * 2),
		Enum.Material.Sand
	)
end

-- Espera o terreno recém-preenchido responder a raycasts: as escritas no Terrain não são
-- consultáveis no mesmo instante, e sem isso as alturas dos objetos cairiam no valor padrão.
function Environment.WaitForGround(position: Vector3, timeout: number): boolean
	local deadline = os.clock() + timeout
	repeat
		local hit = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), groundParams)
		if hit ~= nil then
			return true
		end
		task.wait()
	until os.clock() > deadline
	return false
end

-- Altura do chão de terreno em (x, z). Usa a altura padrão se não encontrar terreno.
function Environment.GroundY(x: number, z: number, fallback: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	if hit == nil then
		return fallback
	end
	return hit.Position.Y
end

return Environment
