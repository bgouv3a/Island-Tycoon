--!strict
--[[
	Saldo de recursos do jogador (contagem por identificador). Lógica pura, sem serviços do Roblox.

	- Só aceita identificadores curtos e quantidades inteiras positivas dentro de um limite.
	- Em caso de valor inválido ou saldo insuficiente, nada é alterado e a função devolve false.
]]

local ResourceLedger = {}

export type Ledger = { [string]: number }

local MAX_ID_LENGTH = 32
local MAX_AMOUNT_PER_OPERATION = 1000

local function isValidId(id: any): boolean
	return type(id) == "string" and #id > 0 and #id <= MAX_ID_LENGTH
end

local function isValidAmount(amount: any): boolean
	return type(amount) == "number" and amount % 1 == 0 and amount > 0 and amount <= MAX_AMOUNT_PER_OPERATION
end

-- Soma `amount` ao saldo de `id`. Retorna false (sem alterar nada) se a entrada for inválida.
function ResourceLedger.Add(ledger: Ledger, id: string, amount: number): boolean
	if not isValidId(id) or not isValidAmount(amount) then
		return false
	end
	local current = ledger[id] or 0
	if type(current) ~= "number" then
		return false
	end
	ledger[id] = current + amount
	return true
end

-- Subtrai `amount` do saldo de `id`. Retorna false (sem alterar nada) se a entrada for inválida
-- ou se o saldo não cobrir a quantidade. Nunca deixa o saldo negativo.
function ResourceLedger.Spend(ledger: Ledger, id: string, amount: number): boolean
	if not isValidId(id) or not isValidAmount(amount) then
		return false
	end
	local current = ledger[id] or 0
	if type(current) ~= "number" or current < amount then
		return false
	end
	ledger[id] = current - amount
	return true
end

function ResourceLedger.Get(ledger: Ledger, id: string): number
	local value = ledger[id]
	if type(value) ~= "number" then
		return 0
	end
	return value
end

return ResourceLedger
