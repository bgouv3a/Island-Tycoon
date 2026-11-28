--!strict
--[[
	ObjectiveService: sequência de objetivos iniciais com recompensas (Config/Economy.Objectives).

	- O progresso vem do estado autoritativo do perfil (Logic/Objectives); o cliente só exibe.
	- Ao carregar o perfil, objetivos já cumpridos antes de existirem são marcados como concluídos
	  sem recompensa (perfis antigos não ganham recompensas em cascata).
	- Depois disso, a cada mudança no perfil (DataService.OnChanged, agrupada por quadro), o
	  objetivo atual é verificado com uma leitura sem cópia. Só há mutação quando um objetivo é
	  concluído, e a recompensa entra na mesma mutação que registra a conclusão.
	- O cliente recebe ObjectiveChanged(estado) só quando algo muda. O estado inclui o estágio da
	  ilha (Logic/Stages): requisitos, benefícios e se já pode avançar. AdvanceStage sobe o estágio
	  com a recompensa na mesma mutação.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Economy = require(Shared.Config.Economy)
local Objectives = require(Shared.Logic.Objectives)
local Stages = require(Shared.Logic.Stages)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local NetService = require(script.Parent.NetService)

local DEFINITIONS: { Objectives.Definition } = Economy.Objectives :: any
local CONTEXT: Objectives.Context = { Producers = Gameplay.Production.Producers }
local STAGES: { Stages.Stage } = Economy.Stages :: any

local ObjectiveService = {}

local initialized = false
local changedRemote: RemoteEvent? = nil
local stageRemote: RemoteEvent? = nil
local ready: { [Player]: boolean } = {} -- recuperação de perfil antigo já feita
local lastSent: { [Player]: string } = {}

type Completed = { Id: string, Text: string, Reward: { [string]: number } }

-- Estágio atual e requisitos do próximo, para o cliente.
local function stageState(data: { [string]: any }): { [string]: any }
	local current = Stages.Current(data, STAGES)
	local nextStage = STAGES[current + 1]
	local requirements = {}
	if nextStage ~= nil then
		for _, requirement in nextStage.Requirements or {} do
			table.insert(requirements, {
				Text = requirement.Text,
				Current = Stages.Progress(requirement, data),
				Target = requirement.Target,
			})
		end
	end
	return {
		Current = current,
		Name = STAGES[current].Name,
		NextName = if nextStage ~= nil then nextStage.Name else nil,
		Requirements = requirements,
		Benefits = if nextStage ~= nil then nextStage.Benefits else nil,
		Ready = Stages.IsReady(data, STAGES),
	}
end

-- Estado do objetivo atual, para o cliente.
local function snapshot(data: { [string]: any }): { [string]: any }
	local definition, index = Objectives.Current(data, DEFINITIONS)
	local stage = stageState(data)
	if definition == nil then
		return { Index = index, Total = #DEFINITIONS, Done = true, Stage = stage }
	end
	return {
		Stage = stage,
		GuideKey = (definition :: any).GuideKey,
		Index = index,
		Total = #DEFINITIONS,
		Done = false,
		Id = definition.Id,
		Text = definition.Text,
		Current = Objectives.Progress(definition, data, CONTEXT),
		Target = definition.Target,
		Guide = definition.Guide,
		Reward = definition.Reward,
	}
end

local function send(player: Player, state: { [string]: any }, completed: { Completed }?)
	local parts = { `{state.Index}:{state.Current}:{state.Stage.Current}:{state.Stage.Ready}` }
	for _, requirement in state.Stage.Requirements do
		table.insert(parts, tostring(requirement.Current))
	end
	local key = table.concat(parts, ",")
	if completed == nil and lastSent[player] == key then
		return -- nada mudou para o jogador
	end
	lastSent[player] = key
	local remote = changedRemote
	if remote ~= nil then
		remote:FireClient(player, state, completed or {})
	end
end

local function evaluate(player: Player)
	if not ready[player] then
		return
	end
	local finished = DataService.Read(player, function(data)
		local definition = Objectives.Current(data, DEFINITIONS)
		return definition ~= nil and Objectives.Progress(definition, data, CONTEXT) >= definition.Target
	end)
	if finished == nil then
		return
	end

	local completed: { Completed } = {}
	if finished then
		local saved = DataService.Mutate(player, function(data)
			completed = {}
			for _, definition in Objectives.Advance(data :: any, DEFINITIONS, CONTEXT, true) do
				table.insert(completed, { Id = definition.Id, Text = definition.Text, Reward = definition.Reward })
			end
		end)
		if not saved then
			completed = {}
		elseif #completed > 0 then
			IslandService.SendSnapshot(player)
		end
	end

	local state = DataService.Read(player, snapshot)
	if state ~= nil then
		send(player, state, if #completed > 0 then completed else nil)
	end
end

local function onLoaded(player: Player)
	-- Perfil antigo: marca o que já foi feito, sem recompensa.
	DataService.Mutate(player, function(data)
		Objectives.Advance(data :: any, DEFINITIONS, CONTEXT, false)
	end)
	if player.Parent ~= Players then
		return
	end
	ready[player] = true
	lastSent[player] = nil
	evaluate(player)
end

function ObjectiveService.Init()
	assert(not initialized, "ObjectiveService.Init chamado mais de uma vez")
	initialized = true

	for index, definition in DEFINITIONS do
		assert(definition.Target >= 1, `Objetivo sem alvo: {index}`)
		for resourceId in definition.Reward do
			assert(Economy.Resources[resourceId] ~= nil, `Recompensa com recurso desconhecido: {definition.Id}`)
		end
	end

	changedRemote = NetService.CreateOutgoing("ObjectiveChanged")
	stageRemote = NetService.CreateOutgoing("StageResult")
	NetService.Register("AdvanceStage", function(): boolean
		return true
	end, function(player: Player)
		local result: string = "NotLoaded"
		local stage = 0
		local saved = DataService.Mutate(player, function(data)
			result, stage = Stages.Advance(data :: any, STAGES)
		end)
		if not saved then
			result = "NotLoaded"
		end
		if result == "Ok" then
			IslandService.SendSnapshot(player)
		end
		local remote = stageRemote
		if remote ~= nil then
			remote:FireClient(player, result, stage)
		end
	end, {
		Capacity = Gameplay.Remotes.StageCapacity,
		RefillPerSecond = Gameplay.Remotes.StageRefillPerSecond,
	})
	NetService.Register("RequestObjective", function(): boolean
		return true
	end, function(player: Player)
		lastSent[player] = nil
		evaluate(player)
	end, { Capacity = 3, RefillPerSecond = 1 })

	DataService.OnLoaded(onLoaded)
	DataService.OnChanged(evaluate)
	Players.PlayerRemoving:Connect(function(player: Player)
		ready[player] = nil
		lastSent[player] = nil
	end)
end

return ObjectiveService
