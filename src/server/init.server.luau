--!strict
--[[
	Bootstrap do servidor. A ordem importa: NetService antes de DataService.
	Novos serviços devem ser adicionados aqui, e não iniciados em outros scripts.
]]

local NetService = require(script.Services.NetService)
local DataService = require(script.Services.DataService)

NetService.Init()
DataService.Init()
