--!strict
--[[
	ProductionService: construções produtivas (ex.: Serraria) na ilha do próprio jogador.

	- Um relógio único no servidor avança a produção de quem está conectado e com perfil carregado.
	  O progresso fica só na memória e começa do zero a cada sessão: não há produção offline.
	- O estoque é salvo no perfil (Storage) e alterado somente por DataService.Mutate.
	- O cliente só pede "recolher o ponto X" ou "melhorar o ponto X". Dono, alcance, estoque, custo
	  e saldo são decididos aqui (Logic/Production e Logic/Upgrade), cada pedido em uma única
	  mutação: não há como recolher o mesmo estoque duas vezes nem pagar uma melhoria duas vezes.
	- Melhorias: nível por ponto no perfil (Levels). O nível muda a regra de produção e a aparência
	  da máquina (Art/Models.ApplyLevel).
	- As estruturas vêm do BuildService (OnPlaced/GetStructure). Este serviço só publica o estado
	  no modelo (atributos Stored, Capacity, Full, Amount, IntervalSeconds, Level, MaxLevel) e cria
	  os prompts de coleta e de melhoria.
	- Máquinas que processam (ex.: Carpintaria, Gameplay.Production.Producers[..].Input) têm estoque
	  de entrada salvo (Inputs). O jogador abastece com SupplyProducer; cada ciclo consome a
	  matéria-prima no mesmo passo em que produz (Production.StepConverter). Sem matéria-prima ou
	  sem espaço, a máquina para (atributos Starved/Full).
	- Custo: o relógio lê o perfil sem copiar (DataService.Read) e faz no máximo uma mutação por
	  jogador e por passo, só quando algo foi produzido, qualquer que seja o número de máquinas.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Economy = require(Shared.Config.Economy)
local Production = require(Shared.Logic.Production)
local Upgrade = require(Shared.Logic.Upgrade)
local Stats = require(Shared.Logic.Stats)
local Validate = require(Shared.Logic.Validate)
local Models = require(Shared.Art.Models)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local BuildService = require(script.Parent.BuildService)
local NetService = require(script.Parent.NetService)

local MAX_ID_LENGTH = 32
local MAX_TICK_SECONDS = 10 -- passo máximo do relógio (evita saltos após uma pausa do servidor)

local PRODUCERS: Upgrade.Producers = Gameplay.Production.Producers

local ProductionService = {}

local initialized = false
local resultRemote: RemoteEvent? = nil
local upgradeRemote: RemoteEvent? = nil
local supplyRemote: RemoteEvent? = nil
-- Progresso (segundos) até a próxima unidade, por jogador e ponto. Só memória.
local progress: { [Player]: { [string]: number } } = {}

-- Peça onde ficam o prompt e o indicador: "Output" no modelo, ou a peça principal.
local function outputPart(model: Model): BasePart?
	local output = model:FindFirstChild("Output", true)
	if output ~= nil and output:IsA("BasePart") then
		return output
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function ownerOf(slot: number): Player?
	for _, player in Players:GetPlayers() do
		if IslandService.GetSlot(player) == slot then
			return player
		end
	end
	return nil
end

-- Regra de produção do ponto no nível salvo, o nível e o nível máximo (nil se não for produtor).
local function siteRule(data: { [string]: any }, siteId: string): (Production.Rule?, number, number)
	local buildings = data.Buildings
	local structureId = if type(buildings) == "table" then buildings[siteId] else nil
	local producer = if type(structureId) == "string" then PRODUCERS[structureId] else nil
	if producer == nil then
		return nil, 0, 0
	end
	local level = Upgrade.Level(data.Levels, siteId, #producer.Levels)
	return Upgrade.RuleFor(producer, level), level, #producer.Levels
end

-- Publica o estado no modelo: o cliente desenha a barra, o nível e o aviso de cheio a partir disso.
local function publish(model: Model, stored: number, input: number, rule: Production.Rule, level: number, maxLevel: number)
	model:SetAttribute("Stored", stored)
	model:SetAttribute("Capacity", rule.Capacity)
	-- Máquina que processa só roda com espaço para um ciclo inteiro; as outras enchem até o limite.
	model:SetAttribute("Full", if rule.InputId ~= nil then stored + rule.Amount > rule.Capacity else stored >= rule.Capacity)
	model:SetAttribute("OutputId", rule.ResourceId)
	if rule.InputId ~= nil then
		model:SetAttribute("InputId", rule.InputId)
		model:SetAttribute("Input", input)
		model:SetAttribute("InputCapacity", rule.InputCapacity)
		model:SetAttribute("InputAmount", rule.InputAmount)
		model:SetAttribute("Starved", input < (rule.InputAmount or 0))
	end
	model:SetAttribute("Amount", rule.Amount)
	model:SetAttribute("IntervalSeconds", rule.IntervalSeconds)
	model:SetAttribute("MaxLevel", maxLevel)
	if model:GetAttribute("Level") ~= level then
		model:SetAttribute("Level", level)
		Models.ApplyLevel(model, level)
	end
	local part = outputPart(model)
	local prompt = if part ~= nil then part:FindFirstChild("HarvestPrompt") else nil
	if prompt ~= nil and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = stored > 0
		prompt.ActionText = `Recolher {stored} de {Economy.Resources[rule.ResourceId].Name}`
	end
	local hopper = model:FindFirstChild("Input", true)
	local supply = if hopper ~= nil then hopper:FindFirstChild("SupplyPrompt") else nil
	if supply ~= nil and supply:IsA("ProximityPrompt") and rule.InputCapacity ~= nil then
		supply.Enabled = input < rule.InputCapacity
	end
	local base = model.PrimaryPart
	local upgrade = if base ~= nil then base:FindFirstChild("UpgradePrompt") else nil
	if upgrade ~= nil and upgrade:IsA("ProximityPrompt") then
		upgrade.ActionText = if level >= maxLevel then "Nível máximo" else `Melhorar (nível {level + 1})`
	end
end

local function publishFor(player: Player, siteId: string)
	local slot = IslandService.GetSlot(player)
	local model = if slot ~= nil then BuildService.GetStructure(slot, siteId) else nil
	if model == nil then
		return
	end
	DataService.Read(player, function(data)
		local rule, level, maxLevel = siteRule(data, siteId)
		if rule ~= nil then
			publish(model, Production.Stored(data.Storage, siteId, rule), Production.Input(data.Inputs, siteId, rule), rule, level, maxLevel)
		end
		return true
	end)
end

local function addPrompt(part: BasePart, name: string, objectText: string, siteId: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Gameplay.Production.ReachStuds
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("SiteId", siteId)
	prompt.Parent = part
	return prompt
end

local function onPlaced(slot: number, siteId: string, structureId: string, model: Model)
	local producer = PRODUCERS[structureId]
	if producer == nil then
		return
	end
	model:SetAttribute("Producer", structureId)
	local name = Gameplay.Build.Structures[structureId].Name

	local part = outputPart(model)
	if part ~= nil and part:FindFirstChild("HarvestPrompt") == nil then
		local prompt = addPrompt(part, "HarvestPrompt", name, siteId)
		prompt.ActionText = "Recolher"
		prompt.Enabled = false
	end
	-- Melhoria: o prompt só abre o painel no cliente; a compra é o pedido UpgradeProducer.
	local base = model.PrimaryPart
	if base ~= nil and base:FindFirstChild("UpgradePrompt") == nil then
		local prompt = addPrompt(base, "UpgradePrompt", name, siteId)
		prompt.ActionText = "Melhorar"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.UIOffset = Vector2.new(0, 72)
	end

	-- Abastecimento: o prompt abre o painel no cliente; o pedido é SupplyProducer.
	local hopper = model:FindFirstChild("Input", true)
	if producer.Input ~= nil and hopper ~= nil and hopper:IsA("BasePart") and hopper:FindFirstChild("SupplyPrompt") == nil then
		local prompt = addPrompt(hopper, "SupplyPrompt", name, siteId)
		prompt.ActionText = `Abastecer com {Economy.Resources[producer.Input.ResourceId].Name}`
		prompt.KeyboardKeyCode = Enum.KeyCode.G
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.UIOffset = Vector2.new(0, -72)
	end

	publish(model, 0, 0, Upgrade.RuleFor(producer, 1), 1, #producer.Levels)
	local owner = ownerOf(slot)
	if owner ~= nil then
		publishFor(owner, siteId)
	end
end

-- Limpa o estoque salvo ao carregar: só pontos com produtor e valores válidos para o nível.
local function onLoaded(player: Player)
	DataService.Mutate(player, function(data)
		local clean: Production.Storage = {}
		local inputs: { [string]: number } = {}
		for siteId, rule in Upgrade.SiteRules(data.Buildings, data.Levels, PRODUCERS) do
			clean[siteId] = Production.Stored(data.Storage, siteId, rule)
			if rule.InputId ~= nil then
				inputs[siteId] = Production.Input(data.Inputs, siteId, rule)
			end
		end
		data.Storage = clean
		data.Inputs = inputs
	end)
	if player.Parent ~= Players then
		return -- saiu durante o carregamento: não cria estado que nunca seria limpo
	end
	progress[player] = {}
	local sites = DataService.Read(player, function(data)
		local list: { string } = {}
		for siteId in data.Storage do
			table.insert(list, siteId)
		end
		return list
	end)
	for _, siteId in sites or {} do
		publishFor(player, siteId)
	end
end

-- Avança a produção de um jogador. No máximo uma mutação por passo, e só quando algo foi produzido.
local function tickPlayer(player: Player, dt: number)
	local playerProgress = progress[player]
	if playerProgress == nil then
		return
	end

	type Change = { Stored: number, Input: number?, Produced: number, ResourceId: string }
	local changes: { [string]: Change } = {}
	local any = DataService.Read(player, function(data)
		local produced = false
		for siteId, rule in Upgrade.SiteRules(data.Buildings, data.Levels, PRODUCERS) do
			local stored = Production.Stored(data.Storage, siteId, rule)
			local progressNow = playerProgress[siteId] or 0
			local newStored, newProgress, amount, newInput
			if rule.InputId ~= nil then
				local input = Production.Input(data.Inputs, siteId, rule)
				local consumed
				newStored, newInput, newProgress, amount, consumed = Production.StepConverter(stored, input, progressNow, dt, rule)
				assert(amount == 0 or consumed > 0, "produção sem consumo de matéria-prima")
			else
				newStored, newProgress, amount = Production.Step(stored, progressNow, dt, rule)
			end
			playerProgress[siteId] = newProgress
			if amount > 0 then
				changes[siteId] = { Stored = newStored, Input = newInput, Produced = amount, ResourceId = rule.ResourceId }
				produced = true
			end
		end
		return produced
	end)
	if not any then
		return
	end

	-- Saída, entrada e estatística mudam juntas: consumo e produção na mesma mutação.
	local saved = DataService.Mutate(player, function(working)
		for siteId, change in changes do
			working.Storage[siteId] = change.Stored
			if change.Input ~= nil then
				if type(working.Inputs) ~= "table" then
					working.Inputs = {}
				end
				working.Inputs[siteId] = change.Input
			end
			Stats.Add(working, change.ResourceId .. "Produced", change.Produced)
		end
	end)
	if saved then
		for siteId in changes do
			publishFor(player, siteId)
		end
	end
end

local function runClock()
	local last = os.clock()
	while true do
		task.wait(Gameplay.Production.TickSeconds)
		local now = os.clock()
		local dt = math.min(now - last, MAX_TICK_SECONDS)
		last = now
		for player in progress do
			if player.Parent == Players and DataService.IsLoaded(player) then
				-- Um erro de um jogador não pode parar o relógio de todos.
				local ok, err = pcall(tickPlayer, player, dt)
				if not ok then
					warn(`[ProductionService] Falha no passo de produção do jogador {player.UserId}: {tostring(err)}`)
				end
			end
		end
	end
end

local function validateSite(siteId: any): boolean
	return Validate.IsString(siteId, MAX_ID_LENGTH)
end

-- Distância entre o personagem e a peça; infinita sem personagem ou sem peça (pedido recusado).
local function playerDistance(player: Player, part: BasePart?): number
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if part == nil or root == nil or not root:IsA("BasePart") then
		return math.huge
	end
	return ((root :: BasePart).Position - part.Position).Magnitude
end

local function handleHarvest(player: Player, siteId: string)
	local slot = IslandService.GetSlot(player)
	local model = if slot ~= nil then BuildService.GetStructure(slot, siteId) else nil
	local request: Production.HarvestRequest = {
		OwnerSlot = slot,
		TargetSlot = slot or -1, -- o ponto sempre é da ilha do próprio jogador
		SiteId = siteId,
		Distance = playerDistance(player, if model ~= nil then outputPart(model) else nil),
		Reach = Gameplay.Production.ReachStuds,
	}

	local result: string = "NotLoaded"
	local amount = 0
	local saved = DataService.Mutate(player, function(data)
		-- Regra do ponto no nível salvo (Harvest procura a regra pela estrutura do ponto).
		local rules: Production.Rules = {}
		local rule = siteRule(data, siteId)
		local structureId = data.Buildings[siteId]
		if rule ~= nil and type(structureId) == "string" then
			rules[structureId] = rule
		end
		result, amount = Production.Harvest(data :: any, request, rules)
		if result == "Ok" then
			Stats.Add(data, "Harvested", 1)
		end
	end)
	if not saved then
		result, amount = "NotLoaded", 0
	end

	if result == "Ok" then
		-- Recomeça o ciclo: a próxima unidade leva o intervalo inteiro.
		local playerProgress = progress[player]
		if playerProgress ~= nil then
			playerProgress[siteId] = 0
		end
		publishFor(player, siteId)
		IslandService.SendSnapshot(player)
	end

	local remote = resultRemote
	if remote ~= nil then
		remote:FireClient(player, siteId, result, amount)
	end
end

local function validateSupply(siteId: any, amount: any): boolean
	return Validate.IsString(siteId, MAX_ID_LENGTH) and type(amount) == "number" and amount == amount
end

local function handleSupply(player: Player, siteId: string, amount: number)
	local slot = IslandService.GetSlot(player)
	local model = if slot ~= nil then BuildService.GetStructure(slot, siteId) else nil
	local hopper = if model ~= nil then model:FindFirstChild("Input", true) else nil
	local request: Production.SupplyRequest = {
		OwnerSlot = slot,
		TargetSlot = slot or -1,
		SiteId = siteId,
		Amount = amount,
		Distance = playerDistance(player, if hopper ~= nil and hopper:IsA("BasePart") then hopper else nil),
		Reach = Gameplay.Production.ReachStuds,
	}

	local result: string = "NotLoaded"
	local moved = 0
	local saved = DataService.Mutate(player, function(data)
		local rules: Production.Rules = {}
		local rule = siteRule(data, siteId)
		local structureId = data.Buildings[siteId]
		if rule ~= nil and type(structureId) == "string" then
			rules[structureId] = rule
		end
		result, moved = Production.Supply(data :: any, request, rules)
	end)
	if not saved then
		result, moved = "NotLoaded", 0
	end
	if result == "Ok" then
		publishFor(player, siteId)
		IslandService.SendSnapshot(player)
	end
	local remote = supplyRemote
	if remote ~= nil then
		remote:FireClient(player, siteId, result, moved)
	end
end

local function handleUpgrade(player: Player, siteId: string)
	local slot = IslandService.GetSlot(player)
	local model = if slot ~= nil then BuildService.GetStructure(slot, siteId) else nil
	local request: Upgrade.Request = {
		OwnerSlot = slot,
		TargetSlot = slot or -1,
		SiteId = siteId,
		Distance = playerDistance(player, if model ~= nil then model.PrimaryPart else nil),
		Reach = Gameplay.Production.ReachStuds,
	}

	local result: string = "NotLoaded"
	local level = 0
	local saved = DataService.Mutate(player, function(data)
		result, level = Upgrade.Apply(data :: any, request, PRODUCERS)
	end)
	if not saved then
		result, level = "NotLoaded", 0
	end

	if result == "Ok" then
		publishFor(player, siteId)
		IslandService.SendSnapshot(player)
	end
	local remote = upgradeRemote
	if remote ~= nil then
		remote:FireClient(player, siteId, result, level)
	end
end

function ProductionService.Init()
	assert(not initialized, "ProductionService.Init chamado mais de uma vez")
	initialized = true

	for structureId, producer in PRODUCERS do
		assert(Gameplay.Build.Structures[structureId] ~= nil, `Produtor sem estrutura no catálogo: {structureId}`)
		assert(#producer.Levels >= 1, `Produtor sem níveis: {structureId}`)
		for level, entry in producer.Levels do
			assert(
				entry.IntervalSeconds > 0 and entry.Capacity > 0 and entry.Amount > 0,
				`Regra inválida: {structureId} nível {level}`
			)
			assert(level == 1 or entry.Cost ~= nil, `Nível sem custo: {structureId} nível {level}`)
		end
	end

	resultRemote = NetService.CreateOutgoing("HarvestResult")
	upgradeRemote = NetService.CreateOutgoing("UpgradeResult")
	supplyRemote = NetService.CreateOutgoing("SupplyResult")
	NetService.Register("SupplyProducer", validateSupply, handleSupply, {
		Capacity = Gameplay.Remotes.SupplyCapacity,
		RefillPerSecond = Gameplay.Remotes.SupplyRefillPerSecond,
	})
	NetService.Register("HarvestProduction", validateSite, handleHarvest, {
		Capacity = Gameplay.Remotes.HarvestCapacity,
		RefillPerSecond = Gameplay.Remotes.HarvestRefillPerSecond,
	})
	NetService.Register("UpgradeProducer", validateSite, handleUpgrade, {
		Capacity = Gameplay.Remotes.UpgradeCapacity,
		RefillPerSecond = Gameplay.Remotes.UpgradeRefillPerSecond,
	})

	BuildService.OnPlaced(onPlaced)
	DataService.OnLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player: Player)
		progress[player] = nil
	end)
	task.spawn(runClock)
end

return ProductionService
