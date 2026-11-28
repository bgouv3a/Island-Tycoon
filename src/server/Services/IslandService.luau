--!strict
--[[
	IslandService: atribui uma ilha exclusiva a cada jogador, cria o mundo da ilha (palmeiras,
	rochas, mercado, placa de expansão) e processa a coleta manual.

	O cliente só pede "coletar o nó X". Dono da ilha, cooldown, alcance e saldo são decididos
	aqui. O saldo é alterado somente por DataService.Mutate.
	Ao sair, a ilha volta a ficar livre: os nós são reiniciados e as expansões voltam ao mar.

	Expansões: SetExpansion molda a área nova (o gramado sobe do mar), cria os nós e a decoração
	dela e esconde a placa de compra. Quem decide e salva a compra é o ExpansionService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Economy = require(Shared.Config.Economy)
local Collect = require(Shared.Logic.Collect)
local IslandAllocator = require(Shared.Logic.IslandAllocator)
local ResourceLedger = require(Shared.Logic.ResourceLedger)
local Stats = require(Shared.Logic.Stats)
local Validate = require(Shared.Logic.Validate)
local Models = require(Shared.Art.Models)
local Palette = require(Shared.Art.Palette)
local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local Environment = require(script.Parent.Parent.World.Environment)
local IslandDecor = require(script.Parent.Parent.World.IslandDecor)

type NodeKind = "Tree" | "Rock"

type Node = {
	Id: string,
	Slot: number,
	Kind: NodeKind,
	Base: BasePart, -- base do nó: guarda o NodeId e o prompt, e mede o alcance
	Top: { BasePart }, -- copa (palmeira) ou blocos de cima (rocha): somem enquanto se recupera
	Prompt: ProximityPrompt,
	ReadyAt: number, -- instante (os.clock) em que o nó volta a dar recurso
}

type NodeSpot = { Kind: NodeKind, Offset: Vector2 }

type ExpansionState = {
	Unlocked: boolean,
	Token: number, -- muda a cada liberação/bloqueio: cancela uma animação em andamento
	Folder: Folder?,
	Nodes: { Node },
}

-- Palmeiras dentro da ilha (X, Z), relativas ao centro: no fundo e nas laterais, longe da
-- clareira de construção. A altura vem do terreno. A ordem define os identificadores (S1T1...).
local TREE_OFFSETS: { Vector2 } = {
	Vector2.new(-22, -14),
	Vector2.new(-11, -23),
	Vector2.new(3, -25),
	Vector2.new(17, -21),
	Vector2.new(25, -13),
	Vector2.new(-27, 8),
}
-- Rochas coletáveis da ilha principal (S1R1...), na borda da clareira e nas praias laterais.
local ROCK_OFFSETS: { Vector2 } = {
	Vector2.new(-3, -19),
	Vector2.new(29, 6),
	Vector2.new(-31, -6),
}
-- Nós de cada expansão (S1E1T1, S1E1R1...).
local EXPANSION_NODES: { [string]: { NodeSpot } } = {
	E1 = {
		{ Kind = "Tree", Offset = Vector2.new(51, 4) },
		{ Kind = "Tree", Offset = Vector2.new(73, 2) },
		{ Kind = "Rock", Offset = Vector2.new(60, -18) },
		{ Kind = "Rock", Offset = Vector2.new(75, -6) },
	},
}
local NODE_LETTER: { [NodeKind]: string } = { Tree = "T", Rock = "R" }
local NODE_NAMES: { [NodeKind]: string } = { Tree = "Palmeira", Rock = "Rocha" }

local MAX_NODE_ID_LENGTH = 32
local OCEAN_MARGIN = 320 -- água além das ilhas da borda, em studs
local RISE_STEP_SECONDS = 0.35 -- intervalo entre as etapas da subida da área nova

local allocator = IslandAllocator.new(Gameplay.Islands.MaxPerServer)
local origins: { [number]: Vector3 } = {}
local models: { [number]: Model } = {}
local platforms: { [number]: BasePart } = {}
local labels: { [number]: BillboardGui } = {}
local markets: { [number]: BasePart } = {}
local signs: { [number]: { [string]: Model } } = {} -- slot → expansão → placa e boias
local expansions: { [number]: { [string]: ExpansionState } } = {}
local nodes: { [string]: Node } = {}
local nodesBySlot: { [number]: { Node } } = {}
local collectedRemote: RemoteEvent? = nil
local changedRemote: RemoteEvent? = nil
local initialized = false

local IslandService = {}

-- Centro da ilha na grade, na altura de referência do terreno (y = 0). A origem usada pelo jogo
-- (origins) tem a altura real do chão, medida depois que o terreno é moldado.
local function originFor(slot: number): Vector3
	local index = slot - 1
	local column = index % Gameplay.Islands.Columns
	local row = math.floor(index / Gameplay.Islands.Columns)
	return Vector3.new(column * Gameplay.Islands.Spacing, 0, row * Gameplay.Islands.Spacing)
end

-- Mostra ou esconde a parte de cima. O atributo Ready permite ao cliente guiar o jogador até nós prontos.
local function setAvailable(node: Node, available: boolean)
	node.Prompt.Enabled = available
	for _, part in node.Top do
		part.Transparency = if available then 0 else 1
	end
	node.Base:SetAttribute("Ready", available)
end

local function buildNode(slot: number, kind: NodeKind, id: string, offset: Vector2, origin: Vector3, parent: Instance, seed: number): Node
	local x, z = origin.X + offset.X, origin.Z + offset.Y
	local y = Environment.GroundY(x, z, origin.Y)
	local model: Model, base: BasePart, top: { BasePart }
	if kind == "Tree" then
		model, base, top = Models.PalmTree(CFrame.new(x, y - 0.3, z), seed)
	else
		model, base, top = Models.MineableRock(CFrame.new(x, y - 0.2, z), seed)
	end
	local config = Economy.Nodes[kind]
	local resourceName = Economy.Resources[config.ResourceId].Name

	base:SetAttribute("NodeId", id)
	base:SetAttribute("NodeKind", kind)
	base:SetAttribute("IslandSlot", slot)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ObjectText = NODE_NAMES[kind]
	prompt.ActionText = "Coletar " .. resourceName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = config.ReachStuds
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, if kind == "Tree" then 40 else 20)
	prompt.Parent = base

	model.Parent = parent

	local node: Node = {
		Id = id,
		Slot = slot,
		Kind = kind,
		Base = base,
		Top = top,
		Prompt = prompt,
		ReadyAt = 0,
	}
	setAvailable(node, true)
	nodes[id] = node
	return node
end

-- Placa de compra e boias que contornam a área de cada expansão ainda não liberada.
local function buildExpansionTeasers(slot: number, origin: Vector3, model: Model)
	local list: { [string]: Model } = {}
	local states: { [string]: ExpansionState } = {}
	for area, shape in Gameplay.Expansions do
		local holder = Instance.new("Model")
		holder.Name = "Expansao" .. area

		local signX, signZ = origin.X + shape.Sign.X, origin.Z + shape.Sign.Y
		local signY = Environment.GroundY(signX, signZ, origin.Y)
		local center = Vector3.new(origin.X + shape.Center.X, signY, origin.Z + shape.Center.Y)
		-- A placa fica de frente para a ilha principal (frente = -Z do modelo, ver Art/Models).
		local signCFrame = CFrame.lookAt(Vector3.new(signX, signY, signZ), Vector3.new(signX - 1, signY, signZ))
		local sign, board = Models.ExpansionSign(signCFrame)
		sign.Parent = holder
		board:SetAttribute("Area", area)

		local cost = Economy.Expansions[area].Cost
		local parts: { string } = {}
		for _, resourceId in { "Coins", "Wood", "Stone" } do
			local amount = cost[resourceId]
			if amount ~= nil then
				table.insert(parts, `{amount} {Economy.Resources[resourceId].Name}`)
			end
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ExpandPrompt"
		prompt.ObjectText = `{Economy.Expansions[area].Name}: {table.concat(parts, ", ")}`
		prompt.ActionText = "Expandir ilha"
		prompt.HoldDuration = 0.6 -- segurar: compra cara não acontece por acidente
		prompt.MaxActivationDistance = shape.ReachStuds
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Area", area)
		prompt.Parent = board

		-- Boias no contorno da futura área, na linha da água.
		local ring = shape.Radius + 4
		for index = 1, 10 do
			local angle = index / 10 * math.pi * 2
			local position = center + Vector3.new(math.cos(angle) * ring, 0, math.sin(angle) * ring)
			Models.Buoy(CFrame.new(position.X, -1.6, position.Z)).Parent = holder
		end

		holder.Parent = model
		list[area] = holder
		states[area] = { Unlocked = false, Token = 0, Folder = nil, Nodes = {} }
	end
	signs[slot] = list
	expansions[slot] = states
end

local function setTeaserVisible(slot: number, area: string, visible: boolean)
	local holder = signs[slot] and signs[slot][area]
	if holder == nil then
		return
	end
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("BaseTransparency") == nil then
				descendant:SetAttribute("BaseTransparency", descendant.Transparency)
				descendant:SetAttribute("BaseCollide", descendant.CanCollide)
			end
			local base = descendant:GetAttribute("BaseTransparency")
			descendant.Transparency = if visible and type(base) == "number" then base else 1
			descendant.CanCollide = visible and descendant:GetAttribute("BaseCollide") == true
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = visible
		end
	end
	holder:SetAttribute("Unlocked", not visible)
end

local function buildMarket(slot: number, origin: Vector3, model: Model)
	local offset = Gameplay.Market.Offset
	local x, z = origin.X + offset.X, origin.Z + offset.Y
	local y = Environment.GroundY(x, z, origin.Y)
	-- Balcão de frente para o caminho do píer (x = 0).
	local cframe = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(origin.X, y, z))
	local stall, counter = Models.MarketStall(cframe)
	counter:SetAttribute("Market", true)
	counter:SetAttribute("IslandSlot", slot)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ObjectText = "Mercado do píer"
	prompt.ActionText = "Vender recursos"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Economy.Market.ReachStuds
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	stall.Parent = model
	markets[slot] = counter
end

local function buildIsland(slot: number, parent: Folder)
	-- Altura real do chão na clareira (o Terrain arredonda a superfície).
	local grid = originFor(slot)
	local origin = Vector3.new(grid.X, Environment.GroundY(grid.X, grid.Z - 3, grid.Y), grid.Z)
	origins[slot] = origin

	local model = Instance.new("Model")
	model.Name = "Ilha" .. slot
	models[slot] = model

	-- Pasta usada pelo BuildService para as estruturas construídas nesta ilha.
	local builds = Instance.new("Folder")
	builds.Name = "Builds"
	builds.Parent = model

	-- Decoração (o relevo já foi moldado no Init). A âncora da placa recebe o nome do dono.
	platforms[slot] = IslandDecor.Build(model, origin, slot)

	local list: { Node } = {}
	for index, offset in TREE_OFFSETS do
		table.insert(list, buildNode(slot, "Tree", `S{slot}T{index}`, offset, origin, model, slot * 100 + index))
	end
	for index, offset in ROCK_OFFSETS do
		table.insert(list, buildNode(slot, "Rock", `S{slot}R{index}`, offset, origin, model, slot * 200 + index))
	end
	nodesBySlot[slot] = list

	buildMarket(slot, origin, model)
	buildExpansionTeasers(slot, origin, model)

	model.Parent = parent
end

-- Reinicia os nós de uma ilha (usado quando ela é liberada).
local function resetSlot(slot: number)
	for _, node in nodesBySlot[slot] or {} do
		node.ReadyAt = 0
		setAvailable(node, true)
	end
end

local function setLabel(slot: number, text: string?)
	local existing = labels[slot]
	if existing ~= nil then
		existing:Destroy()
		labels[slot] = nil
	end
	local platform = platforms[slot]
	if text == nil or platform == nil then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "OwnerLabel"
	gui.Size = UDim2.fromScale(10, 2.2)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	gui.Adornee = platform

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Palette.UiPanel
	label.BackgroundTransparency = 0.05
	label.TextColor3 = Palette.UiText
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.UiAccentDark
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label

	gui.Parent = platform
	labels[slot] = gui
end

local function placeCharacter(player: Player, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local slot = IslandAllocator.GetSlot(allocator, player.UserId)
		if root == nil or not root:IsA("BasePart") or slot == nil then
			return
		end
		if player.Character ~= character then
			return -- o personagem mudou enquanto esperava
		end
		local origin = origins[slot]
		if origin ~= nil then
			-- Chega pela frente da ilha, olhando para a clareira de construção e as palmeiras.
			local spawn = origin + Gameplay.Islands.SpawnOffset
			local facing = Vector3.new(origin.X, spawn.Y, origin.Z - 4)
			local rootPart = root :: BasePart
			rootPart.CFrame = CFrame.lookAt(spawn, facing)
		end
	end)
end

local function sendSnapshot(player: Player)
	local remote = changedRemote
	local data = DataService.GetData(player)
	if remote == nil or data == nil then
		return
	end
	remote:FireClient(player, data.Resources)
end

-- Remove a área de uma expansão (nós, decoração e terreno) e mostra a placa de compra de novo.
local function lockExpansion(slot: number, area: string)
	local state = expansions[slot] and expansions[slot][area]
	local shape = Gameplay.Expansions[area]
	if state == nil or shape == nil or not state.Unlocked then
		return
	end
	state.Unlocked = false
	state.Token += 1
	for _, node in state.Nodes do
		nodes[node.Id] = nil
	end
	state.Nodes = {}
	if state.Folder ~= nil then
		state.Folder:Destroy()
		state.Folder = nil
	end
	Environment.ClearExpansion(originFor(slot), shape)
	-- Recria a ilha principal com a mesma semente: o corte da faixa não deixa marcas na praia.
	Environment.ShapeIsland(originFor(slot), Random.new(slot))
	setTeaserVisible(slot, area, true)
end

local function onPlayerAdded(player: Player)
	local slot = IslandAllocator.Assign(allocator, player.UserId)
	if slot == nil then
		warn(`[IslandService] Sem ilha livre para o jogador {player.UserId}`)
		player:Kick("Este servidor está cheio. Tente entrar novamente em instantes.")
		return
	end

	setLabel(slot, `Ilha de {player.DisplayName}`)
	-- Identifica o dono no modelo (público): o cliente só abre a construção na própria ilha.
	local model = models[slot]
	if model ~= nil then
		model:SetAttribute("OwnerUserId", player.UserId)
	end
	player.CharacterAdded:Connect(function(character: Model)
		placeCharacter(player, character)
	end)
	if player.Character ~= nil then
		placeCharacter(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local slot = IslandAllocator.Release(allocator, player.UserId)
	if slot == nil then
		return
	end
	setLabel(slot, nil)
	resetSlot(slot)
	for area in expansions[slot] or {} do
		lockExpansion(slot, area)
	end
	local model = models[slot]
	if model ~= nil then
		model:SetAttribute("OwnerUserId", nil)
	end
end

local function handleCollect(player: Player, nodeId: string)
	if not DataService.IsLoaded(player) then
		return
	end

	local node = nodes[nodeId]
	if node == nil then
		return
	end

	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end

	local config = Economy.Nodes[node.Kind]
	local now = os.clock()
	local result = Collect.Evaluate({
		OwnerSlot = IslandAllocator.GetSlot(allocator, player.UserId),
		NodeSlot = node.Slot,
		ReadyAt = node.ReadyAt,
		Now = now,
		Distance = ((root :: BasePart).Position - node.Base.Position).Magnitude,
		Reach = config.ReachStuds,
	})
	if result ~= "Ok" then
		return
	end

	local amount = config.Amount
	local saved = DataService.Mutate(player, function(data)
		local resources = data.Resources
		if type(resources) ~= "table" or not ResourceLedger.Add(resources, config.ResourceId, amount) then
			error("saldo de recursos inválido")
		end
		Stats.Add(data, config.ResourceId .. "Collected", amount)
	end)
	if not saved then
		return
	end

	local cooldown = config.CooldownSeconds
	node.ReadyAt = now + cooldown
	setAvailable(node, false)
	task.delay(cooldown, function()
		if os.clock() >= node.ReadyAt and nodes[node.Id] == node then
			setAvailable(node, true)
		end
	end)

	local collected = collectedRemote
	if collected ~= nil then
		collected:FireClient(player, nodeId, amount, config.ResourceId, cooldown)
	end
	sendSnapshot(player)
end

local function validateNodeId(nodeId: any): boolean
	return Validate.IsString(nodeId, MAX_NODE_ID_LENGTH)
end

-- Envia o saldo atual ao cliente (usado também por outros serviços após uma mudança de saldo).
function IslandService.SendSnapshot(player: Player)
	sendSnapshot(player)
end

-- Slot da ilha do jogador (nil se não tiver uma).
function IslandService.GetSlot(player: Player): number?
	return IslandAllocator.GetSlot(allocator, player.UserId)
end

function IslandService.GetOrigin(slot: number): Vector3?
	return origins[slot]
end

function IslandService.GetIsland(slot: number): Model?
	return models[slot]
end

-- Balcão do mercado da ilha (mede o alcance da venda).
function IslandService.GetMarket(slot: number): BasePart?
	return markets[slot]
end

-- Placa de compra de uma expansão da ilha (mede o alcance da compra).
function IslandService.GetExpansionSign(slot: number, area: string): BasePart?
	local holder = signs[slot] and signs[slot][area]
	local board = if holder ~= nil then holder:FindFirstChild("Board", true) else nil
	return if board ~= nil and board:IsA("BasePart") then board else nil
end

function IslandService.IsExpansionShown(slot: number, area: string): boolean
	local state = expansions[slot] and expansions[slot][area]
	return state ~= nil and state.Unlocked
end

-- Mostra a área de uma expansão na ilha: molda o terreno (subindo do mar se `animate`), cria
-- os nós e a decoração e esconde a placa. Pode esperar (yield) durante a animação.
-- Devolve false se a área foi bloqueada de novo no meio (o jogador saiu).
function IslandService.ShowExpansion(slot: number, area: string, animate: boolean): boolean
	local state = expansions[slot] and expansions[slot][area]
	local shape = Gameplay.Expansions[area]
	local model = models[slot]
	local origin = origins[slot]
	if state == nil or shape == nil or model == nil or origin == nil or state.Unlocked then
		return false
	end
	state.Unlocked = true
	state.Token += 1
	local token = state.Token
	local function stillValid(): boolean
		return state.Unlocked and state.Token == token
	end
	setTeaserVisible(slot, area, false)

	local finished = Environment.ShapeExpansion(originFor(slot), shape, Random.new(slot * 7), function(): boolean
		if animate then
			task.wait(RISE_STEP_SECONDS)
		end
		return stillValid()
	end)
	if not finished or not stillValid() then
		return false
	end
	local center = origin + Vector3.new(shape.Center.X, 0, shape.Center.Y)
	Environment.WaitForGround(center, 3)
	if not stillValid() then
		return false
	end

	local folder = Instance.new("Folder")
	folder.Name = "Area" .. area
	local counts: { [NodeKind]: number } = { Tree = 0, Rock = 0 }
	for _, spot in EXPANSION_NODES[area] or {} do
		counts[spot.Kind] += 1
		local id = `S{slot}{area}{NODE_LETTER[spot.Kind]}{counts[spot.Kind]}`
		table.insert(state.Nodes, buildNode(slot, spot.Kind, id, spot.Offset, origin, folder, slot * 300 + #state.Nodes))
	end
	IslandDecor.BuildExpansion(folder, origin, area, slot)
	folder.Parent = model
	state.Folder = folder
	return true
end

function IslandService.Init()
	assert(not initialized, "IslandService.Init chamado mais de uma vez")
	initialized = true

	-- Ambiente: iluminação, peças do template e oceano cobrindo toda a grade de ilhas.
	Environment.ConfigureLighting()
	Environment.HideTemplateParts()
	local lastOrigin = originFor(Gameplay.Islands.MaxPerServer)
	local farX = math.max(lastOrigin.X, (Gameplay.Islands.Columns - 1) * Gameplay.Islands.Spacing)
	Environment.FillOcean(
		Vector2.new(-OCEAN_MARGIN, -OCEAN_MARGIN),
		Vector2.new(farX + OCEAN_MARGIN, lastOrigin.Z + OCEAN_MARGIN)
	)

	-- Relevo de todas as ilhas primeiro; os objetos só são posicionados quando o terreno já
	-- responde a raycasts (palmeiras e decoração seguem a altura real do chão).
	for slot = 1, Gameplay.Islands.MaxPerServer do
		Environment.ShapeIsland(originFor(slot), Random.new(slot))
	end
	if not Environment.WaitForGround(originFor(1), 5) then
		warn("[IslandService] Terreno não respondeu a tempo; objetos usarão a altura padrão do chão")
	end

	local folder = Instance.new("Folder")
	folder.Name = "Islands"
	folder.Parent = Workspace
	for slot = 1, Gameplay.Islands.MaxPerServer do
		buildIsland(slot, folder)
	end

	collectedRemote = NetService.CreateOutgoing("ResourceCollected")
	changedRemote = NetService.CreateOutgoing("ResourcesChanged")

	NetService.Register("CollectResource", validateNodeId, handleCollect, {
		Capacity = Gameplay.Remotes.CollectCapacity,
		RefillPerSecond = Gameplay.Remotes.CollectRefillPerSecond,
	})
	NetService.Register("RequestResources", function(): boolean
		return true
	end, function(player: Player)
		sendSnapshot(player)
	end, {
		Capacity = Gameplay.Remotes.RequestCapacity,
		RefillPerSecond = Gameplay.Remotes.RequestRefillPerSecond,
	})

	DataService.OnLoaded(sendSnapshot)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return IslandService
