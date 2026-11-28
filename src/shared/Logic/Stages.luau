--!strict
--[[
	Estágios de desenvolvimento da ilha (1 = Ilha inicial, 2 = Ilha produtiva). Lógica pura.

	- O estágio fica no perfil (Stage). Requisitos do próximo estágio são calculados do estado
	  autoritativo (expansões e estatísticas).
	- Advance verifica os requisitos e sobe um estágio com a recompensa na mesma chamada: a
	  recompensa nunca sai duas vezes.
]]

local Cost = require(script.Parent.Cost)
local Stats = require(script.Parent.Stats)

local Stages = {}

export type Requirement = { Kind: string, Key: string, Target: number, Text: string }
export type Stage = {
	Name: string,
	Requirements: { Requirement }?,
	Reward: Cost.Cost?,
	OrderBonus: number?,
	Benefits: { string }?,
}

export type Result = "Ok" | "MaxStage" | "NotReady" | "Invalid"

function Stages.Current(data: { [string]: any }, stages: { Stage }): number
	local value = data.Stage
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 1 then
		return 1
	end
	return math.min(value, #stages)
end

function Stages.Progress(requirement: Requirement, data: { [string]: any }): number
	local value = 0
	if requirement.Kind == "Stat" then
		value = Stats.Get(data, requirement.Key)
	elseif requirement.Kind == "Expansion" then
		local expansions = data.Expansions
		value = if type(expansions) == "table" and expansions[requirement.Key] == true then 1 else 0
	end
	return math.clamp(value, 0, requirement.Target)
end

-- Verdadeiro se todos os requisitos do próximo estágio estão cumpridos.
function Stages.IsReady(data: { [string]: any }, stages: { Stage }): boolean
	local nextStage = stages[Stages.Current(data, stages) + 1]
	if nextStage == nil then
		return false
	end
	for _, requirement in nextStage.Requirements or {} do
		if Stages.Progress(requirement, data) < requirement.Target then
			return false
		end
	end
	return true
end

-- Bônus dos pedidos no estágio atual (o maior bônus já alcançado).
function Stages.OrderBonus(data: { [string]: any }, stages: { Stage }): number
	local bonus = 0
	for index = 1, Stages.Current(data, stages) do
		bonus = math.max(bonus, stages[index].OrderBonus or 0)
	end
	return bonus
end

function Stages.Advance(data: { [string]: any }, stages: { Stage }): (Result, number)
	local current = Stages.Current(data, stages)
	local nextStage = stages[current + 1]
	if nextStage == nil then
		return "MaxStage", current
	end
	if not Stages.IsReady(data, stages) then
		return "NotReady", current
	end
	if nextStage.Reward ~= nil then
		if type(data.Resources) ~= "table" then
			return "Invalid", current
		end
		Cost.Grant(data.Resources, nextStage.Reward)
	end
	data.Stage = current + 1
	return "Ok", current + 1
end

return Stages
