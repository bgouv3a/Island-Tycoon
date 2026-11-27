--!strict
--[[
	Níveis de melhoria das construções produtivas. Lógica pura, sem serviços do Roblox.

	- O nível de cada ponto fica no perfil (Levels: ponto → nível). Ausente ou inválido = nível 1.
	- Cada nível define a regra de produção (quantidade, intervalo, capacidade) e o custo para
	  chegar a ele (Config/Economy.Upgrades).
	- Apply verifica e aplica na mesma chamada: desconta o custo e sobe um nível, ou não muda nada.
	  Ordem: ilha → dono → produtor → alcance → nível máximo → saldo.
]]

local Cost = require(script.Parent.Cost)
local Production = require(script.Parent.Production)

local Upgrade = {}

export type Level = {
	Amount: number,
	IntervalSeconds: number,
	Capacity: number,
	Cost: Cost.Cost?,
}

export type Producer = { ResourceId: string, Levels: { Level } }
export type Producers = { [string]: Producer } -- estrutura → produtor

export type Request = {
	OwnerSlot: number?,
	TargetSlot: number,
	SiteId: string,
	Distance: number,
	Reach: number,
}

export type Result = "Ok" | "NoIsland" | "NotOwner" | "NotUpgradable" | "OutOfReach" | "MaxLevel" | "Insufficient" | "Invalid"

-- Nível salvo de um ponto, sempre um inteiro entre 1 e `maxLevel`.
function Upgrade.Level(levels: any, siteId: string, maxLevel: number): number
	local value = if type(levels) == "table" then levels[siteId] else nil
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 1 then
		return 1
	end
	return math.min(value, maxLevel)
end

-- Regra de produção de um produtor em um nível (limitado ao intervalo válido).
function Upgrade.RuleFor(producer: Producer, level: number): Production.Rule
	local index = math.clamp(level, 1, #producer.Levels)
	local entry = producer.Levels[index]
	return {
		ResourceId = producer.ResourceId,
		Amount = entry.Amount,
		IntervalSeconds = entry.IntervalSeconds,
		Capacity = entry.Capacity,
	}
end

-- Regra de cada ponto com construção produtiva, já no nível salvo.
function Upgrade.SiteRules(buildings: any, levels: any, producers: Producers): { [string]: Production.Rule }
	local result: { [string]: Production.Rule } = {}
	if type(buildings) ~= "table" then
		return result
	end
	for siteId, structureId in buildings do
		local producer = if type(structureId) == "string" then producers[structureId] else nil
		if type(siteId) == "string" and producer ~= nil then
			result[siteId] = Upgrade.RuleFor(producer, Upgrade.Level(levels, siteId, #producer.Levels))
		end
	end
	return result
end

-- Custo do próximo nível de um ponto, ou nil se já estiver no máximo.
function Upgrade.NextCost(producer: Producer, level: number): Cost.Cost?
	local entry = producer.Levels[level + 1]
	return if entry ~= nil then entry.Cost else nil
end

-- Sobe um nível do produtor no ponto, descontando o custo. Devolve o resultado e o nível final.
function Upgrade.Apply(data: { [string]: any }, request: Request, producers: Producers): (Result, number)
	if request.OwnerSlot == nil then
		return "NoIsland", 0
	end
	if request.OwnerSlot ~= request.TargetSlot then
		return "NotOwner", 0
	end
	local buildings, resources = data.Buildings, data.Resources
	if type(buildings) ~= "table" or type(resources) ~= "table" then
		return "Invalid", 0
	end
	local structureId = buildings[request.SiteId]
	local producer = if type(structureId) == "string" then producers[structureId] else nil
	if producer == nil then
		return "NotUpgradable", 0
	end
	if not (request.Distance <= request.Reach) then
		return "OutOfReach", 0
	end
	local level = Upgrade.Level(data.Levels, request.SiteId, #producer.Levels)
	local cost = Upgrade.NextCost(producer, level)
	if level >= #producer.Levels or cost == nil then
		return "MaxLevel", level
	end
	if not Cost.Spend(resources, cost) then
		return "Insufficient", level
	end
	if type(data.Levels) ~= "table" then
		data.Levels = {}
	end
	data.Levels[request.SiteId] = level + 1
	return "Ok", level + 1
end

return Upgrade
