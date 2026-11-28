--!strict
--[[
	BuildService: construção de estruturas nos pontos fixos da ilha do próprio jogador.

	O cliente envia só o ponto e a estrutura. Ilha, preço, ocupação, saldo e alcance são
	decididos aqui. A madeira é descontada somente por DataService.Mutate, na mesma operação
	que registra a construção (ver Logic/Build).

	Ao sair, as construções visuais da ilha são removidas. Ao carregar o perfil, são recriadas
	a partir de Buildings, sem duplicar as que já existem.

	Outros serviços (ex.: ProductionService) acompanham as estruturas por OnPlaced e GetStructure,
	sem criar um segundo sistema de construção.

	Pontos de uma expansão (Gameplay.Build.SiteAreas) ficam escondidos e recusados ("Locked") até
	a área ser liberada no perfil; o ExpansionService chama UnlockArea quando isso acontece.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Build = require(Shared.Logic.Build)
local Validate = require(Shared.Logic.Validate)
local Models = require(Shared.Art.Models)
local Palette = require(Shared.Art.Palette)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local NetService = require(script.Parent.NetService)

local MAX_ID_LENGTH = 32

local SITES: { [string]: Vector2 } = Gameplay.Build.Sites
local STRUCTURES: { [string]: Build.Structure } = Gameplay.Build.Structures

local CATALOG: Build.Catalog = {
	Sites = SITES,
	Structures = STRUCTURES,
	CurrencyId = Gameplay.Resources.WoodId,
	SiteAreas = Gameplay.Build.SiteAreas,
}
local SITE_AREAS: { [string]: string } = Gameplay.Build.SiteAreas

local BuildService = {}

local initialized = false
local resultRemote: RemoteEvent? = nil
local siteIds: { string } = {}
local markers: { [number]: { [string]: Model } } = {} -- slot → ponto → marcador
local placed: { [number]: { [string]: Model } } = {} -- slot → ponto → estrutura
local activeSlot: { [Player]: number } = {} -- slot ocupado por cada jogador com perfil carregado
local unlockedAreas: { [number]: { [string]: boolean } } = {} -- slot → expansões liberadas
local placedCallbacks: { (slot: number, siteId: string, structureId: string, model: Model) -> () } = {}

-- Posição no mundo de um ponto da ilha, ou nil se o ponto ou a ilha não existirem.
local function sitePosition(slot: number, siteId: string): Vector3?
	local origin = IslandService.GetOrigin(slot)
	local offset = SITES[siteId]
	if origin == nil or offset == nil then
		return nil
	end
	return origin + Vector3.new(offset.X, 0, offset.Y)
end

-- Estrutura olha para a chegada do jogador (frente do modelo = -Z = LookVector).
local function siteCFrame(slot: number, siteId: string): CFrame?
	local position = sitePosition(slot, siteId)
	local origin = IslandService.GetOrigin(slot)
	if position == nil or origin == nil then
		return nil
	end
	local spawn = origin + Gameplay.Islands.SpawnOffset
	return CFrame.lookAt(position, Vector3.new(spawn.X, position.Y, spawn.Z))
end

-- Mostra ou esconde o marcador do ponto (peças, prompt e rótulo). O atributo Open, na placa,
-- permite ao cliente guiar o jogador até um ponto livre.
local function setMarkerOpen(slot: number, siteId: string, open: boolean)
	local marker = markers[slot] and markers[slot][siteId]
	if marker == nil then
		return
	end
	-- Ponto de expansão ainda não liberada fica sempre fechado.
	local area = SITE_AREAS[siteId]
	if area ~= nil and not (unlockedAreas[slot] and unlockedAreas[slot][area]) then
		open = false
	end
	for _, descendant in marker:GetDescendants() do
		if descendant:IsA("BasePart") then
			local base = descendant:GetAttribute("BaseTransparency")
			descendant.Transparency = if open and type(base) == "number" then base else 1
		elseif descendant:IsA("ProximityPrompt") or descendant:IsA("BillboardGui") then
			descendant.Enabled = open
		end
	end
	local pad = marker.PrimaryPart
	if pad ~= nil then
		pad:SetAttribute("Open", open)
	end
end

local function buildLabel(pad: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(5, 1.5)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = pad

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Palette.UiAccent
	text.TextColor3 = Palette.UiTextLight
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "Construir"
	text.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.14, 0)
	padding.PaddingBottom = UDim.new(0.14, 0)
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.Parent = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = text

	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.UiAccentDark
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = text

	gui.Parent = pad
end

local function buildMarkers(slot: number, model: Model)
	local list: { [string]: Model } = {}
	for _, siteId in siteIds do
		local cframe = siteCFrame(slot, siteId)
		if cframe == nil then
			continue
		end

		local marker, pad = Models.BuildMarker(cframe)
		for _, descendant in marker:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant:SetAttribute("BaseTransparency", descendant.Transparency)
			end
		end
		pad:SetAttribute("SiteId", siteId)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuildPrompt"
		prompt.ObjectText = `Ponto {siteId}`
		prompt.ActionText = "Construir"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Gameplay.Build.ReachStuds
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad

		buildLabel(pad)
		marker.Parent = model
		list[siteId] = marker
	end
	markers[slot] = list
	for _, siteId in siteIds do
		setMarkerOpen(slot, siteId, true)
	end
end

-- Cria a estrutura no ponto. Se já existir uma no ponto, não cria outra.
local function spawnStructure(slot: number, siteId: string, structureId: string)
	local slotPlaced = placed[slot]
	if slotPlaced == nil or slotPlaced[siteId] ~= nil then
		return
	end
	local definition = STRUCTURES[structureId]
	local cframe = siteCFrame(slot, siteId)
	local island = IslandService.GetIsland(slot)
	if definition == nil or cframe == nil or island == nil then
		return
	end
	local builds = island:FindFirstChild("Builds")
	if builds == nil then
		return
	end

	local structure = Models.Structure(structureId, cframe)
	if structure == nil then
		return
	end
	structure.Name = definition.Name
	structure:SetAttribute("SiteId", siteId)
	structure:SetAttribute("StructureId", structureId)
	structure.Parent = builds
	slotPlaced[siteId] = structure
	setMarkerOpen(slot, siteId, false)
	for _, callback in placedCallbacks do
		task.spawn(callback, slot, siteId, structureId, structure)
	end
end

-- Remove as estruturas e reabre os pontos da ilha (os de expansão voltam a ficar bloqueados).
local function clearIsland(slot: number)
	for _, structure in placed[slot] or {} do
		structure:Destroy()
	end
	placed[slot] = {}
	unlockedAreas[slot] = {}
	for _, siteId in siteIds do
		setMarkerOpen(slot, siteId, true)
	end
end

-- Recria as construções salvas do jogador na ilha dele.
local function restoreFor(player: Player)
	local slot = IslandService.GetSlot(player)
	if slot == nil then
		return
	end
	clearIsland(slot)
	activeSlot[player] = slot

	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	-- Estruturas em pontos de expansão só aparecem em UnlockArea, depois que o terreno da área
	-- existe (o ExpansionService chama UnlockArea quando a área termina de aparecer).
	for siteId, structureId in Build.Restore(data.Buildings, CATALOG) do
		if SITE_AREAS[siteId] == nil then
			spawnStructure(slot, siteId, structureId)
		end
	end
end

local function onPlayerRemoving(player: Player)
	local slot = activeSlot[player]
	activeSlot[player] = nil
	if slot ~= nil then
		clearIsland(slot)
	end
end

local function validateBuild(siteId: any, structureId: any): boolean
	return Validate.IsString(siteId, MAX_ID_LENGTH) and Validate.IsString(structureId, MAX_ID_LENGTH)
end

local function handleBuild(player: Player, siteId: string, structureId: string)
	local slot = IslandService.GetSlot(player)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil

	-- Sem ponto válido ou sem personagem, a distância fica infinita e a compra é recusada.
	local distance = math.huge
	local position = if slot ~= nil then sitePosition(slot, siteId) else nil
	if position ~= nil and root ~= nil and root:IsA("BasePart") then
		distance = ((root :: BasePart).Position - position).Magnitude
	end

	-- O ponto sempre pertence à ilha do próprio jogador: o cliente não informa a ilha.
	local request: Build.Request = {
		OwnerSlot = slot,
		TargetSlot = slot or -1,
		SiteId = siteId,
		StructureId = structureId,
		Distance = distance,
		Reach = Gameplay.Build.ReachStuds,
	}

	local result: string = "NotLoaded"
	local saved = DataService.Mutate(player, function(data)
		-- Se a regra recusar, nada é alterado no perfil.
		result = Build.Apply(data :: any, request, CATALOG)
		-- Ponto recém-ocupado começa sem estoque e no nível 1 (descarta qualquer valor antigo).
		if result == "Ok" then
			if type(data.Storage) == "table" then
				data.Storage[siteId] = nil
			end
			if type(data.Levels) == "table" then
				data.Levels[siteId] = nil
			end
			if type(data.Inputs) == "table" then
				data.Inputs[siteId] = nil
			end
		end
	end)
	if not saved then
		result = "NotLoaded"
	end

	if result == "Ok" and slot ~= nil then
		spawnStructure(slot, siteId, structureId)
		-- O saldo mudou: o cliente precisa do valor novo para a interface.
		IslandService.SendSnapshot(player)
	end

	local remote = resultRemote
	if remote ~= nil then
		remote:FireClient(player, siteId, structureId, result)
	end
end

-- Libera os pontos de uma expansão na ilha (chamado ao carregar o perfil e ao comprar a área).
function BuildService.UnlockArea(slot: number, area: string)
	local areas = unlockedAreas[slot]
	if areas == nil then
		areas = {}
		unlockedAreas[slot] = areas
	end
	areas[area] = true

	-- Recria as construções salvas do dono nos pontos desta área.
	local owner: Player? = nil
	for player, playerSlot in activeSlot do
		if playerSlot == slot then
			owner = player
		end
	end
	local data = if owner ~= nil then DataService.GetData(owner) else nil
	local saved = if data ~= nil then Build.Restore(data.Buildings, CATALOG) else {}

	for siteId, siteArea in SITE_AREAS do
		if siteArea == area then
			local structureId = saved[siteId]
			if structureId ~= nil then
				spawnStructure(slot, siteId, structureId)
			end
			local slotPlaced = placed[slot]
			setMarkerOpen(slot, siteId, slotPlaced == nil or slotPlaced[siteId] == nil)
		end
	end
end

-- Estrutura construída em um ponto da ilha, ou nil.
function BuildService.GetStructure(slot: number, siteId: string): Model?
	local slotPlaced = placed[slot]
	return if slotPlaced ~= nil then slotPlaced[siteId] else nil
end

-- Registra uma função chamada sempre que uma estrutura aparece na ilha (compra ou restauração).
function BuildService.OnPlaced(callback: (slot: number, siteId: string, structureId: string, model: Model) -> ())
	table.insert(placedCallbacks, callback)
end

function BuildService.Init()
	assert(not initialized, "BuildService.Init chamado mais de uma vez")
	initialized = true

	for siteId in SITES do
		table.insert(siteIds, siteId)
	end
	table.sort(siteIds)
	for structureId in STRUCTURES do
		assert(Models.HasStructure(structureId), `Estrutura sem modelo em Art/Models: {structureId}`)
	end

	for slot = 1, Gameplay.Islands.MaxPerServer do
		local model = IslandService.GetIsland(slot)
		assert(model ~= nil, "IslandService.Init precisa ser chamado antes de BuildService.Init")
		placed[slot] = {}
		unlockedAreas[slot] = {}
		buildMarkers(slot, model)
	end

	resultRemote = NetService.CreateOutgoing("BuildResult")
	NetService.Register("BuildStructure", validateBuild, handleBuild, {
		Capacity = Gameplay.Remotes.BuildCapacity,
		RefillPerSecond = Gameplay.Remotes.BuildRefillPerSecond,
	})

	DataService.OnLoaded(restoreFor)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return BuildService
