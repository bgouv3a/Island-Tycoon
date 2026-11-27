--!strict
--[[
	MarketService: venda de recursos no mercado do píer da ilha do próprio jogador.

	O cliente só pede "vender N de X". Preço, dono, alcance e saldo são decididos aqui
	(Logic/Market), em uma única mutação: o recurso sai e as moedas entram juntos, ou nada muda.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Economy = require(Shared.Config.Economy)
local Market = require(Shared.Logic.Market)
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

local MarketService = {}

local initialized = false
local resultRemote: RemoteEvent? = nil

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

	resultRemote = NetService.CreateOutgoing("SellResult")
	NetService.Register("SellResource", validateSell, handleSell, {
		Capacity = Gameplay.Remotes.SellCapacity,
		RefillPerSecond = Gameplay.Remotes.SellRefillPerSecond,
	})
end

return MarketService
