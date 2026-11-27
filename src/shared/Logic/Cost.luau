--!strict
--[[
	Custos com vários recursos (ex.: { Coins = 25, Stone = 4 }). Lógica pura, sem serviços do Roblox.
	Spend é tudo ou nada: verifica todos os recursos antes de descontar qualquer um.
]]

local ResourceLedger = require(script.Parent.ResourceLedger)

local Cost = {}

export type Cost = { [string]: number }

local function isAmount(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value > 0
end

-- Um custo válido tem ao menos um recurso e só quantidades inteiras positivas.
function Cost.IsValid(cost: any): boolean
	if type(cost) ~= "table" then
		return false
	end
	local any = false
	for id, amount in cost do
		if type(id) ~= "string" or not isAmount(amount) then
			return false
		end
		any = true
	end
	return any
end

function Cost.CanAfford(ledger: any, cost: Cost): boolean
	if type(ledger) ~= "table" or not Cost.IsValid(cost) then
		return false
	end
	for id, amount in cost do
		if ResourceLedger.Get(ledger, id) < amount then
			return false
		end
	end
	return true
end

-- Desconta o custo inteiro, ou nada (devolve false) se faltar algum recurso ou o custo for inválido.
function Cost.Spend(ledger: any, cost: Cost): boolean
	if not Cost.CanAfford(ledger, cost) then
		return false
	end
	for id, amount in cost do
		if not ResourceLedger.Spend(ledger, id, amount) then
			error("saldo mudou durante o desconto") -- não acontece após CanAfford; protege a transação
		end
	end
	return true
end

-- Soma uma recompensa ao saldo. Devolve false, sem alterar nada, se a recompensa for inválida.
-- Se o saldo recusar uma parte no meio, gera erro: dentro de DataService.Mutate isso descarta tudo.
function Cost.Grant(ledger: any, reward: Cost): boolean
	if type(ledger) ~= "table" or not Cost.IsValid(reward) then
		return false
	end
	for id, amount in reward do
		if not ResourceLedger.Add(ledger, id, amount) then
			error(`recompensa recusada pelo saldo: {id}`)
		end
	end
	return true
end

return Cost
