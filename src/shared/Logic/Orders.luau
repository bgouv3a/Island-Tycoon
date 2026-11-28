--!strict
--[[
	Pedidos comerciais do mercado do píer. Lógica pura, sem serviços do Roblox.

	- O perfil guarda Orders = { Next = número do próximo pedido, Slots = { [vaga] = número } }.
	  O pedido número N usa o modelo Templates[((N - 1) % #Templates) + 1]: a sequência é fixa e
	  igual para todos (sem sorteio, sem prazo, sem renovação diária).
	- Entregar consome todos os recursos pedidos e paga a recompensa na mesma chamada. A vaga
	  recebe o próximo pedido. O cliente informa a vaga E o número do pedido que está vendo: um
	  pedido repetido (duplo clique, pacote atrasado) não corresponde mais à vaga e é recusado.
	- Ordem: ilha → dono → alcance → vaga → pedido atual → saldo.
]]

local Cost = require(script.Parent.Cost)
local ResourceLedger = require(script.Parent.ResourceLedger)
local Stats = require(script.Parent.Stats)

local Orders = {}

export type Template = { Id: string, Name: string, Needs: Cost.Cost, Reward: number }
export type Config = { Slots: number, Templates: { Template }, CurrencyId: string }

export type DeliverRequest = {
	OwnerSlot: number?,
	TargetSlot: number,
	Slot: number,
	OrderNumber: number,
	Distance: number,
	Reach: number,
	Bonus: number, -- fração extra da recompensa (estágio da ilha), ex.: 0.25
}

export type Result = "Ok" | "NoIsland" | "NotOwner" | "OutOfReach" | "InvalidSlot" | "Stale" | "Insufficient" | "Invalid"

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 1 and value < 2 ^ 31
end

function Orders.TemplateFor(config: Config, number: number): Template
	return config.Templates[((number - 1) % #config.Templates) + 1]
end

-- Recompensa com o bônus do estágio (sempre inteira).
function Orders.RewardFor(template: Template, bonus: number): number
	local safeBonus = if type(bonus) == "number" and bonus == bonus and bonus > 0 then bonus else 0
	return math.floor(template.Reward * (1 + safeBonus))
end

-- Corrige o estado salvo: toda vaga com um pedido válido e Next maior que todos os pedidos.
-- Pedidos já mostrados continuam os mesmos (o jogador não perde o que estava juntando).
function Orders.Normalize(saved: any, config: Config): { Next: number, Slots: { number } }
	local slots: { number } = {}
	local nextNumber = 1
	if type(saved) == "table" then
		if isPositiveInteger(saved.Next) then
			nextNumber = saved.Next
		end
		if type(saved.Slots) == "table" then
			for index = 1, config.Slots do
				local value = saved.Slots[index]
				if isPositiveInteger(value) and value < nextNumber and not table.find(slots, value) then
					slots[index] = value
				end
			end
		end
	end
	for index = 1, config.Slots do
		if slots[index] == nil then
			slots[index] = nextNumber
			nextNumber += 1
		end
	end
	return { Next = nextNumber, Slots = slots }
end

function Orders.Deliver(data: { [string]: any }, request: DeliverRequest, config: Config): (Result, number)
	if request.OwnerSlot == nil then
		return "NoIsland", 0
	end
	if request.OwnerSlot ~= request.TargetSlot then
		return "NotOwner", 0
	end
	if not (request.Distance <= request.Reach) then
		return "OutOfReach", 0
	end
	if not isPositiveInteger(request.Slot) or request.Slot > config.Slots then
		return "InvalidSlot", 0
	end
	if type(data.Resources) ~= "table" then
		return "Invalid", 0
	end
	local state = Orders.Normalize(data.Orders, config)
	local current = state.Slots[request.Slot]
	if request.OrderNumber ~= current then
		return "Stale", 0
	end
	local template = Orders.TemplateFor(config, current)
	if not Cost.Spend(data.Resources, template.Needs) then
		return "Insufficient", 0
	end
	local reward = Orders.RewardFor(template, request.Bonus)
	if not ResourceLedger.Add(data.Resources, config.CurrencyId, reward) then
		error("recompensa do pedido recusada pelo saldo") -- desfaz tudo (Mutate descarta a cópia)
	end
	state.Slots[request.Slot] = state.Next
	state.Next += 1
	data.Orders = state
	Stats.Add(data, "OrdersDelivered", 1)
	Stats.Add(data, "CoinsEarned", reward)
	return "Ok", reward
end

return Orders
