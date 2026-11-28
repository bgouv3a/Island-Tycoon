--!strict
--[[
	DataService: camada de abstração ÚNICA entre o jogo e o ProfileStore.

	Regras:
	- Nenhum outro serviço deve require() o ProfileStore. Use Read, GetData, Mutate, IsLoaded,
	  OnLoaded e OnChanged.
	- Um perfil é carregado com lock de sessão, então só um servidor escreve os dados do jogador.
	- Dados de versão mais nova ou inválida nunca são alterados por este código (ver SchemaMigrator).
	- O fechamento do servidor é tratado pelo próprio ProfileStore (game:BindToClose).
	  Aqui só liberamos a sessão quando o jogador sai.
	- Só no Studio, com o atributo Persistence.StudioFreshProfileAttribute no Workspace, os perfis
	  vêm do ProfileStore.Mock: novos, temporários e sem acesso a nenhum DataStore.

	Custo das cópias: Mutate copia o perfil (transação) e GetData devolve uma cópia. Caminhos
	frequentes (relógio de produção, objetivos) usam Read, que não copia nada.

	Proteção do perfil: os dados guardados ficam congelados (DeepCopy.Freeze) depois de cada
	carga e de cada Mutate. Read entrega essa tabela congelada: qualquer tentativa de escrita gera
	erro, então nada contorna o Mutate. Read também não pode esperar (yield): a leitura roda em
	uma corrotina e é encerrada com erro se tentar esperar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Persistence = require(Shared.Config.Persistence)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local SchemaMigrator = require(Shared.Logic.SchemaMigrator)
local DeepCopy = require(Shared.Logic.DeepCopy)
local Transaction = require(Shared.Logic.Transaction)
local PlayerMigrations = require(Shared.Logic.PlayerMigrations)
local ProfileSource = require(Shared.Logic.ProfileSource)

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

-- Migrações registradas por versão de destino (ver Logic/PlayerMigrations).
local MIGRATIONS: { [number]: Migration } = PlayerMigrations

local MSG_LOAD_FAILED = "Não foi possível carregar seus dados. Tente entrar novamente em alguns instantes."
local MSG_INCOMPATIBLE = "Seus dados são de uma versão incompatível deste servidor. Contate o suporte."
local MSG_SESSION_ENDED = "Sua sessão foi encerrada porque sua conta foi carregada em outro servidor."

local store: any = nil
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (player: Player) -> () } = {}
local changedCallbacks: { (player: Player) -> () } = {}
local changePending: { [Player]: boolean } = {}
local useMock = false

local function getStoreName(): string
	if RunService:IsStudio() then
		return Persistence.StoreName .. Persistence.StudioStoreSuffix
	end
	return Persistence.StoreName
end

local function kickIfPresent(player: Player, message: string)
	if player.Parent == Players then
		player:Kick(message)
	end
end

local function loadProfile(player: Player)
	local key = Persistence.ProfileKeyPrefix .. tostring(player.UserId)

	-- Cancel interrompe as tentativas se o jogador sair durante o carregamento.
	local source = if useMock then store.Mock else store
	local profile: Profile? = source:StartSessionAsync(key, {
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
		local working = DeepCopy.Clone(profile.Data)
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
	DeepCopy.Freeze(profile.Data) -- daqui em diante, só Mutate troca os dados

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
	changePending[player] = nil
	if profile ~= nil then
		profile:EndSession()
	end
end

function DataService.Init()
	assert(store == nil, "DataService.Init chamado mais de uma vez")

	-- Template de perfil novo. Campos novos aqui também devem existir em PlayerMigrations.
	store = ProfileStore.New(getStoreName(), {
		SchemaVersion = CURRENT_VERSION,
		Resources = {},
		Buildings = {},
		Storage = {},
		Levels = {},
		Expansions = {},
		Stats = {},
		Objective = 0,
		Inputs = {},
		Orders = {},
		Stage = 1,
	})

	local requested = Workspace:GetAttribute(Persistence.StudioFreshProfileAttribute)
	useMock = ProfileSource.UseMock(RunService:IsStudio(), requested)
	if requested ~= nil and not RunService:IsStudio() then
		warn("[DataService] Atributo de perfil temporário ignorado: só é permitido no Studio")
	end
	if useMock then
		warn("[DataService] Studio com perfil temporário (ProfileStore.Mock): nada será lido nem salvo no DataStore")
	end

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

-- Lê os dados do jogador SEM copiar: `reader` recebe a tabela real e não pode alterá-la nem
-- esperar (yield). Devolve o que `reader` devolver, ou nil se o perfil não estiver ativo.
function DataService.Read<T>(player: Player, reader: (data: PlayerData) -> T): T?
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end
	-- Os dados estão congelados (escrita gera erro). A corrotina garante que a leitura não espere.
	local thread = coroutine.create(reader)
	local ok, result = coroutine.resume(thread, profile.Data)
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		error("DataService.Read: a leitura não pode esperar (yield)", 2)
	end
	if not ok then
		error(result, 2)
	end
	return result
end

-- Cópia somente leitura dos dados do jogador, ou nil se o perfil não estiver carregado e ativo.
-- Alterar a cópia não altera os dados salvos: para alterar, use Mutate.
function DataService.GetData(player: Player): PlayerData?
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end
	return DeepCopy.Clone(profile.Data)
end

-- Altera os dados do jogador de forma transacional: a função recebe uma cópia, e o resultado só
-- substitui os dados se ela terminar sem erro. Retorna false se o perfil não estiver ativo ou se
-- a função falhar; nesse caso os dados permanecem exatamente como estavam.
function DataService.Mutate(player: Player, mutator: (data: PlayerData) -> ()): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	-- O mutador também não pode esperar: outra mutação no meio seria perdida ao trocar os dados.
	local ok, result = Transaction.Apply(profile.Data, function(working)
		local thread = coroutine.create(mutator)
		local resumed, err = coroutine.resume(thread, working)
		if coroutine.status(thread) ~= "dead" then
			coroutine.close(thread)
			error("DataService.Mutate: a mutação não pode esperar (yield)")
		end
		if not resumed then
			error(err)
		end
	end)
	if not ok then
		warn(`[DataService] Mutação cancelada para o jogador {player.UserId}: {tostring(result)}`)
		return false
	end
	profile.Data = DeepCopy.Freeze(result)
	-- Avisa os interessados uma vez por quadro, mesmo com várias mutações seguidas.
	if #changedCallbacks > 0 and not changePending[player] then
		changePending[player] = true
		task.defer(function()
			if not changePending[player] then
				return -- jogador saiu
			end
			changePending[player] = nil
			for _, callback in changedCallbacks do
				task.spawn(callback, player)
			end
		end)
	end
	return true
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Registra uma função chamada quando o perfil de um jogador é carregado.
function DataService.OnLoaded(callback: (player: Player) -> ())
	table.insert(loadedCallbacks, callback)
end

-- Registra uma função chamada depois de mutações bem-sucedidas (agrupadas por quadro).
function DataService.OnChanged(callback: (player: Player) -> ())
	table.insert(changedCallbacks, callback)
end

-- Verdadeiro se este servidor usa perfis temporários (ProfileStore.Mock, só no Studio).
function DataService.IsMock(): boolean
	return useMock
end

return DataService
