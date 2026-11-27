--!strict
--[[
	ExpansionService: compra e restauração das expansões territoriais da ilha do próprio jogador.

	- O cliente só pede "expandir a área X" junto à placa. Dono, alcance, área e custo são
	  decididos aqui (Logic/Expansion), em uma única mutação: a área nunca é paga duas vezes.
	- A área liberada fica salva no perfil (Expansions). Ao carregar o perfil, ela é recriada
	  sem animação; na compra, o gramado sobe do mar (IslandService.ShowExpansion).
	- Os pontos de construção da área são liberados no BuildService (UnlockArea).
	- Ao sair, o IslandService devolve a área ao mar: a ilha pode ir para outro jogador.

	Mensagens ao cliente (ExpandResult): (área, resultado). "Ok" ao aprovar a compra e
	"Ready" quando a área nova terminou de aparecer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Economy = require(Shared.Config.Economy)
local Expansion = require(Shared.Logic.Expansion)
local Validate = require(Shared.Logic.Validate)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local BuildService = require(script.Parent.BuildService)
local NetService = require(script.Parent.NetService)

local MAX_ID_LENGTH = 32
local AREAS: Expansion.Areas = Economy.Expansions

local ExpansionService = {}

local initialized = false
local resultRemote: RemoteEvent? = nil

local function notify(player: Player, area: string, result: string)
	local remote = resultRemote
	if remote ~= nil and player.Parent ~= nil then
		remote:FireClient(player, area, result)
	end
end

-- Mostra a área na ilha e libera os pontos de construção dela.
local function reveal(player: Player, slot: number, area: string, animate: boolean)
	if IslandService.ShowExpansion(slot, area, animate) and IslandService.GetSlot(player) == slot then
		BuildService.UnlockArea(slot, area)
		if animate then
			notify(player, area, "Ready")
		end
	end
end

local function handleExpand(player: Player, area: string)
	local slot = IslandService.GetSlot(player)
	local board = if slot ~= nil then IslandService.GetExpansionSign(slot, area) else nil
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local distance = math.huge
	if board ~= nil and root ~= nil and root:IsA("BasePart") then
		distance = ((root :: BasePart).Position - board.Position).Magnitude
	end
	local shape = Gameplay.Expansions[area]

	local request: Expansion.Request = {
		OwnerSlot = slot,
		TargetSlot = slot or -1, -- a área é sempre da ilha do próprio jogador
		AreaId = area,
		Distance = distance,
		Reach = if shape ~= nil then shape.ReachStuds else 0,
	}

	local result: string = "NotLoaded"
	local saved = DataService.Mutate(player, function(data)
		result = Expansion.Apply(data :: any, request, AREAS)
	end)
	if not saved then
		result = "NotLoaded"
	end

	notify(player, area, result)
	if result == "Ok" and slot ~= nil then
		IslandService.SendSnapshot(player)
		task.spawn(reveal, player, slot, area, true)
	end
end

local function onLoaded(player: Player)
	local slot = IslandService.GetSlot(player)
	if slot == nil then
		return
	end
	local unlocked = DataService.Read(player, function(data)
		local list: { string } = {}
		for area in AREAS do
			if Expansion.IsUnlocked(data, area) then
				table.insert(list, area)
			end
		end
		return list
	end)
	for _, area in unlocked or {} do
		task.spawn(reveal, player, slot, area, false)
	end
end

function ExpansionService.Init()
	assert(not initialized, "ExpansionService.Init chamado mais de uma vez")
	initialized = true

	for area in AREAS do
		assert(Gameplay.Expansions[area] ~= nil, `Expansão sem geometria em Config/Gameplay: {area}`)
	end

	resultRemote = NetService.CreateOutgoing("ExpandResult")
	NetService.Register("ExpandIsland", function(area: any): boolean
		return Validate.IsString(area, MAX_ID_LENGTH)
	end, handleExpand, {
		Capacity = Gameplay.Remotes.ExpandCapacity,
		RefillPerSecond = Gameplay.Remotes.ExpandRefillPerSecond,
	})

	DataService.OnLoaded(onLoaded)
end

return ExpansionService
