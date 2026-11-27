--!strict
--[[
	Venda de recursos no mercado do píer. Lógica pura, sem serviços do Roblox.

	- Recebe a cópia de trabalho dos dados (DataService.Mutate). Em qualquer recusa, nada muda.
	- Desconto do recurso e crédito das moedas acontecem na mesma chamada: não há venda pela metade.
	- Ordem: ilha → dono → recurso → quantidade → alcance → saldo.
]]

local ResourceLedger = require(script.Parent.ResourceLedger)
local Stats = require(script.Parent.Stats)

local Market = {}

export type Config = {
	CurrencyId: string,
	MaxLot: number,
	Prices: { [string]: number },
}

export type SellRequest = {
	OwnerSlot: number?,
	TargetSlot: number,
	ResourceId: string,
	Amount: number,
	Distance: number,
	Reach: number,
}

export type Result = "Ok" | "NoIsland" | "NotOwner" | "NotSellable" | "InvalidAmount" | "OutOfReach" | "Insufficient" | "Invalid"

function Market.Sell(data: { [string]: any }, request: SellRequest, config: Config): (Result, number)
	if request.OwnerSlot == nil then
		return "NoIsland", 0
	end
	if request.OwnerSlot ~= request.TargetSlot then
		return "NotOwner", 0
	end
	local price = config.Prices[request.ResourceId]
	if type(price) ~= "number" or request.ResourceId == config.CurrencyId then
		return "NotSellable", 0
	end
	local amount = request.Amount
	if type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > config.MaxLot then
		return "InvalidAmount", 0
	end
	-- A forma `not (a <= b)` também rejeita NaN.
	if not (request.Distance <= request.Reach) then
		return "OutOfReach", 0
	end
	local resources = data.Resources
	if type(resources) ~= "table" then
		return "Invalid", 0
	end
	if ResourceLedger.Get(resources, request.ResourceId) < amount then
		return "Insufficient", 0
	end
	local earned = amount * price
	if not ResourceLedger.Spend(resources, request.ResourceId, amount) then
		return "Insufficient", 0
	end
	if not ResourceLedger.Add(resources, config.CurrencyId, earned) then
		error("crédito de moedas recusado") -- desfaz o desconto (Mutate descarta a cópia)
	end
	Stats.Add(data, "CoinsEarned", earned)
	return "Ok", earned
end

return Market
