--!strict
--[[
	Bootstrap do servidor. A ordem importa: NetService antes de DataService.
	Novos serviços devem ser adicionados aqui, e não iniciados em outros scripts.
]]

local NetService = require(script.Services.NetService)
local DataService = require(script.Services.DataService)
local IslandService = require(script.Services.IslandService)
local BuildService = require(script.Services.BuildService)
local ProductionService = require(script.Services.ProductionService)
local MarketService = require(script.Services.MarketService)
local ExpansionService = require(script.Services.ExpansionService)
local ObjectiveService = require(script.Services.ObjectiveService)

NetService.Init()
DataService.Init()
IslandService.Init()
BuildService.Init()
ProductionService.Init()
MarketService.Init()
ExpansionService.Init()
ObjectiveService.Init()
