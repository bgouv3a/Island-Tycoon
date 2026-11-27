--!strict
--[[
	Compra de expansões territoriais. Lógica pura, sem serviços do Roblox.

	- Recebe a cópia de trabalho dos dados (DataService.Mutate). Em qualquer recusa, nada muda.
	- Custo e liberação acontecem na mesma chamada: a mesma área nunca é paga duas vezes.
	- Ordem: ilha → dono → área → já liberada → alcance → saldo.
]]

local Cost = require(script.Parent.Cost)

local Expansion = {}

export type Areas = { [string]: { Cost: Cost.Cost } }

export type Request = {
	OwnerSlot: number?,
	TargetSlot: number,
	AreaId: string,
	Distance: number,
	Reach: number,
}

export type Result = "Ok" | "NoIsland" | "NotOwner" | "UnknownArea" | "AlreadyOwned" | "OutOfReach" | "Insufficient" | "Invalid"

function Expansion.IsUnlocked(data: { [string]: any }, areaId: string): boolean
	local expansions = data.Expansions
	return type(expansions) == "table" and expansions[areaId] == true
end

function Expansion.Apply(data: { [string]: any }, request: Request, areas: Areas): Result
	if request.OwnerSlot == nil then
		return "NoIsland"
	end
	if request.OwnerSlot ~= request.TargetSlot then
		return "NotOwner"
	end
	local area = areas[request.AreaId]
	if area == nil then
		return "UnknownArea"
	end
	if Expansion.IsUnlocked(data, request.AreaId) then
		return "AlreadyOwned"
	end
	-- A forma `not (a <= b)` também rejeita NaN.
	if not (request.Distance <= request.Reach) then
		return "OutOfReach"
	end
	if type(data.Resources) ~= "table" then
		return "Invalid"
	end
	if not Cost.Spend(data.Resources, area.Cost) then
		return "Insufficient"
	end
	if type(data.Expansions) ~= "table" then
		data.Expansions = {}
	end
	data.Expansions[request.AreaId] = true
	return "Ok"
end

return Expansion
