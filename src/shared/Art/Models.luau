--!strict
--[[
	Modelos low-poly do Island Tycoon, gerados por código (sem assets externos).
	Usado pelo servidor para montar o mundo e pelo cliente para prévias da interface.

	Regras: peças ancoradas, poucas peças por modelo, sem scripts. Decoração sem colisão.
	Convenção: o CFrame recebido fica no chão, e a frente do modelo aponta para -Z (LookVector).
]]

local Palette = require(script.Parent.Palette)

local Models = {}

type Options = {
	Shape: Enum.PartType?,
	Wedge: boolean?,
	Transparency: number?,
	CanCollide: boolean?,
	Shadow: boolean?,
	Material: Enum.Material?,
}

local function make(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, options: Options?): BasePart
	local opts: Options = options or {}
	local part: BasePart
	if opts.Wedge then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if opts.Shape ~= nil then
			block.Shape = opts.Shape
		end
		part = block
	end
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = opts.Material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = opts.Transparency or 0
	local collide = if opts.CanCollide == nil then true else opts.CanCollide
	part.CanCollide = collide
	if not collide then
		part.CanTouch = false
		part.CanQuery = false
	end
	if opts.Shadow == false then
		part.CastShadow = false
	end
	part.Parent = parent
	return part
end

local CYLINDER_UP = CFrame.Angles(0, 0, math.pi / 2) -- cilindro do Roblox tem o eixo em X
local BALL = Enum.PartType.Ball
local CYLINDER = Enum.PartType.Cylinder

-- Palmeira: tronco esguio e afunilado com curva suave, copa com folhas longas em arco e cocos.
-- Devolve o modelo, a peça base do tronco (usada como nó de coleta) e as peças da copa.
function Models.PalmTree(base: CFrame, seed: number): (Model, BasePart, { BasePart })
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Palmeira"

	local crown: { BasePart } = {}
	local cursor = base * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local lean = rng:NextNumber(0.05, 0.09) -- curvatura por segmento (acumula, forma o arco)
	local trunk: BasePart? = nil
	local segments = 6
	local length = 1.75

	for index = 1, segments do
		local diameter = 1.15 - index * 0.085 -- afunila de baixo para cima
		if index > 1 then
			cursor = cursor * CFrame.Angles(lean * (0.6 + index * 0.12), 0, 0)
		end
		-- Anéis sutis: tons próximos alternados.
		local color = if index % 2 == 0 then Palette.TrunkMid else Palette.Trunk
		local segment = make(
			model,
			if index == 1 then "Trunk" else "TrunkSegment",
			Vector3.new(length + 0.2, diameter, diameter),
			cursor * CFrame.new(0, length / 2, 0) * CYLINDER_UP,
			color,
			{ Shape = CYLINDER }
		)
		if index == 1 then
			trunk = segment
		end
		cursor = cursor * CFrame.new(0, length, 0)
	end

	local top = CFrame.new(cursor.Position)
	table.insert(
		crown,
		make(model, "Hub", Vector3.new(1.3, 1.3, 1.3), top, Palette.LeafDark, { Shape = BALL, CanCollide = false })
	)

	-- Folhas longas e finas: três segmentos por folha, subindo e caindo em arco.
	local leafColors = { Palette.Leaf, Palette.LeafLight, Palette.LeafDark }
	local leaves = 8
	local widths = { 1.0, 0.8, 0.5 }
	local lengths = { 2.2, 2.2, 1.9 }
	local pitches = { 0.3, -0.5, -0.6 }
	for index = 1, leaves do
		local yaw = (index / leaves) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local color = leafColors[(index % 3) + 1]
		local leafCursor = top * CFrame.Angles(0, yaw, 0) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, 0)
		for step = 1, 3 do
			leafCursor = leafCursor * CFrame.Angles(pitches[step], 0, 0)
			local len = lengths[step]
			table.insert(
				crown,
				make(
					model,
					"Leaf",
					Vector3.new(widths[step], 0.18, len),
					leafCursor * CFrame.new(0, 0, -len / 2),
					color,
					{ CanCollide = false, Shadow = step == 1 }
				)
			)
			leafCursor = leafCursor * CFrame.new(0, 0, -len)
		end
	end

	-- Cocos agrupados sob a copa.
	for index = 1, 4 do
		local spot = top * CFrame.Angles(0, index * 1.57 + 0.4, 0) * CFrame.new(0, -0.75, -0.5)
		table.insert(
			crown,
			make(model, "Coconut", Vector3.new(0.7, 0.7, 0.7), spot, Palette.Coconut, { Shape = BALL, CanCollide = false })
		)
	end

	return model, trunk :: BasePart, crown
end

-- Cerca de madeira com três postes, duas travessas e arbustos nas pontas. Largura ~7.
local function buildFence(origin: CFrame, model: Model)
	for _, x in { -2.8, 0, 2.8 } do
		make(model, "Post", Vector3.new(0.6, 2.6, 0.6), origin * CFrame.new(x, 1.3, 0), Palette.PlankDark)
		make(model, "Cap", Vector3.new(0.8, 0.8, 0.8), origin * CFrame.new(x, 2.65, 0), Palette.Plank, { Shape = BALL })
	end
	for _, y in { 0.95, 1.9 } do
		make(model, "Rail", Vector3.new(6.4, 0.38, 0.28), origin * CFrame.new(0, y, -0.38), Palette.Plank)
	end
	for _, x in { -3.6, 3.6 } do
		make(
			model,
			"Bush",
			Vector3.new(1.5, 1.5, 1.5),
			origin * CFrame.new(x, 0.55, 0.2),
			Palette.Bush,
			{ Shape = BALL, CanCollide = false }
		)
	end
end

-- Cabana: piso, paredes, colunas, telhado de duas águas, porta, janelas e chaminé.
local function buildCabin(origin: CFrame, model: Model)
	make(model, "Floor", Vector3.new(7.6, 0.6, 6.6), origin * CFrame.new(0, 0.3, 0), Palette.PlankDark)
	make(model, "Walls", Vector3.new(6.6, 4, 5.6), origin * CFrame.new(0, 2.6, 0), Palette.Wall)
	for _, corner in { Vector2.new(-3.3, -2.8), Vector2.new(3.3, -2.8), Vector2.new(-3.3, 2.8), Vector2.new(3.3, 2.8) } do
		make(
			model,
			"Column",
			Vector3.new(0.7, 4.2, 0.7),
			origin * CFrame.new(corner.X, 2.7, corner.Y),
			Palette.Plank
		)
	end
	-- Telhado: duas cunhas. A face inclinada da WedgePart desce para -Z.
	make(
		model,
		"RoofFront",
		Vector3.new(7.8, 2.4, 3.6),
		origin * CFrame.new(0, 5.8, -1.8),
		Palette.Roof,
		{ Wedge = true }
	)
	make(
		model,
		"RoofBack",
		Vector3.new(7.8, 2.4, 3.6),
		origin * CFrame.new(0, 5.8, 1.8) * CFrame.Angles(0, math.pi, 0),
		Palette.RoofDark,
		{ Wedge = true }
	)
	make(model, "Ridge", Vector3.new(8, 0.4, 0.5), origin * CFrame.new(0, 7.05, 0), Palette.RoofDark)
	make(model, "Door", Vector3.new(1.6, 2.6, 0.2), origin * CFrame.new(0, 1.9, -2.85), Palette.Door)
	make(model, "Knob", Vector3.new(0.25, 0.25, 0.25), origin * CFrame.new(0.5, 1.9, -2.98), Palette.FlowerYellow, { Shape = BALL, Shadow = false })
	for _, x in { -2, 2 } do
		make(model, "WindowFrame", Vector3.new(1.5, 1.5, 0.2), origin * CFrame.new(x, 2.9, -2.84), Palette.Plank)
		make(model, "Window", Vector3.new(1.1, 1.1, 0.22), origin * CFrame.new(x, 2.9, -2.86), Palette.Window, { Shadow = false })
	end
	make(model, "Step", Vector3.new(2.2, 0.35, 0.9), origin * CFrame.new(0, 0.18, -3.7), Palette.Plank)
	make(model, "Chimney", Vector3.new(0.9, 2.2, 0.9), origin * CFrame.new(2.2, 6.6, 1.4), Palette.RockDark)
	-- Toque doméstico: jardineiras com flores, varanda, tapete, caminho de pedras e lanterna.
	local blooms = { Palette.FlowerPink, Palette.FlowerYellow, Palette.FlowerWhite }
	for side, x in { -2.6, 2.6 } do
		make(model, "Planter", Vector3.new(1.9, 0.6, 0.7), origin * CFrame.new(x, 0.3, -3.5), Palette.Plank, { CanCollide = false })
		make(model, "PlanterLeaves", Vector3.new(1.7, 0.6, 0.6), origin * CFrame.new(x, 0.8, -3.5), Palette.Bush, { Shape = BALL, CanCollide = false, Shadow = false })
		for index = 1, 3 do
			make(
				model,
				"FlowerBox",
				Vector3.new(0.45, 0.45, 0.45),
				origin * CFrame.new(x + (index - 2) * 0.55, 1.15 + (index % 2) * 0.1, -3.5),
				blooms[((index + side) % 3) + 1],
				{ Shape = BALL, CanCollide = false, Shadow = false }
			)
		end
	end
	make(model, "Porch", Vector3.new(3.4, 0.16, 1.6), origin * CFrame.new(0, 0.08, -4.9), Palette.Plank, { CanCollide = false, Shadow = false })
	make(model, "Mat", Vector3.new(1.4, 0.05, 0.8), origin * CFrame.new(0, 0.19, -4.6), Palette.Roof, { CanCollide = false, Shadow = false })
	for index = 1, 2 do
		make(
			model,
			"PathStone",
			Vector3.new(0.12, 1 - index * 0.15, 1 - index * 0.15),
			origin * CFrame.new((index - 1.5) * 0.3, 0.05, -5.4 - (index - 1) * 0.75) * CYLINDER_UP,
			Palette.SandWet,
			{ Shape = CYLINDER, CanCollide = false, Shadow = false }
		)
	end
	make(model, "LanternPost", Vector3.new(0.2, 1.7, 0.2), origin * CFrame.new(3.4, 0.85, -4.4), Palette.PlankDark, { CanCollide = false })
	make(model, "Lantern", Vector3.new(0.55, 0.55, 0.55), origin * CFrame.new(3.4, 1.9, -4.4), Palette.Marker, { Shape = BALL, CanCollide = false, Shadow = false, Material = Enum.Material.Neon })
end

-- Serraria: plataforma de tábuas, galpão aberto, bancada com tora, lâmina, manivela, pilha e caixote.
-- Contrato com o cliente (ProductionController): Blade e Wheel giram no eixo X local, Log oscila
-- em X local (todas guardam BaseCFrame) e Output é o ponto do prompt e do indicador (frente, -Z).
local function buildSawmill(origin: CFrame, model: Model)
	local base = make(model, "Base", Vector3.new(9, 0.5, 8), origin * CFrame.new(0, 0.25, 0), Palette.PlankDark)
	model.PrimaryPart = base
	for index = 0, 3 do
		make(
			model,
			"Deck",
			Vector3.new(9, 0.1, 1.9),
			origin * CFrame.new(0, 0.53, -3 + index * 2),
			if index % 2 == 0 then Palette.Plank else Palette.PlankDark
		)
	end

	-- Pátio de trabalho: terra batida com borda de pedra, estacas laranja e cascalho (sem colisão).
	make(model, "Yard", Vector3.new(13.4, 0.1, 12.4), origin * CFrame.new(0, 0.05, 0), Palette.Dirt, { CanCollide = false, Shadow = false })
	for _, z in { -6.2, 6.2 } do
		make(model, "YardEdge", Vector3.new(13.8, 0.3, 0.5), origin * CFrame.new(0, 0.15, z), Palette.Rock, { CanCollide = false, Shadow = false })
	end
	for _, x in { -6.7, 6.7 } do
		make(model, "YardEdge", Vector3.new(0.5, 0.3, 12.4), origin * CFrame.new(x, 0.15, 0), Palette.Rock, { CanCollide = false, Shadow = false })
	end
	for _, x in { -6.7, 6.7 } do
		for _, z in { -6.2, 6.2 } do
			make(model, "YardStake", Vector3.new(0.4, 1.1, 0.4), origin * CFrame.new(x, 0.55, z), Palette.Industrial, { CanCollide = false, Shadow = false })
		end
	end
	make(model, "Gravel", Vector3.new(2.6, 0.08, 1.8), origin * CFrame.new(-5, 0.12, -4.6) * CFrame.Angles(0, 0.4, 0), Palette.DirtDark, { CanCollide = false, Shadow = false })

	-- Galpão aberto no fundo (z de -1 a 3.8), com telhado de cunhas.
	for _, x in { -4, 4 } do
		for _, z in { -0.8, 3.4 } do
			make(model, "Column", Vector3.new(0.5, 4.6, 0.5), origin * CFrame.new(x, 2.85, z), Palette.Plank)
		end
	end
	make(model, "Header", Vector3.new(8.6, 0.4, 0.4), origin * CFrame.new(0, 5, -0.8), Palette.Industrial)
	make(model, "BackWall", Vector3.new(7.5, 3.4, 0.25), origin * CFrame.new(0, 2.3, 3.7), Palette.PlankDark)
	local zc = 1.4
	make(
		model,
		"RoofFront",
		Vector3.new(9.6, 2.2, 3.0),
		origin * CFrame.new(0, 6.2, zc - 1.5),
		Palette.Roof,
		{ Wedge = true }
	)
	make(
		model,
		"RoofBack",
		Vector3.new(9.6, 2.2, 3.0),
		origin * CFrame.new(0, 6.2, zc + 1.5) * CFrame.Angles(0, math.pi, 0),
		Palette.RoofDark,
		{ Wedge = true }
	)
	make(model, "Ridge", Vector3.new(9.8, 0.35, 0.5), origin * CFrame.new(0, 7.4, zc), Palette.RoofDark)

	-- Bancada (comprimento ao longo de X) com a tora em cima.
	make(model, "Bench", Vector3.new(6.4, 0.3, 1.6), origin * CFrame.new(0, 2.05, 1.2), Palette.Plank)
	for _, x in { -2.8, 2.8 } do
		for _, z in { 0.6, 1.8 } do
			make(model, "BenchLeg", Vector3.new(0.4, 1.5, 0.4), origin * CFrame.new(x, 1.3, z), Palette.PlankDark)
		end
	end
	local logCFrame = origin * CFrame.new(-1, 2.2 + 0.55, 1.2)
	local log = make(model, "Log", Vector3.new(4.2, 1.1, 1.1), logCFrame, Palette.Trunk, { Shape = CYLINDER })
	log:SetAttribute("BaseCFrame", log.CFrame)

	-- Lâmina circular vertical (plano YZ, eixo X) com cubo, caixa do motor e braço de apoio.
	local blade = make(
		model,
		"Blade",
		Vector3.new(0.12, 2.8, 2.8),
		origin * CFrame.new(1.7, 3.2, 1.2),
		Palette.Metal,
		{ Shape = CYLINDER }
	)
	blade:SetAttribute("BaseCFrame", blade.CFrame)
	make(
		model,
		"BladeHub",
		Vector3.new(0.3, 0.7, 0.7),
		origin * CFrame.new(1.7, 3.2, 1.2),
		Palette.MetalDark,
		{ Shape = CYLINDER }
	)
	make(model, "Motor", Vector3.new(0.9, 1, 1), origin * CFrame.new(2.4, 3.2, 1.2), Palette.MetalDark)
	make(model, "Arm", Vector3.new(0.5, 0.5, 1.8), origin * CFrame.new(2.4, 3.2, 2.6), Palette.PlankDark)

	-- Roda lateral: aro fixo e manivela que gira.
	make(
		model,
		"Flywheel",
		Vector3.new(0.25, 2.6, 2.6),
		origin * CFrame.new(4.6, 2.4, 1.2),
		Palette.MetalDark,
		{ Shape = CYLINDER, CanCollide = false }
	)
	make(
		model,
		"WheelHub",
		Vector3.new(0.5, 0.5, 0.5),
		origin * CFrame.new(4.8, 2.4, 1.2),
		Palette.Metal,
		{ Shape = CYLINDER, CanCollide = false }
	)
	local wheel = make(
		model,
		"Wheel",
		Vector3.new(0.2, 2.2, 0.35),
		origin * CFrame.new(4.85, 2.4, 1.2),
		Palette.Plank,
		{ CanCollide = false }
	)
	wheel:SetAttribute("BaseCFrame", wheel.CFrame)

	-- Serragem sob a lâmina.
	make(
		model,
		"Sawdust",
		Vector3.new(2.4, 0.08, 1.6),
		origin * CFrame.new(1.2, 0.6, 1.2),
		Palette.Sawdust,
		{ CanCollide = false, Shadow = false }
	)

	-- Pilha de tábuas prontas (frente esquerda).
	for layer = 0, 3 do
		make(
			model,
			"Board",
			Vector3.new(3.2, 0.3, 1.5),
			origin * CFrame.new(-2.4 + (layer % 2) * 0.1, 0.65 + layer * 0.3, -2.7) * CFrame.Angles(0, (layer - 1.5) * 0.04, 0),
			if layer % 2 == 0 then Palette.Plank else Palette.PlankDark
		)
	end
	for _, x in { -3.6, -1.2 } do
		make(
			model,
			"Spacer",
			Vector3.new(0.3, 0.2, 1.5),
			origin * CFrame.new(x, 0.6, -2.7),
			Palette.PlankDark,
			{ Shadow = false }
		)
	end

	-- Caixote de saída (frente direita): é onde o jogador recolhe.
	make(model, "Output", Vector3.new(2.2, 1.1, 1.6), origin * CFrame.new(2.4, 1.05, -2.6), Palette.Plank)
	make(
		model,
		"CrateLid",
		Vector3.new(2.3, 0.15, 1.7),
		origin * CFrame.new(2.4, 1.65, -2.6),
		Palette.PlankDark,
		{ CanCollide = false }
	)
	make(
		model,
		"CrateBand",
		Vector3.new(0.25, 1.15, 1.65),
		origin * CFrame.new(2.4, 1.05, -2.6),
		Palette.PlankDark,
		{ CanCollide = false, Shadow = false }
	)

	-- Evolução visual por nível (Models.ApplyLevel mostra as peças com MinLevel <= nível).
	local function tier(level: number, part: BasePart)
		part:SetAttribute("MinLevel", level)
	end
	-- Nível 2: cintas e cantoneiras de metal nas colunas, segunda lâmina (com cubo) ao lado da primeira.
	for _, x in { -4, 4 } do
		for _, z in { -0.8, 3.4 } do
			tier(2, make(model, "TierBand", Vector3.new(0.75, 0.3, 0.75), origin * CFrame.new(x, 1.2, z), Palette.MetalDark, { CanCollide = false }))
			tier(2, make(model, "TierBand", Vector3.new(0.75, 0.3, 0.75), origin * CFrame.new(x, 4.3, z), Palette.Metal, { CanCollide = false }))
		end
	end
	tier(2, make(model, "TierBlade", Vector3.new(0.1, 2, 2), origin * CFrame.new(-2.6, 3.1, 1.2), Palette.Metal, { Shape = CYLINDER, CanCollide = false }))
	tier(2, make(model, "TierBladeHub", Vector3.new(0.25, 0.5, 0.5), origin * CFrame.new(-2.6, 3.1, 1.2), Palette.Industrial, { Shape = CYLINDER, CanCollide = false }))
	-- Nível 3: alicerce de pedra (visível em volta da plataforma) e chaminé de tijolo com tampa.
	tier(3, make(model, "TierFoundation", Vector3.new(9.8, 0.9, 8.8), origin * CFrame.new(0, 0.0, 0), Palette.Rock))
	tier(3, make(model, "TierChimney", Vector3.new(1.2, 3.4, 1.2), origin * CFrame.new(-3.2, 7.1, 2.6), Palette.RoofDark, { CanCollide = false }))
	tier(3, make(model, "TierChimneyCap", Vector3.new(1.6, 0.35, 1.6), origin * CFrame.new(-3.2, 8.95, 2.6), Palette.MetalDark, { CanCollide = false }))
	-- Nível 4: esteira (com trilhos laranja e roletes) da bancada até o caixote.
	tier(4, make(model, "TierBelt", Vector3.new(1.2, 0.2, 3.6), origin * CFrame.new(2.4, 1.85, -0.9), Palette.MetalDark, { CanCollide = false }))
	for _, x in { 1.7, 3.1 } do
		tier(4, make(model, "TierRail", Vector3.new(0.15, 0.3, 3.6), origin * CFrame.new(x, 2, -0.9), Palette.Industrial, { CanCollide = false }))
	end
	for index = 0, 2 do
		tier(4, make(model, "TierRoller", Vector3.new(1.3, 0.35, 0.35), origin * CFrame.new(2.4, 1.97, -2.1 + index * 1.2), Palette.Metal, { Shape = CYLINDER, CanCollide = false }))
	end
	-- Nível 5: acabamento dourado no telhado e nas colunas da frente, mastro e bandeira.
	tier(5, make(model, "TierTrim", Vector3.new(9.9, 0.2, 0.6), origin * CFrame.new(0, 7.62, zc), Palette.Gold, { CanCollide = false }))
	for _, x in { -4, 4 } do
		tier(5, make(model, "TierGoldCap", Vector3.new(0.9, 0.3, 0.9), origin * CFrame.new(x, 5.2, -0.8), Palette.Gold, { CanCollide = false }))
	end
	tier(5, make(model, "TierMast", Vector3.new(0.2, 2.6, 0.2), origin * CFrame.new(4.4, 8.6, zc), Palette.GoldDark, { CanCollide = false }))
	tier(5, make(model, "TierFlag", Vector3.new(0.08, 1.1, 1.8), origin * CFrame.new(4.4, 9.4, zc - 0.95), Palette.UiAccent, { CanCollide = false, Shadow = false }))
end

-- Marca uma peça de evolução: aparece quando o nível da estrutura >= `level` (ver Models.ApplyLevel).
local function markTier(level: number, part: BasePart): BasePart
	part:SetAttribute("MinLevel", level)
	return part
end

-- Registra a animação da peça para o cliente: `kind` = "Spin" (rad/s, eixo X local) ou "Bob" (studs).
local function animate(part: BasePart, kind: string, amount: number): BasePart
	part:SetAttribute(kind, amount)
	part:SetAttribute("BaseCFrame", part.CFrame)
	return part
end

local DECO = { CanCollide = false, Shadow = false }
local DECO_SHADOW = { CanCollide = false }

-- Pedreira: paredão de rocha cortado em degraus, guindaste de madeira com polia, carrinho sobre trilhos,
-- britadeira sob pórtico e blocos cortados. Silhueta de rocha cinza, sem telhado.
-- Contrato: Base (melhoria), Output (recolher, frente direita); Drill faz Bob, Pulley gira (Spin).
-- Níveis (4): 1 base; 2 degrau extra, bloco extra e cintas laranja; 3 segunda britadeira e lanterna;
-- 4 acabamento dourado, bandeira e veios de minério.
local function buildQuarry(origin: CFrame, model: Model)
	local base = make(model, "Base", Vector3.new(9, 0.5, 8), origin * CFrame.new(0, 0.25, 0), Palette.RockDark)
	model.PrimaryPart = base

	-- Pátio de trabalho: terra cinza com borda de pedra e rochas soltas nos cantos.
	make(model, "Yard", Vector3.new(13.4, 0.1, 12.4), origin * CFrame.new(0, 0.05, 0), Palette.QuarryYard, DECO)
	for _, z in { -6.2, 6.2 } do
		make(model, "YardEdge", Vector3.new(13.8, 0.3, 0.5), origin * CFrame.new(0, 0.15, z), Palette.RockLight, DECO)
	end
	for _, x in { -6.7, 6.7 } do
		make(model, "YardEdge", Vector3.new(0.5, 0.3, 12.4), origin * CFrame.new(x, 0.15, 0), Palette.RockLight, DECO)
	end
	make(model, "YardRock", Vector3.new(1.3, 0.9, 1.1), origin * CFrame.new(-6.2, 0.45, -5.6) * CFrame.Angles(0, 0.5, 0), Palette.RockDark, DECO_SHADOW)
	make(model, "YardRock", Vector3.new(1, 0.7, 1.2), origin * CFrame.new(6.2, 0.35, -5.7) * CFrame.Angles(0, 1.1, 0), Palette.Rock, DECO_SHADOW)

	-- Paredão cortado em degraus (de frente para trás, cada degrau mais alto e mais estreito).
	local stepColors = { Palette.Rock, Palette.RockLight, Palette.Rock, Palette.RockLight }
	for index = 0, 3 do
		local startZ = 0.6 + index * 0.9
		local depth = 4 - startZ
		local height = 1.2 * (index + 1)
		local step = make(
			model,
			"Step",
			Vector3.new(8.2 - index * 1.3, height, depth),
			origin * CFrame.new(0, 0.5 + height / 2, startZ + depth / 2),
			stepColors[index + 1]
		)
		if index == 3 then
			step.CanCollide = false
			markTier(2, step)
		end
	end
	-- Furos de cunha na face do segundo degrau.
	for _, x in { -1.8, 0.2 } do
		make(model, "DrillHole", Vector3.new(0.5, 0.35, 0.12), origin * CFrame.new(x, 2.4, 1.46), Palette.MetalDark, DECO)
	end

	-- Guindaste de madeira (mastro, lança, escora, polia que gira, corda e bloco pendurado).
	make(model, "CraneMast", Vector3.new(0.5, 6, 0.5), origin * CFrame.new(-3.4, 3.5, 0.3), Palette.Plank)
	make(model, "CraneBoom", Vector3.new(0.4, 0.4, 3.2), origin * CFrame.new(-3.4, 6.4, -1.3), Palette.PlankDark, DECO_SHADOW)
	make(model, "CraneBrace", Vector3.new(0.3, 0.3, 2.6), origin * CFrame.new(-3.4, 5.45, -0.7) * CFrame.Angles(0.7, 0, 0), Palette.PlankDark, DECO_SHADOW)
	animate(make(model, "Pulley", Vector3.new(0.3, 1.2, 1.2), origin * CFrame.new(-3.4, 6.4, -2.9), Palette.MetalDark, { Shape = CYLINDER, CanCollide = false }), "Spin", 2.5)
	make(model, "CraneRope", Vector3.new(0.1, 2.9, 0.1), origin * CFrame.new(-3.4, 4.95, -2.9), Palette.Sawdust, DECO)
	make(model, "HoistBlock", Vector3.new(1.3, 1, 1.3), origin * CFrame.new(-3.4, 3, -2.9) * CFrame.Angles(0, 0.3, 0), Palette.RockLight, DECO_SHADOW)

	-- Trilho com carrinho carregado de pedras (ao lado do guindaste).
	for _, x in { -4, -2.8 } do
		make(model, "Rail", Vector3.new(0.18, 0.15, 3.2), origin * CFrame.new(x, 0.575, -2.3), Palette.MetalDark, DECO)
	end
	for _, z in { -3.6, -2.4, -1.2 } do
		make(model, "Sleeper", Vector3.new(2, 0.1, 0.3), origin * CFrame.new(-3.4, 0.55, z), Palette.PlankDark, DECO)
	end
	make(model, "CartBody", Vector3.new(1.5, 0.8, 1.8), origin * CFrame.new(-3.4, 1.15, -2.9), Palette.MetalDark, DECO_SHADOW)
	make(model, "CartRim", Vector3.new(1.6, 0.15, 1.9), origin * CFrame.new(-3.4, 1.6, -2.9), Palette.Industrial, DECO)
	for _, x in { -4.2, -2.6 } do
		for _, z in { -3.5, -2.3 } do
			make(model, "CartWheel", Vector3.new(0.2, 0.6, 0.6), origin * CFrame.new(x, 0.9, z), Palette.Metal, { Shape = CYLINDER, CanCollide = false, Shadow = false })
		end
	end
	make(model, "CartStone", Vector3.new(0.9, 0.5, 0.8), origin * CFrame.new(-3.7, 1.9, -3.2) * CFrame.Angles(0, 0.4, 0), Palette.Rock, DECO)
	make(model, "CartStone", Vector3.new(0.8, 0.5, 0.7), origin * CFrame.new(-3, 1.9, -2.6) * CFrame.Angles(0, -0.3, 0), Palette.RockDark, DECO)

	-- Pórtico com britadeira (a haste sobe e desce sobre o primeiro degrau).
	for _, x in { 0.2, 2.2 } do
		make(model, "GantryPost", Vector3.new(0.35, 5.2, 0.35), origin * CFrame.new(x, 3.1, 0.35), Palette.Plank)
	end
	make(model, "GantryBeam", Vector3.new(2.4, 0.4, 1.4), origin * CFrame.new(1.2, 5.6, 0.8), Palette.PlankDark, DECO_SHADOW)
	make(model, "Compressor", Vector3.new(1.4, 1, 1), origin * CFrame.new(1.2, 6.1, 0.8), Palette.Industrial, DECO_SHADOW)
	animate(make(model, "Drill", Vector3.new(0.5, 2.6, 0.5), origin * CFrame.new(1.2, 3.5, 1.05), Palette.Metal, DECO_SHADOW), "Bob", 0.5)

	-- Blocos cortados empilhados (direita) e na saída.
	make(model, "CutBlock", Vector3.new(1.4, 0.9, 1.1), origin * CFrame.new(2.4, 0.95, -0.5) * CFrame.Angles(0, 0.05, 0), Palette.Rock)
	make(model, "CutBlock", Vector3.new(1.4, 0.9, 1.1), origin * CFrame.new(3.75, 0.95, -0.5) * CFrame.Angles(0, -0.05, 0), Palette.RockDark)
	make(model, "CutBlock", Vector3.new(1.4, 0.9, 1.1), origin * CFrame.new(3.1, 1.85, -0.5), Palette.RockLight, DECO_SHADOW)
	make(model, "Pallet", Vector3.new(2.8, 0.2, 2.1), origin * CFrame.new(2.4, 0.6, -2.6), Palette.PlankDark, DECO)
	make(model, "Output", Vector3.new(2.2, 1.1, 1.6), origin * CFrame.new(2.4, 1.05, -2.6), Palette.Rock)
	for _, x in { 1.9, 2.9 } do
		make(model, "OutputBlock", Vector3.new(0.9, 0.7, 1.2), origin * CFrame.new(x, 1.95, -2.6) * CFrame.Angles(0, (x - 2.4) * 0.3, 0), Palette.RockLight, DECO_SHADOW)
	end

	-- Nível 2: degrau extra (acima), bloco extra na pilha e cintas laranja no pórtico.
	markTier(2, make(model, "TierBlock", Vector3.new(1.4, 0.9, 1.1), origin * CFrame.new(3.1, 2.75, -0.5), Palette.Rock, DECO_SHADOW))
	for _, x in { 0.2, 2.2 } do
		markTier(2, make(model, "TierBand", Vector3.new(0.6, 0.3, 0.6), origin * CFrame.new(x, 1.2, 0.35), Palette.Industrial, DECO))
		markTier(2, make(model, "TierBand", Vector3.new(0.6, 0.3, 0.6), origin * CFrame.new(x, 4.3, 0.35), Palette.IndustrialDark, DECO))
	end
	-- Nível 3: segunda britadeira (pórtico prolongado) e lanterna no pórtico.
	markTier(3, make(model, "TierPost", Vector3.new(0.35, 5.2, 0.35), origin * CFrame.new(-1.4, 3.1, 0.35), Palette.Plank, DECO_SHADOW))
	markTier(3, make(model, "TierBeam", Vector3.new(1.6, 0.4, 1.4), origin * CFrame.new(-0.6, 5.6, 0.8), Palette.PlankDark, DECO_SHADOW))
	markTier(3, animate(make(model, "TierDrill", Vector3.new(0.5, 2.6, 0.5), origin * CFrame.new(-0.7, 3.5, 1.05), Palette.Metal, DECO_SHADOW), "Bob", 0.4))
	markTier(3, make(model, "TierLampArm", Vector3.new(0.15, 0.15, 0.9), origin * CFrame.new(2.2, 4.6, -0.1), Palette.PlankDark, DECO))
	markTier(3, make(model, "TierLamp", Vector3.new(0.55, 0.55, 0.55), origin * CFrame.new(2.2, 4.4, -0.55), Palette.Marker, { Shape = BALL, CanCollide = false, Shadow = false, Material = Enum.Material.Neon }))
	-- Nível 4: ouro no guindaste, bandeira no topo do paredão e veios de minério na rocha.
	markTier(4, make(model, "TierGoldCap", Vector3.new(0.8, 0.25, 0.8), origin * CFrame.new(-3.4, 6.7, 0.3), Palette.Gold, DECO))
	markTier(4, make(model, "TierGoldBand", Vector3.new(0.6, 0.4, 0.6), origin * CFrame.new(-3.4, 6.4, 0.3), Palette.GoldDark, DECO))
	markTier(4, make(model, "TierMast", Vector3.new(0.2, 2.4, 0.2), origin * CFrame.new(0, 6.5, 3.65), Palette.GoldDark, DECO))
	markTier(4, make(model, "TierFlag", Vector3.new(0.08, 1, 1.6), origin * CFrame.new(0, 7.1, 2.85), Palette.BuoyRed, DECO))
	local vein = { CanCollide = false, Shadow = false, Material = Enum.Material.Neon }
	markTier(4, make(model, "TierVein", Vector3.new(1, 0.25, 0.12), origin * CFrame.new(-1.4, 3.5, 2.36) * CFrame.Angles(0, 0, 0.4), Palette.Ore, vein))
	markTier(4, make(model, "TierVein", Vector3.new(0.8, 0.22, 0.12), origin * CFrame.new(1.2, 3.8, 2.36) * CFrame.Angles(0, 0, -0.5), Palette.Ore, vein))
	markTier(4, make(model, "TierCrystal", Vector3.new(0.7, 0.7, 0.7), origin * CFrame.new(-0.8, 5.65, 3.55) * CFrame.Angles(0.7, 0.7, 0), Palette.Ore, vein))
end

-- Carpintaria: oficina coberta com telhado de palha inclinado (um caimento), paredes verde-azuladas,
-- bancada com serra circular, funil de toras na ENTRADA (frente esquerda) e pilha de tábuas na SAÍDA
-- (frente direita). Contrato: Base, Input, Output; Saw gira (Spin); TierSaw gira no nível 3.
-- Níveis (3): 1 base; 2 prateleira de ferramentas e lanternas; 3 segunda serra, topo dourado e flâmulas.
local function buildWorkshop(origin: CFrame, model: Model)
	local base = make(model, "Base", Vector3.new(9, 0.5, 8), origin * CFrame.new(0, 0.25, 0), Palette.WorkshopTrim)
	model.PrimaryPart = base
	for index = 0, 1 do
		make(model, "Deck", Vector3.new(9, 0.1, 3.6), origin * CFrame.new(0, 0.53, -2 + index * 3.8), if index == 0 then Palette.PlankLight else Palette.Plank, { CanCollide = false })
	end

	-- Pátio de trabalho: areia clara com borda de madeira e estacas verde-azuladas.
	make(model, "Yard", Vector3.new(13.4, 0.1, 12.4), origin * CFrame.new(0, 0.05, 0), Palette.WorkshopYard, DECO)
	for _, z in { -6.2, 6.2 } do
		make(model, "YardEdge", Vector3.new(13.8, 0.3, 0.5), origin * CFrame.new(0, 0.15, z), Palette.TrunkDark, DECO)
	end
	for _, x in { -6.7, 6.7 } do
		make(model, "YardEdge", Vector3.new(0.5, 0.3, 12.4), origin * CFrame.new(x, 0.15, 0), Palette.TrunkDark, DECO)
	end
	for _, x in { -6.7, 6.7 } do
		make(model, "YardStake", Vector3.new(0.4, 1.1, 0.4), origin * CFrame.new(x, 0.55, -6.2), Palette.WorkshopWall, DECO)
	end

	-- Estrutura coberta: colunas (frente mais baixa), viga, paredes de fundo e lateral esquerda.
	for _, x in { -4, 4 } do
		make(model, "Column", Vector3.new(0.5, 3.8, 0.5), origin * CFrame.new(x, 2.4, 0.2), Palette.WorkshopTrim)
		make(model, "Column", Vector3.new(0.5, 5.2, 0.5), origin * CFrame.new(x, 3.1, 3.5), Palette.WorkshopTrim)
	end
	make(model, "Header", Vector3.new(8.6, 0.4, 0.4), origin * CFrame.new(0, 4.1, 0.2), Palette.WorkshopTrim, DECO_SHADOW)
	make(model, "BackWall", Vector3.new(7.6, 4.9, 0.25), origin * CFrame.new(0, 2.95, 3.75), Palette.WorkshopWall)
	make(model, "SideWall", Vector3.new(0.25, 3, 3.3), origin * CFrame.new(-3.9, 2, 2), Palette.WorkshopWall)
	make(model, "Window", Vector3.new(1.8, 1.2, 0.1), origin * CFrame.new(0, 3.6, 3.6), Palette.Window, DECO)

	-- Telhado de palha com um caimento (alto atrás, baixo na frente): placa, fiadas, franja e cumeeira.
	local roof = origin * CFrame.new(0, 5.05, 1.65) * CFrame.Angles(-0.32, 0, 0)
	make(model, "Roof", Vector3.new(9.8, 0.4, 5), roof, Palette.ThatchRoof)
	for _, z in { -1.5, 0, 1.5 } do
		make(model, "ThatchRow", Vector3.new(9.9, 0.15, 0.35), roof * CFrame.new(0, 0.27, z), Palette.ThatchDark, DECO)
	end
	make(model, "ThatchFringe", Vector3.new(9.9, 0.55, 0.2), roof * CFrame.new(0, -0.15, -2.5), Palette.ThatchDark, DECO_SHADOW)
	make(model, "Ridge", Vector3.new(9.9, 0.3, 0.5), roof * CFrame.new(0, 0.2, 2.45), Palette.WorkshopTrim, DECO)

	-- Bancada com serra circular (gira), proteção e tábua sendo cortada.
	make(model, "Bench", Vector3.new(6, 0.3, 1.6), origin * CFrame.new(0, 2.05, 2), Palette.Plank)
	for _, x in { -2.6, 2.6 } do
		make(model, "BenchLeg", Vector3.new(0.4, 1.5, 1.4), origin * CFrame.new(x, 1.3, 2), Palette.PlankDark)
	end
	animate(make(model, "Saw", Vector3.new(0.12, 2.4, 2.4), origin * CFrame.new(0.8, 3, 2), Palette.Metal, { Shape = CYLINDER, CanCollide = false }), "Spin", 9)
	make(model, "SawHub", Vector3.new(0.3, 0.6, 0.6), origin * CFrame.new(0.8, 3, 2), Palette.MetalDark, { Shape = CYLINDER, CanCollide = false })
	make(model, "SawGuard", Vector3.new(0.5, 1, 2), origin * CFrame.new(1.2, 4.1, 2), Palette.Industrial, DECO_SHADOW)
	make(model, "CutBoard", Vector3.new(2.2, 0.15, 0.6), origin * CFrame.new(-1.2, 2.3, 2), Palette.PlankLight, DECO)
	make(model, "Sawdust", Vector3.new(1.8, 0.06, 1.3), origin * CFrame.new(0.8, 0.57, 2), Palette.Sawdust, DECO)

	-- Calhas: da entrada até a bancada e da bancada até a saída.
	make(model, "ChuteIn", Vector3.new(1.2, 0.2, 3.2), origin * CFrame.new(-2.7, 1.78, -0.35) * CFrame.Angles(-0.27, 0, 0), Palette.PlankDark, DECO_SHADOW)
	make(model, "ChuteOut", Vector3.new(1.2, 0.2, 3), origin * CFrame.new(2.4, 1.78, -0.2) * CFrame.Angles(-0.18, 0, 0), Palette.PlankLight, DECO_SHADOW)

	-- ENTRADA: caixa de toras com funil (quatro abas inclinadas) e toras para fora.
	make(model, "Input", Vector3.new(2.2, 1.1, 2.2), origin * CFrame.new(-3, 1.05, -2.4), Palette.TrunkDark)
	for _, side in { -1, 1 } do
		make(model, "Funnel", Vector3.new(2.6, 0.15, 0.9), origin * CFrame.new(-3, 1.9, -2.4 + side * 1.1) * CFrame.Angles(-side * 0.6, 0, 0), Palette.WorkshopWall, DECO_SHADOW)
		make(model, "Funnel", Vector3.new(0.9, 0.15, 2.6), origin * CFrame.new(-3 + side * 1.1, 1.9, -2.4) * CFrame.Angles(0, 0, side * 0.6), Palette.WorkshopWall, DECO_SHADOW)
	end
	for _, x in { -3.5, -2.8 } do
		make(model, "InLog", Vector3.new(1.8, 0.7, 0.7), origin * CFrame.new(x, 2.1, -2.4) * CFrame.Angles(0, math.pi / 2, 0), Palette.Trunk, { Shape = CYLINDER, CanCollide = false, Shadow = false })
	end
	make(model, "InLog", Vector3.new(1.8, 0.7, 0.7), origin * CFrame.new(-3.15, 2.65, -2.4) * CFrame.Angles(0, math.pi / 2, 0), Palette.TrunkMid, { Shape = CYLINDER, CanCollide = false, Shadow = false })

	-- SAÍDA: pilha de tábuas aparelhadas, claras e alinhadas, sobre palete.
	make(model, "Pallet", Vector3.new(2.8, 0.2, 1.9), origin * CFrame.new(2.4, 0.6, -2.6), Palette.PlankDark, DECO)
	make(model, "Output", Vector3.new(2.2, 1.1, 1.6), origin * CFrame.new(2.4, 1.05, -2.6), Palette.PlankLight)
	for layer = 0, 2 do
		make(model, "Board", Vector3.new(2.5, 0.2, 1.7), origin * CFrame.new(2.4 + (layer % 2) * 0.12, 1.7 + layer * 0.22, -2.6), if layer % 2 == 0 then Palette.Plank else Palette.PlankLight, DECO)
	end

	-- Nível 2: prateleira de ferramentas na parede e lanternas nas colunas da frente.
	markTier(2, make(model, "TierShelf", Vector3.new(3.2, 0.15, 0.5), origin * CFrame.new(-1.6, 3.9, 3.5), Palette.PlankDark, DECO))
	markTier(2, make(model, "TierTool", Vector3.new(0.5, 0.6, 0.3), origin * CFrame.new(-2.5, 4.3, 3.5), Palette.Industrial, DECO))
	markTier(2, make(model, "TierTool", Vector3.new(0.4, 0.5, 0.4), origin * CFrame.new(-1.6, 4.25, 3.5), Palette.Metal, DECO))
	markTier(2, make(model, "TierTool", Vector3.new(0.5, 0.4, 0.4), origin * CFrame.new(-0.7, 4.2, 3.5), Palette.Plank, DECO))
	for _, x in { -4, 4 } do
		markTier(2, make(model, "TierLamp", Vector3.new(0.55, 0.55, 0.55), origin * CFrame.new(x, 3.5, -0.2), Palette.Marker, { Shape = BALL, CanCollide = false, Shadow = false, Material = Enum.Material.Neon }))
	end
	-- Nível 3: segunda serra (gira), cumeeira dourada e flâmulas penduradas na viga.
	markTier(3, animate(make(model, "TierSaw", Vector3.new(0.1, 1.8, 1.8), origin * CFrame.new(-1.6, 2.95, 2), Palette.Metal, { Shape = CYLINDER, CanCollide = false }), "Spin", -6))
	markTier(3, make(model, "TierSawHub", Vector3.new(0.25, 0.5, 0.5), origin * CFrame.new(-1.6, 2.95, 2), Palette.Industrial, { Shape = CYLINDER, CanCollide = false }))
	markTier(3, make(model, "TierTrim", Vector3.new(10, 0.2, 0.7), roof * CFrame.new(0, 0.42, 2.45), Palette.Gold, DECO))
	for index, x in { -1.8, 0, 1.8 } do
		markTier(3, make(model, "TierPennant", Vector3.new(0.9, 0.9, 0.06), origin * CFrame.new(x, 3.5, -0.2), if index == 2 then Palette.Marker else Palette.Awning, DECO))
	end
end

local STRUCTURES: { [string]: (CFrame, Model) -> () } = {
	Quarry = buildQuarry,
	Workshop = buildWorkshop,
	Fence = buildFence,
	Cabin = buildCabin,
	Sawmill = buildSawmill,
}

-- Cria a estrutura pelo identificador do catálogo (ver Config/Gameplay). Nil se não existir modelo.
function Models.Structure(id: string, origin: CFrame): Model?
	local builder = STRUCTURES[id]
	if builder == nil then
		return nil
	end
	local model = Instance.new("Model")
	builder(origin, model)
	Models.ApplyLevel(model, 1)
	return model
end

-- Mostra as peças de evolução (atributo MinLevel) até o nível dado e esconde as demais.
function Models.ApplyLevel(model: Model, level: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local minLevel = descendant:GetAttribute("MinLevel")
			if type(minLevel) == "number" then
				local visible = level >= minLevel
				descendant.Transparency = if visible then 0 else 1
				descendant.CastShadow = visible
				if descendant.Name == "TierFoundation" then
					descendant.CanCollide = visible
				end
			end
		end
	end
end

function Models.HasStructure(id: string): boolean
	return STRUCTURES[id] ~= nil
end

-- Marcador de ponto de construção: placa redonda, anel e estacas. Devolve o modelo e a placa.
function Models.BuildMarker(origin: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "BuildPoint"
	make(
		model,
		"Ring",
		Vector3.new(0.2, 6.4, 6.4),
		origin * CFrame.new(0, 0.1, 0) * CYLINDER_UP,
		Palette.MarkerRing,
		{ Shape = CYLINDER, CanCollide = false, Shadow = false }
	)
	local pad = make(
		model,
		"Pad",
		Vector3.new(0.24, 5.2, 5.2),
		origin * CFrame.new(0, 0.16, 0) * CYLINDER_UP,
		Palette.Marker,
		{ Shape = CYLINDER, CanCollide = false, Shadow = false, Transparency = 0.15 }
	)
	for _, corner in { Vector2.new(-3, -3), Vector2.new(3, -3), Vector2.new(-3, 3), Vector2.new(3, 3) } do
		make(
			model,
			"Stake",
			Vector3.new(0.3, 1.2, 0.3),
			origin * CFrame.new(corner.X, 0.6, corner.Y),
			Palette.PlankDark,
			{ CanCollide = false, Shadow = false }
		)
	end
	model.PrimaryPart = pad
	return model, pad
end

-- Pedra facetada: bloco base enterrado, bloco girado e duas cunhas, em três tons.
function Models.Rock(origin: CFrame, scale: number, seed: number): Model
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Pedra"
	local root = origin * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	make(
		model,
		"Rock",
		Vector3.new(rng:NextNumber(2, 2.6), rng:NextNumber(1.4, 1.8), rng:NextNumber(1.8, 2.4)) * scale,
		root
			* CFrame.new(0, 0.45 * scale, 0)
			* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 0.6), rng:NextNumber(-0.15, 0.15)),
		Palette.Rock
	)
	make(
		model,
		"Rock",
		Vector3.new(rng:NextNumber(1.2, 1.6), rng:NextNumber(1.2, 1.6), rng:NextNumber(1.2, 1.6)) * scale,
		root
			* CFrame.new(rng:NextNumber(0.5, 0.9) * scale, 1.2 * scale, rng:NextNumber(-0.4, 0.4) * scale)
			* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(-0.5, 0.5)),
		Palette.RockDark
	)
	make(
		model,
		"RockWedge",
		Vector3.new(1.6, 1.3, 1.8) * scale,
		root * CFrame.new(-1.3 * scale, 0.6 * scale, 0.3 * scale) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		Palette.RockLight,
		{ Wedge = true }
	)
	make(
		model,
		"RockWedge",
		Vector3.new(1.1, 0.9, 1.2) * scale,
		root * CFrame.new(0.2 * scale, 0.4 * scale, 1.3 * scale) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		Palette.RockDark,
		{ Wedge = true }
	)
	return model
end

-- Arbusto: três esferas.
function Models.Bush(origin: CFrame, scale: number, seed: number): Model
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Arbusto"
	for index = 1, 3 do
		local radius = rng:NextNumber(1.4, 2.1) * scale
		local offset = Vector3.new(rng:NextNumber(-1, 1), radius * 0.35, rng:NextNumber(-1, 1)) * scale
		make(
			model,
			"Bush",
			Vector3.new(radius, radius, radius),
			origin * CFrame.new(offset),
			if index == 2 then Palette.GrassDark else Palette.Bush,
			{ Shape = BALL, CanCollide = false }
		)
	end
	return model
end

-- Pequeno grupo de flores (caule + flor), sem colisão e sem sombra.
function Models.Flowers(origin: CFrame, seed: number): Model
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Flores"
	local colors = { Palette.FlowerPink, Palette.FlowerYellow, Palette.FlowerWhite }
	for index = 1, 3 do
		local spot = origin * CFrame.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		make(
			model,
			"Stem",
			Vector3.new(0.9, 0.15, 0.15),
			spot * CFrame.new(0, 0.45, 0) * CYLINDER_UP,
			Palette.GrassDark,
			{ Shape = CYLINDER, CanCollide = false, Shadow = false }
		)
		make(
			model,
			"Bloom",
			Vector3.new(0.55, 0.55, 0.55),
			spot * CFrame.new(0, 0.95, 0),
			colors[(index % #colors) + 1],
			{ Shape = BALL, CanCollide = false, Shadow = false }
		)
	end
	return model
end

-- Pedra de caminho (disco achatado).
function Models.SteppingStone(parent: Instance, origin: CFrame, size: number): BasePart
	return make(
		parent,
		"Stone",
		Vector3.new(0.3, size, size),
		origin * CFrame.new(0, 0.05, 0) * CYLINDER_UP,
		Palette.SandWet,
		{ Shape = CYLINDER, CanCollide = false, Shadow = false }
	)
end

-- Placa de madeira com poste. A frente da placa aponta para -Z.
function Models.Sign(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Placa"
	make(model, "Post", Vector3.new(0.5, 3.4, 0.5), origin * CFrame.new(0, 1.7, 0), Palette.PlankDark)
	make(model, "Board", Vector3.new(4.2, 1.8, 0.3), origin * CFrame.new(0, 3, -0.3), Palette.Plank)
	return model
end

-- Píer de tábuas que avança para -Z a partir de `origin` (que fica na borda da praia).
function Models.Dock(origin: CFrame, length: number): Model
	local model = Instance.new("Model")
	model.Name = "Pier"
	local planks = math.floor(length / 1.25)
	for index = 0, planks - 1 do
		make(
			model,
			"Plank",
			Vector3.new(4.6, 0.35, 1.1),
			origin * CFrame.new(0, 0, -index * 1.25),
			if index % 2 == 0 then Palette.Plank else Palette.PlankDark
		)
	end
	for _, z in { 0, -length / 2, -length + 1 } do
		for _, x in { -2.4, 2.4 } do
			make(
				model,
				"Pile",
				Vector3.new(5, 0.6, 0.6),
				origin * CFrame.new(x, -2.2, z) * CYLINDER_UP,
				Palette.PlankDark,
				{ Shape = CYLINDER }
			)
		end
	end
	return model
end

-- Rocha coletável: base escura (fica sempre) e blocos de cima, violeta-acinzentados, com veios
-- dourados nas faces e um cristal (somem enquanto a rocha se recupera). Cascalho na base fica visível.
-- Devolve o modelo, a base (nó de coleta) e as peças de cima.
function Models.MineableRock(origin: CFrame, seed: number): (Model, BasePart, { BasePart })
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Rocha"
	local root = origin * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local base = make(model, "Base", Vector3.new(4.8, 1.4, 4.2), root * CFrame.new(0, 0.5, 0) * CFrame.Angles(0.04, 0.3, -0.04), Palette.OreRockDark)
	local top: { BasePart } = {}
	local function add(part: BasePart): BasePart
		table.insert(top, part)
		return part
	end
	local vein = { CanCollide = false, Shadow = false, Material = Enum.Material.Neon }

	local c1 = add(make(model, "Chunk", Vector3.new(3.2, 2.4, 2.8), root * CFrame.new(-0.3, 2, 0.1) * CFrame.Angles(0.12, 0.7, -0.1), Palette.OreRock))
	local c2 = add(make(model, "Chunk", Vector3.new(2, 1.8, 2), root * CFrame.new(1.2, 3.1, -0.3) * CFrame.Angles(-0.3, 0.2, 0.35), Palette.OreRockLight))
	add(make(model, "ChunkWedge", Vector3.new(1.8, 1.5, 2.2), root * CFrame.new(-1.6, 1.6, 1.1) * CFrame.Angles(0, 2.2, 0), Palette.OreRockLight, { Wedge = true }))
	add(make(model, "ChunkWedge", Vector3.new(1.6, 1.3, 1.8), root * CFrame.new(1.8, 1.4, -1.1) * CFrame.Angles(0, -0.8, 0), Palette.OreRockDark, { Wedge = true }))
	add(make(model, "Chunk", Vector3.new(1.3, 1.2, 1.2), root * CFrame.new(-1.2, 3.3, -0.8) * CFrame.Angles(0.4, 1.1, 0.3), Palette.OreRock))
	-- Veios de minério: lajes finas coladas nas faces dos blocos, legíveis de qualquer lado.
	add(make(model, "Vein", Vector3.new(0.16, 1.1, 0.4), c1.CFrame * CFrame.new(1.62, 0.2, 0.3) * CFrame.Angles(0, 0, 0.5), Palette.Ore, vein))
	add(make(model, "Vein", Vector3.new(0.4, 1, 0.16), c1.CFrame * CFrame.new(-0.5, 0.1, 1.42) * CFrame.Angles(0, 0, -0.6), Palette.Ore, vein))
	add(make(model, "Vein", Vector3.new(0.16, 0.9, 0.5), c1.CFrame * CFrame.new(-1.62, -0.3, -0.2) * CFrame.Angles(0, 0, 0.4), Palette.Ore, vein))
	add(make(model, "Vein", Vector3.new(0.9, 0.3, 0.16), c2.CFrame * CFrame.new(0.2, 0.3, -1.02) * CFrame.Angles(0, 0, 0.3), Palette.Ore, vein))
	-- Cristal de minério no topo.
	add(make(model, "Crystal", Vector3.new(0.6, 0.6, 0.6), c2.CFrame * CFrame.new(0, 0.95, 0) * CFrame.Angles(0.7, 0.7, 0), Palette.Ore, vein))
	-- Cascalho ao redor da base (permanece visível).
	local gravelColors = { Palette.OreRock, Palette.OreRockLight, Palette.OreRockDark }
	for index = 1, 3 do
		local angle = (index / 3) * math.pi * 2 + rng:NextNumber(0, 1)
		local radius = rng:NextNumber(2.8, 3.3)
		local size = rng:NextNumber(0.5, 0.85)
		make(
			model,
			"Gravel",
			Vector3.new(size, size * 0.7, size),
			root * CFrame.new(math.cos(angle) * radius, size * 0.25, math.sin(angle) * radius) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)),
			gravelColors[index],
			{ CanCollide = false, Shadow = false }
		)
	end
	model.PrimaryPart = base
	return model, base, top
end

-- Barraca tropical de feira (frente para -Z): plataforma, balcão, toldo listrado com babado,
-- placa dourada com moeda, mercadorias (toras, pedras), balança, barril e moedas.
-- Devolve o modelo e o balcão (onde fica o prompt de venda).
function Models.MarketStall(origin: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Mercado"
	make(model, "Floor", Vector3.new(7, 0.4, 5), origin * CFrame.new(0, 0.2, 0), Palette.PlankDark)
	make(model, "Step", Vector3.new(3, 0.25, 0.8), origin * CFrame.new(0, 0.12, -2.9), Palette.Plank, { CanCollide = false })
	local counter = make(model, "Counter", Vector3.new(6.4, 2.4, 1.4), origin * CFrame.new(0, 1.6, -1.6), Palette.Plank)
	make(model, "CounterTop", Vector3.new(6.8, 0.25, 1.8), origin * CFrame.new(0, 2.9, -1.6), Palette.PlankDark)
	make(model, "CounterTrim", Vector3.new(6.5, 0.3, 0.1), origin * CFrame.new(0, 2.5, -2.33), Palette.Gold, { CanCollide = false, Shadow = false })
	for _, x in { -3.2, 3.2 } do
		for _, z in { -2.2, 2.2 } do
			make(model, "Post", Vector3.new(0.4, 5.4, 0.4), origin * CFrame.new(x, 2.9, z), Palette.Plank)
		end
	end
	-- Toldo listrado (mais baixo na frente) e babado.
	for index = 0, 7 do
		local x = -3.15 + index * 0.9
		local color = if index % 2 == 0 then Palette.Awning else Palette.UiPanel
		make(model, "Awning", Vector3.new(0.9, 0.2, 5.8), origin * CFrame.new(x, 5.8, 0) * CFrame.Angles(-0.18, 0, 0), color, { CanCollide = false })
		if index > 0 then
			make(model, "Valance", Vector3.new(0.9, 0.5, 0.1), origin * CFrame.new(x, 5.05, -2.85), color, { CanCollide = false, Shadow = false })
		end
	end
	-- Placa dourada com moeda, apoiada no toldo.
	make(model, "SignBoard", Vector3.new(4.4, 1.3, 0.2), origin * CFrame.new(0, 6.5, -2.2) * CFrame.Angles(-0.18, 0, 0), Palette.Gold, { CanCollide = false })
	local signFace = origin * CFrame.new(0, 6.5, -2.2) * CFrame.Angles(-0.18, 0, 0) * CFrame.new(0, 0, -0.14)
	make(model, "CoinRim", Vector3.new(0.12, 1, 1), signFace * CFrame.Angles(0, math.pi / 2, 0), Palette.GoldDark, { Shape = CYLINDER, CanCollide = false, Shadow = false })
	make(model, "Coin", Vector3.new(0.12, 0.8, 0.8), signFace * CFrame.new(0, 0, -0.07) * CFrame.Angles(0, math.pi / 2, 0), Palette.Ore, { Shape = CYLINDER, CanCollide = false, Shadow = false, Material = Enum.Material.Neon })
	-- Mercadorias no balcão: caixote de toras e caixote de pedras.
	make(model, "WoodCrate", Vector3.new(1.5, 0.9, 1.3), origin * CFrame.new(-2.3, 3.5, -1.6), Palette.Plank, { CanCollide = false })
	for index = 0, 1 do
		make(model, "Log", Vector3.new(1.3, 0.55, 0.55), origin * CFrame.new(-2.3, 4.15 + index * 0.1, -1.9 + index * 0.6), Palette.Trunk, { Shape = CYLINDER, CanCollide = false, Shadow = false })
	end
	make(model, "StoneCrate", Vector3.new(1.5, 0.9, 1.3), origin * CFrame.new(-0.6, 3.5, -1.6), Palette.PlankDark, { CanCollide = false })
	make(model, "Stone", Vector3.new(0.8, 0.6, 0.7), origin * CFrame.new(-0.85, 4.1, -1.6) * CFrame.Angles(0, 0.5, 0), Palette.Rock, { CanCollide = false, Shadow = false })
	make(model, "Stone", Vector3.new(0.6, 0.5, 0.6), origin * CFrame.new(-0.3, 4.05, -1.5) * CFrame.Angles(0.2, 1, 0), Palette.RockLight, { CanCollide = false, Shadow = false })
	-- Balança de pratos.
	make(model, "ScaleBase", Vector3.new(0.8, 0.15, 0.5), origin * CFrame.new(1.4, 3.1, -1.6), Palette.MetalDark, { CanCollide = false, Shadow = false })
	make(model, "ScalePole", Vector3.new(0.12, 1.2, 0.12), origin * CFrame.new(1.4, 3.7, -1.6), Palette.Metal, { CanCollide = false, Shadow = false })
	make(model, "ScaleBeam", Vector3.new(1.8, 0.1, 0.1), origin * CFrame.new(1.4, 4.3, -1.6) * CFrame.Angles(0, 0, 0.06), Palette.Metal, { CanCollide = false, Shadow = false })
	for _, x in { 0.5, 2.3 } do
		make(model, "ScalePan", Vector3.new(0.7, 0.1, 0.7), origin * CFrame.new(x, 3.6, -1.6), Palette.Gold, { Shape = CYLINDER, CanCollide = false, Shadow = false })
	end
	-- Pilha de moedas.
	for index = 0, 2 do
		make(model, "CoinStack", Vector3.new(0.14, 0.7, 0.7), origin * CFrame.new(2.8, 3.1 + index * 0.14, -1.6) * CYLINDER_UP, Palette.Ore, { Shape = CYLINDER, CanCollide = false, Shadow = false, Material = Enum.Material.Neon })
	end
	-- Barril e caixote de reserva atrás do balcão.
	make(model, "Barrel", Vector3.new(1.4, 1.2, 1.2), origin * CFrame.new(2.7, 1.1, 1.3) * CYLINDER_UP, Palette.TrunkDark, { Shape = CYLINDER })
	for _, y in { 0.65, 1.55 } do
		make(model, "BarrelHoop", Vector3.new(0.12, 1.25, 1.25), origin * CFrame.new(2.7, y, 1.3) * CYLINDER_UP, Palette.MetalDark, { Shape = CYLINDER, CanCollide = false, Shadow = false })
	end
	make(model, "BackCrate", Vector3.new(1.4, 1.2, 1.4), origin * CFrame.new(-2.6, 1, 1.4) * CFrame.Angles(0, 0.2, 0), Palette.Plank)
	model.PrimaryPart = counter
	return model, counter
end

-- Placa de expansão "terreno à venda": duas estacas, tábua amarela com moldura laranja e moeda,
-- bandeirola e uma seta no topo apontando para trás da placa (onde fica a área nova, +Z local).
-- Devolve o modelo e a tábua "Board" (onde ficam o prompt e o rótulo).
function Models.ExpansionSign(origin: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "PlacaExpansao"
	for _, x in { -2.1, 2.1 } do
		make(model, "Post", Vector3.new(0.5, 5.2, 0.5), origin * CFrame.new(x, 2.6, 0.1), Palette.PlankDark)
	end
	local board = make(model, "Board", Vector3.new(4.6, 2.2, 0.3), origin * CFrame.new(0, 3.7, -0.3), Palette.Marker)
	for _, y in { 4.85, 2.55 } do
		make(model, "Frame", Vector3.new(4.9, 0.25, 0.4), origin * CFrame.new(0, y, -0.32), Palette.Industrial, { CanCollide = false, Shadow = false })
	end
	for _, x in { -2.4, 2.4 } do
		make(model, "Frame", Vector3.new(0.25, 2.2, 0.4), origin * CFrame.new(x, 3.7, -0.32), Palette.Industrial, { CanCollide = false, Shadow = false })
	end
	make(model, "CoinRim", Vector3.new(0.12, 1, 1), origin * CFrame.new(-1.7, 3.7, -0.52) * CFrame.Angles(0, math.pi / 2, 0), Palette.GoldDark, { Shape = CYLINDER, CanCollide = false, Shadow = false })
	make(model, "Coin", Vector3.new(0.12, 0.75, 0.75), origin * CFrame.new(-1.7, 3.7, -0.58) * CFrame.Angles(0, math.pi / 2, 0), Palette.Ore, { Shape = CYLINDER, CanCollide = false, Shadow = false, Material = Enum.Material.Neon })
	-- Seta no topo: haste e dois braços em V, apontando para +Z local (atrás da placa).
	make(model, "ArrowShaft", Vector3.new(0.5, 0.4, 2.6), origin * CFrame.new(0, 5.6, 1.1), Palette.Industrial, { CanCollide = false })
	for _, side in { -1, 1 } do
		make(model, "ArrowHead", Vector3.new(0.5, 0.4, 1.6), origin * CFrame.new(side * 0.55, 5.6, 2.1) * CFrame.Angles(0, -side * 0.75, 0), Palette.Industrial, { CanCollide = false })
	end
	-- Bandeirola e estacas de demarcação.
	make(model, "Pole", Vector3.new(0.15, 3, 0.15), origin * CFrame.new(3.2, 1.5, 0), Palette.PlankDark, { CanCollide = false })
	make(model, "Pennant", Vector3.new(0.06, 0.8, 1.3), origin * CFrame.new(3.2, 2.7, 0.65), Palette.UiBad, { CanCollide = false, Shadow = false })
	for _, x in { -3.3, -2.9 } do
		make(model, "Stake", Vector3.new(0.25, 0.9, 0.25), origin * CFrame.new(x, 0.45, 1.2), Palette.Industrial, { CanCollide = false, Shadow = false })
	end
	model.PrimaryPart = board
	return model, board
end

-- Trecho de passadiço de praia ao longo de +X (4 studs): tábuas no chão, estacas nas bordas, corda e,
-- opcionalmente, tochas nas duas bordas. `endPost` fecha o trecho com estacas em x = 4.
-- Tudo sem colisão: o centro fica livre e a passagem não é bloqueada.
function Models.BoardwalkSegment(origin: CFrame, torches: boolean, endPost: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Passadico"
	for index = 0, 3 do
		make(
			model,
			"Plank",
			Vector3.new(0.95, 0.18, 3.2),
			origin * CFrame.new(index + 0.5, 0.12, 0),
			if index % 2 == 0 then Palette.Plank else Palette.PlankDark,
			{ CanCollide = false, Shadow = false }
		)
	end
	local posts = if endPost then { 0, 4 } else { 0 }
	for _, side in { -1.9, 1.9 } do
		for _, x in posts do
			local tall = torches and x == 0
			local height = if tall then 2 else 1.3
			make(model, "Post", Vector3.new(0.3, height, 0.3), origin * CFrame.new(x, height / 2, side), Palette.PlankDark, { CanCollide = false, Shadow = false })
			if tall then
				make(model, "TorchBowl", Vector3.new(0.5, 0.25, 0.5), origin * CFrame.new(x, 2.05, side), Palette.MetalDark, { CanCollide = false, Shadow = false })
				make(model, "TorchFlame", Vector3.new(0.45, 0.45, 0.45), origin * CFrame.new(x, 2.4, side), Palette.Industrial, { Shape = BALL, CanCollide = false, Shadow = false, Material = Enum.Material.Neon })
			end
		end
		make(model, "Rope", Vector3.new(4, 0.1, 0.1), origin * CFrame.new(2, 1.05, side), Palette.RopeFiber, { CanCollide = false, Shadow = false })
	end
	return model
end

-- Planta de praia: roseta de folhas longas e inclinadas para fora (sem colisão).
function Models.BeachPlant(origin: CFrame, seed: number): Model
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "PlantaPraia"
	local colors = { Palette.Leaf, Palette.LeafLight, Palette.GrassDark }
	for index = 1, 5 do
		local yaw = (index / 5) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		make(
			model,
			"Blade",
			Vector3.new(0.3, 0.08, rng:NextNumber(1.3, 1.8)),
			origin * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.6, -0.55) * CFrame.Angles(0.65, 0, 0),
			colors[(index % 3) + 1],
			{ CanCollide = false, Shadow = false }
		)
	end
	return model
end

-- Boia flutuante: bola turquesa com faixa clara e topo vermelho (marca o contorno de uma área).
function Models.Buoy(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Boia"
	make(model, "Float", Vector3.new(1.4, 1.4, 1.4), origin, Palette.Awning, { Shape = BALL, CanCollide = false })
	make(model, "Band", Vector3.new(0.5, 1.5, 1.5), origin * CYLINDER_UP, Palette.UiPanel, { Shape = CYLINDER, CanCollide = false, Shadow = false })
	make(model, "Top", Vector3.new(0.5, 0.5, 0.5), origin * CFrame.new(0, 0.85, 0), Palette.BuoyRed, { Shape = BALL, CanCollide = false, Shadow = false })
	return model
end

return Models
