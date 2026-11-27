--!strict
--[[
	Regras das construções produtivas (ex.: Serraria). Lógica pura, sem serviços do Roblox.

	- O estoque de cada ponto fica no perfil (Storage: ponto → quantidade) e sobrevive entre sessões.
	- O progresso até a próxima unidade fica só na memória do servidor e começa do zero a cada
	  sessão: não existe produção offline.
	- Estoque cheio pausa a produção e zera o progresso (nada se acumula "por fora").
	- Recolher move todo o estoque para o saldo na mesma operação que zera o estoque:
	  duas coletas seguidas nunca entregam o mesmo estoque duas vezes.
]]

local ResourceLedger = require(script.Parent.ResourceLedger)

local Production = {}

export type Rule = {
	ResourceId: string,
	Amount: number, -- unidades por ciclo
	IntervalSeconds: number, -- duração de um ciclo
	Capacity: number, -- estoque máximo
}

export type Rules = { [string]: Rule } -- estrutura → regra
export type Storage = { [string]: number } -- ponto → estoque

export type HarvestRequest = {
	OwnerSlot: number?,
	TargetSlot: number,
	SiteId: string,
	Distance: number,
	Reach: number,
}

export type HarvestResult = "Ok" | "NoIsland" | "NotOwner" | "NotProducer" | "OutOfReach" | "Empty" | "Invalid"

local function isCount(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 0
end

-- Avança o relógio de um produtor por `dt` segundos.
-- Devolve o estoque novo, o progresso novo e quanto foi produzido neste passo.
function Production.Step(stored: number, progress: number, dt: number, rule: Rule): (number, number, number)
	if not (dt > 0) or not (rule.IntervalSeconds > 0) then
		return stored, progress, 0
	end
	if stored >= rule.Capacity then
		return stored, 0, 0
	end
	local total = progress + dt
	local cycles = math.floor(total / rule.IntervalSeconds)
	if cycles <= 0 then
		return stored, total, 0
	end
	local produced = math.min(cycles * rule.Amount, rule.Capacity - stored)
	local newStored = stored + produced
	local newProgress = if newStored >= rule.Capacity then 0 else total - cycles * rule.IntervalSeconds
	return newStored, newProgress, produced
end

-- Estoque salvo de um ponto, sempre um inteiro entre 0 e a capacidade.
function Production.Stored(storage: any, siteId: string, rule: Rule): number
	if type(storage) ~= "table" then
		return 0
	end
	local value = storage[siteId]
	if not isCount(value) then
		return 0
	end
	return math.min(value, rule.Capacity)
end

-- Limpa o estoque vindo do perfil: mantém só pontos com construção produtiva e valores válidos.
function Production.Sanitize(storage: any, buildings: any, rules: Rules): Storage
	local result: Storage = {}
	if type(buildings) ~= "table" then
		return result
	end
	for siteId, structureId in buildings do
		local rule = if type(structureId) == "string" then rules[structureId] else nil
		if type(siteId) == "string" and rule ~= nil then
			result[siteId] = Production.Stored(storage, siteId, rule)
		end
	end
	return result
end

-- Recolhe todo o estoque do ponto para o saldo do jogador. Em qualquer recusa, nada é alterado.
-- Ordem: ilha → dono → produtor → alcance → estoque.
function Production.Harvest(
	data: { Resources: { [string]: number }, Buildings: { [string]: string }, Storage: Storage },
	request: HarvestRequest,
	rules: Rules
): (HarvestResult, number)
	if request.OwnerSlot == nil then
		return "NoIsland", 0
	end
	if request.OwnerSlot ~= request.TargetSlot then
		return "NotOwner", 0
	end
	local buildings = data.Buildings
	local storage = data.Storage
	local resources = data.Resources
	if type(buildings) ~= "table" or type(storage) ~= "table" or type(resources) ~= "table" then
		return "Invalid", 0
	end
	local structureId = buildings[request.SiteId]
	local rule = if type(structureId) == "string" then rules[structureId] else nil
	if rule == nil then
		return "NotProducer", 0
	end
	-- A forma `not (a <= b)` também rejeita NaN.
	if not (request.Distance <= request.Reach) then
		return "OutOfReach", 0
	end
	local amount = Production.Stored(storage, request.SiteId, rule)
	if amount <= 0 then
		return "Empty", 0
	end
	if not ResourceLedger.Add(resources, rule.ResourceId, amount) then
		return "Invalid", 0
	end
	storage[request.SiteId] = 0
	return "Ok", amount
end

return Production
