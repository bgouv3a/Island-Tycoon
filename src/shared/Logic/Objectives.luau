--!strict
--[[
	Sequência de objetivos iniciais. Lógica pura, sem serviços do Roblox.

	- O perfil guarda só quantos objetivos foram concluídos (Objective). O progresso do objetivo
	  atual é calculado do estado autoritativo do perfil (estatísticas, construções, níveis e
	  expansões), então cliente e servidor nunca divergem e não há "tempo de espera" visual.
	- Advance conclui, em ordem, todos os objetivos já cumpridos. Com `grant`, entrega as
	  recompensas na mesma mutação que registra a conclusão: a mesma recompensa nunca sai duas vezes.
	- Ao carregar um perfil antigo, o servidor chama Advance sem `grant`: o que o jogador já tinha
	  feito antes dos objetivos existirem é marcado como concluído, sem recompensa.
]]

local Cost = require(script.Parent.Cost)
local Stats = require(script.Parent.Stats)
local Upgrade = require(script.Parent.Upgrade)

local Objectives = {}

export type Definition = {
	Id: string,
	Text: string,
	Kind: string, -- "Stat" | "Buildings" | "Producers" | "Level" | "Expansion"
	Key: string?,
	Target: number,
	Reward: Cost.Cost,
	Guide: string,
}

export type Context = { Producers: Upgrade.Producers }

local function count(value: any, predicate: (any) -> boolean): number
	local total = 0
	if type(value) == "table" then
		for _, item in value do
			if predicate(item) then
				total += 1
			end
		end
	end
	return total
end

-- Progresso atual do objetivo, entre 0 e o alvo.
function Objectives.Progress(definition: Definition, data: { [string]: any }, context: Context): number
	local kind = definition.Kind
	local value = 0
	if kind == "Stat" and definition.Key ~= nil then
		value = Stats.Get(data, definition.Key)
	elseif kind == "Buildings" then
		value = count(data.Buildings, function(id)
			return type(id) == "string"
		end)
	elseif kind == "Producers" then
		value = count(data.Buildings, function(id)
			return type(id) == "string" and context.Producers[id] ~= nil
		end)
	elseif kind == "Level" then
		local buildings = data.Buildings
		if type(buildings) == "table" then
			for siteId, structureId in buildings do
				local producer = if type(structureId) == "string" then context.Producers[structureId] else nil
				if type(siteId) == "string" and producer ~= nil then
					value = math.max(value, Upgrade.Level(data.Levels, siteId, #producer.Levels))
				end
			end
		end
	elseif kind == "Expansion" and definition.Key ~= nil then
		local expansions = data.Expansions
		value = if type(expansions) == "table" and expansions[definition.Key] == true then 1 else 0
	end
	return math.clamp(value, 0, definition.Target)
end

-- Quantos objetivos já foram concluídos (sempre entre 0 e o total).
function Objectives.Completed(data: { [string]: any }, definitions: { Definition }): number
	local value = data.Objective
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 0 then
		return 0
	end
	return math.min(value, #definitions)
end

-- Objetivo atual (o primeiro não concluído), ou nil se todos foram concluídos.
function Objectives.Current(data: { [string]: any }, definitions: { Definition }): (Definition?, number)
	local index = Objectives.Completed(data, definitions) + 1
	return definitions[index], index
end

-- Conclui os objetivos já cumpridos, em ordem, e devolve os concluídos agora.
function Objectives.Advance(
	data: { [string]: any },
	definitions: { Definition },
	context: Context,
	grant: boolean
): { Definition }
	local done: { Definition } = {}
	local completed = Objectives.Completed(data, definitions)
	while completed < #definitions do
		local definition = definitions[completed + 1]
		if Objectives.Progress(definition, data, context) < definition.Target then
			break
		end
		if grant then
			if type(data.Resources) ~= "table" then
				error("saldo inválido")
			end
			Cost.Grant(data.Resources, definition.Reward)
		end
		completed += 1
		data.Objective = completed
		table.insert(done, definition)
	end
	return done
end

return Objectives
