--!strict
--[[
	NetService: ponto único de entrada de RemoteEvents do cliente.

	Todo remote passa por: rate limit por jogador → validador de argumentos → handler.
	O cliente envia apenas intenções. O servidor decide o resultado.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage:WaitForChild("Shared").Logic.RateLimiter)

type Limiter = RateLimiter.Limiter

export type Validator = (...any) -> boolean
export type Handler = (player: Player, ...any) -> ()
export type Limit = { Capacity: number, RefillPerSecond: number }

local DEFAULT_LIMIT: Limit = { Capacity = 10, RefillPerSecond = 5 }

local NetService = {}

local remotesFolder: Folder? = nil
local registered: { [string]: boolean } = {}
local limiters: { [Player]: { [string]: Limiter } } = {}

local function onPlayerAdded(player: Player)
	limiters[player] = {}
end

local function onPlayerRemoving(player: Player)
	limiters[player] = nil
end

function NetService.Init()
	assert(remotesFolder == nil, "NetService.Init chamado mais de uma vez")

	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	remotesFolder = folder

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function NetService.Register(name: string, validator: Validator, handler: Handler, limit: Limit?)
	local folder = remotesFolder
	assert(folder ~= nil, "NetService.Init precisa ser chamado antes de Register")
	assert(not registered[name], `Remote já registrado: {name}`)
	registered[name] = true

	local config = limit or DEFAULT_LIMIT

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder

	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		local playerLimiters = limiters[player]
		if playerLimiters == nil then
			return -- jogador já saiu
		end

		local limiter = playerLimiters[name]
		if limiter == nil then
			limiter = RateLimiter.new(config.Capacity, config.RefillPerSecond)
			playerLimiters[name] = limiter
		end

		if not RateLimiter.Consume(limiter, os.clock()) then
			return -- acima do limite: ignora silenciosamente
		end

		if not validator(...) then
			warn(`[NetService] Argumentos inválidos em {name} do jogador {player.UserId}`)
			return
		end

		handler(player, ...)
	end)
end

return NetService
