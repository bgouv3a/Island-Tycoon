--!strict
--[[
	Textos de recursos e custos em português, na ordem de exibição de Economy.Resources.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared").Config.Economy)

local Format = {}

local ordered: { string } = {}
for id in Economy.Resources do
	table.insert(ordered, id)
end
table.sort(ordered, function(a: string, b: string): boolean
	return Economy.Resources[a].Order < Economy.Resources[b].Order
end)

-- Ids de recurso na ordem de exibição.
function Format.OrderedIds(): { string }
	return ordered
end

function Format.Name(resourceId: string): string
	local resource = Economy.Resources[resourceId]
	return if resource ~= nil then resource.Name else resourceId
end

-- "120 Moedas, 40 Madeira"
function Format.Cost(cost: { [string]: number }): string
	local parts: { string } = {}
	for _, id in ordered do
		local amount = cost[id]
		if amount ~= nil and amount > 0 then
			table.insert(parts, `{amount} {Format.Name(id)}`)
		end
	end
	return table.concat(parts, ", ")
end

-- "+10 Moedas, +4 Madeira"
function Format.Reward(reward: { [string]: number }): string
	local parts: { string } = {}
	for _, id in ordered do
		local amount = reward[id]
		if amount ~= nil and amount > 0 then
			table.insert(parts, `+{amount} {Format.Name(id)}`)
		end
	end
	return table.concat(parts, ", ")
end

-- O que falta para pagar `cost` com `balances`: "20 Pedra, 5 Madeira" (vazio se cobre).
function Format.Missing(cost: { [string]: number }, balances: { [string]: number }): string
	local parts: { string } = {}
	for _, id in ordered do
		local need = cost[id]
		if need ~= nil then
			local lack = need - (balances[id] or 0)
			if lack > 0 then
				table.insert(parts, `{lack} {Format.Name(id)}`)
			end
		end
	end
	return table.concat(parts, ", ")
end

return Format
