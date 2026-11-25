--!strict
--[[
	DataService: camada de abstração ÚNICA entre o jogo e o ProfileStore.

	Regras:
	- Nenhum outro serviço deve require() o ProfileStore. Use GetData, Mutate, IsLoaded, OnLoaded.
	- Um perfil é carregado com lock de sessão, então só um servidor escreve os dados do jogador.
	- Dados de versão mais nova ou inválida nunca são alterados por este código (ver SchemaMigrator).
	- O fechamento do servidor é tratado pelo próprio ProfileStore (game:BindToClose).
	  Aqui só liberamos a sessão quando o jogador sai.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Persistence = require(Shared.Config.Persistence)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local SchemaMigrator = require(Shared.Logic.SchemaMigrator)

-- Biblioteca de terceiros (Wally: lm-loleris/profilestore@=1.0.3).
local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))

type PlayerData = PlayerDataTypes.PlayerData
type Migration = SchemaMigrator.Migration

-- Tipo mínimo do perfil que este serviço usa.
type Profile = {
	Data: PlayerData,
	IsActive: (self: Profile) -> boolean,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> any },
}

local DataService = {}

local CURRENT_VERSION: number = Persistence.SchemaVersion

-- Migrações registradas por versão de destino. Ex.: MIGRATIONS[2] = function(data) ... end
local MIGRATIONS: { [number]: Migration } = {}

local MSG_LOAD_FAILED = "Não foi possível carregar seus dados. Tente entrar novamente em alguns instantes."
local MSG_INCOMPATIBLE = "Seus dados são de uma versão incompatível deste servidor. Contate o suporte."
local MSG_SESSION_ENDED = "Sua sessão foi encerrada porque sua conta foi carregada em outro servidor."

local store: any = nil
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (player: Player) -> () } = {}

local function getStoreName(): string
	if RunService:IsStudio() then
		return Persistence.StoreName .. Persistence.StudioStoreSuffix
	end
	return Persistence.StoreName
end

-- Cópia profunda de dados JSON-like (tabelas, strings, números, booleanos).
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy: { [any]: any } = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

local function kickIfPresent(player: Player, message: string)
	if player.Parent == Players then
		player:Kick(message)
	end
end

local function loadProfile(player: Player)
	local key = Persistence.ProfileKeyPrefix .. tostring(player.UserId)

	-- Cancel interrompe as tentativas se o jogador sair durante o carregamento.
	local profile: Profile? = store:StartSessionAsync(key, {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		warn(`[DataService] Não foi possível iniciar a sessão do jogador {player.UserId}`)
		kickIfPresent(player, MSG_LOAD_FAILED)
		return
	end

	-- O jogador saiu enquanto carregava: libera a sessão e termina.
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	-- Verifica a versão ANTES de reconciliar: Reconcile altera Data e isso não pode
	-- acontecer em dados que não entendemos.
	local storedVersion = profile.Data.SchemaVersion
	local status = SchemaMigrator.GetStatus(storedVersion, CURRENT_VERSION)

	if status == "TooNew" or status == "Invalid" then
		warn(`[DataService] Dados do jogador {player.UserId} com status {status} (versão {tostring(storedVersion)})`)
		-- Os dados não foram alterados, então liberar a sessão regrava o mesmo conteúdo.
		profile:EndSession()
		kickIfPresent(player, MSG_INCOMPATIBLE)
		return
	end

	if status == "NeedsMigration" then
		-- Migra uma cópia: se uma migração falhar no meio, os dados originais não são alterados
		-- e a sessão é liberada sem gravar nada de parcial.
		local working = deepCopy(profile.Data)
		local ok, err =
			pcall(SchemaMigrator.Apply, working :: any, storedVersion :: number, CURRENT_VERSION, MIGRATIONS)
		if not ok then
			warn(`[DataService] Falha na migração do jogador {player.UserId}: {tostring(err)}`)
			profile:EndSession()
			kickIfPresent(player, MSG_INCOMPATIBLE)
			return
		end
		profile.Data = working :: any
	end

	-- Preenche campos novos que estejam faltando com o template.
	profile:Reconcile()
	profile.Data.SchemaVersion = CURRENT_VERSION

	profile:AddUserId(player.UserId)
	profiles[player] = profile

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		kickIfPresent(player, MSG_SESSION_ENDED)
	end)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerAdded(player: Player)
	task.spawn(loadProfile, player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile ~= nil then
		profile:EndSession()
	end
end

function DataService.Init()
	assert(store == nil, "DataService.Init chamado mais de uma vez")

	store = ProfileStore.New(getStoreName(), { SchemaVersion = CURRENT_VERSION })

	ProfileStore.OnError:Connect(function(message: string, storeName: string, profileKey: string)
		warn(`[DataService] Erro do ProfileStore em {storeName}/{profileKey}: {message}`)
	end)

	ProfileStore.OnCriticalToggle:Connect(function(isCritical: boolean)
		if isCritical then
			warn("[DataService] ProfileStore em estado crítico: muitos erros consecutivos no DataStore")
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Jogadores que entraram antes da inicialização do serviço.
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
end

-- Dados do jogador ou nil se ainda não carregados. Não alterar diretamente: use Mutate.
function DataService.GetData(player: Player): PlayerData?
	local profile = profiles[player]
	if profile == nil then
		return nil
	end
	return profile.Data
end

-- Altera os dados do jogador. Retorna false se o perfil não estiver carregado ou ativo.
function DataService.Mutate(player: Player, mutator: (data: PlayerData) -> ()): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	mutator(profile.Data)
	return true
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Registra uma função chamada quando o perfil de um jogador é carregado.
function DataService.OnLoaded(callback: (player: Player) -> ())
	table.insert(loadedCallbacks, callback)
end

return DataService
