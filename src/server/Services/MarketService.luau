--!strict
--[[
	MarketService: venda de recursos no mercado do píer da ilha do próprio jogador.

	O cliente só pede "vender N de X". Preço, dono, alcance e saldo são decididos aqui
	(Logic/Market), em uma única mutação: o recurso sai e as moedas entram juntos, ou nada muda.

	Pedidos comerciais (Logic/Orders): 3 vagas em sequência fixa. O cliente pede "entregar o
	pedido N da vaga V"; recursos, recompensa (com o bônus do estágio) e a troca do pedido da vaga
	acontecem na mesma mutação. O estado dos pedidos vai ao cliente por OrdersChanged, só quando muda.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Economy = require(Shared.Config.Economy)
local Market = require(Shared.Logic.Market)
local Orders = require(Shared.Logic.Orders)
local Stages = require(Shared.Logic.Stages)
local Validate = require(Shared.Logic.Validate)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local NetService = require(script.Parent.NetService)

local MAX_ID_LENGTH = 32
local LEDGER_LIMIT = 1000 -- maior quantidade por operação aceita pelo ResourceLedger

local CONFIG: Market.Config = {
	CurrencyId = Economy.CurrencyId,
	MaxLot = Economy.Market.MaxLot,
	Prices = Economy.Market.Prices,
}

local ORDERS: Orders.Config = {
	Slots = Economy.Orders.Slots,
	Templates = Economy.Orders.Templates,
	CurrencyId = Economy.CurrencyId,
}
local STAGES: { Stages.Stage } = Economy.Stages :: any

local MarketService = {}

local initialized = false
local resultRemote: RemoteEvent? = nil
local orderRemote: RemoteEvent? = nil
local ordersRemote: RemoteEvent? = nil
local lastOrders: { [Player]: string } = {}

local function playerDistance(player: Player, part: BasePart?): number
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if part == nil or root == nil or not root:IsA("BasePart") then
		return math.huge
	end
	return ((root :: BasePart).Position - part.Position).Magnitude
end

-- Estado dos pedidos para o cliente: o que cada vaga pede, a recompensa e o progresso (saldo).
local function ordersState(data: { [string]: any }): { [string]: any }
	local state = Orders.Normalize(data.Orders, ORDERS)
	local bonus = Stages.OrderBonus(data, STAGES)
	local list = {}
	for slot, number in state.Slots do
		local template = Orders.TemplateFor(ORDERS, number)
		local have: { [string]: number } = {}
		for resourceId in template.Needs do
			local value = data.Resources[resourceId]
			have[resourceId] = if type(value) == "number" then value else 0
		end
		table.insert(list, {
			Slot = slot,
			Number = number,
			Id = template.Id,
			Name = template.Name,
			Needs = template.Needs,
			Have = have,
			Reward = Orders.RewardFor(template, bonus),
		})
	end
	return { Orders = list, Bonus = bonus }
end

local function sendOrders(player: Player, force: boolean?)
	local remote = ordersRemote
	if remote == nil then
		return
	end
	local state = DataService.Read(player, ordersState)
	if state == nil then
		return
	end
	local parts = { tostring(state.Bonus) }
	for _, order in state.Orders do
		table.insert(parts, `{order.Number}`)
		for resourceId, amount in order.Have do
			table.insert(parts, `{resourceId}={math.min(amount, order.Needs[resourceId])}`)
		end
	end
	local key = table.concat(parts, ";")
	if not force and lastOrders[player] == key then
		return
	end
	lastOrders[player] = key
	remote:FireClient(player, state)
end

local function validateDeliver(slot: any, number: any): boolean
	return type(slot) == "number" and slot == slot and type(number) == "number" and number == number
end

local function handleDeliver(player: Player, slot: number, number: number)
	local islandSlot = IslandService.GetSlot(player)
	local counter = if islandSlot ~= nil then IslandService.GetMarket(islandSlot) else nil
	local request: Orders.DeliverRequest = {
		OwnerSlot = islandSlot,
		TargetSlot = islandSlot or -1,
		Slot = slot,
		OrderNumber = number,
		Distance = playerDistance(player, counter),
		Reach = Economy.Market.ReachStuds,
		Bonus = 0,
	}
	local result: string = "NotLoaded"
	local reward = 0
	local saved = DataService.Mutate(player, function(data)
		request.Bonus = Stages.OrderBonus(data :: any, STAGES)
		result, reward = Orders.Deliver(data :: any, request, ORDERS)
	end)
	if not saved then
		result, reward = "NotLoaded", 0
	end
	if result == "Ok" then
		IslandService.SendSnapshot(player)
		sendOrders(player, true)
	end
	local remote = orderRemote
	if remote ~= nil then
		remote:FireClient(player, slot, result, reward)
	end
end

local function onLoaded(player: Player)
	DataService.Mutate(player, function(data)
		data.Orders = Orders.Normalize(data.Orders, ORDERS)
	end)
	lastOrders[player] = nil
	sendOrders(player, true)
end

local function validateSell(resourceId: any, amount: any): boolean
	return Validate.IsString(resourceId, MAX_ID_LENGTH) and type(amount) == "number" and amount == amount
end

local function handleSell(player: Player, resourceId: string, amount: number)
	local slot = IslandService.GetSlot(player)
	local counter = if slot ~= nil then IslandService.GetMarket(slot) else nil
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local distance = math.huge
	if counter ~= nil and root ~= nil and root:IsA("BasePart") then
		distance = ((root :: BasePart).Position - counter.Position).Magnitude
	end

	local request: Market.SellRequest = {
		OwnerSlot = slot,
		TargetSlot = slot or -1, -- o mercado usado é sempre o da ilha do próprio jogador
		ResourceId = resourceId,
		Amount = amount,
		Distance = distance,
		Reach = Economy.Market.ReachStuds,
	}

	local result: string = "NotLoaded"
	local earned = 0
	local saved = DataService.Mutate(player, function(data)
		result, earned = Market.Sell(data :: any, request, CONFIG)
	end)
	if not saved then
		result, earned = "NotLoaded", 0
	end

	if result == "Ok" then
		IslandService.SendSnapshot(player)
	end
	local remote = resultRemote
	if remote ~= nil then
		remote:FireClient(player, resourceId, result, if result == "Ok" then amount else 0, earned)
	end
end

function MarketService.Init()
	assert(not initialized, "MarketService.Init chamado mais de uma vez")
	initialized = true

	for resourceId, price in CONFIG.Prices do
		assert(Economy.Resources[resourceId] ~= nil, `Preço de recurso desconhecido: {resourceId}`)
		assert(price > 0 and price % 1 == 0, `Preço inválido: {resourceId}`)
		assert(CONFIG.MaxLot * price <= LEDGER_LIMIT, `MaxLot × preço passa do limite do saldo: {resourceId}`)
	end

	for _, template in ORDERS.Templates do
		assert(template.Reward > 0 and template.Reward % 1 == 0, `Recompensa inválida: {template.Id}`)
		for resourceId in template.Needs do
			assert(Economy.Resources[resourceId] ~= nil, `Pedido com recurso desconhecido: {template.Id}`)
		end
	end

	resultRemote = NetService.CreateOutgoing("SellResult")
	orderRemote = NetService.CreateOutgoing("OrderResult")
	ordersRemote = NetService.CreateOutgoing("OrdersChanged")
	NetService.Register("DeliverOrder", validateDeliver, handleDeliver, {
		Capacity = Gameplay.Remotes.DeliverCapacity,
		RefillPerSecond = Gameplay.Remotes.DeliverRefillPerSecond,
	})
	NetService.Register("RequestOrders", function(): boolean
		return true
	end, function(player: Player)
		sendOrders(player, true)
	end, { Capacity = 3, RefillPerSecond = 1 })
	DataService.OnLoaded(onLoaded)
	DataService.OnChanged(function(player: Player)
		sendOrders(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastOrders[player] = nil
	end)
	NetService.Register("SellResource", validateSell, handleSell, {
		Capacity = Gameplay.Remotes.SellCapacity,
		RefillPerSecond = Gameplay.Remotes.SellRefillPerSecond,
	})
end

return MarketService
