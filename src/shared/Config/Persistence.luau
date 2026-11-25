--!strict
--[[
	Configuração de persistência. Usada somente pelo DataService.
	Mudar SchemaVersion exige uma migração registrada no DataService.
]]

local Persistence = {
	StoreName = "IslandRebuild_PlayerData",

	-- No Studio usa-se um DataStore separado, para que testes não alterem dados reais.
	StudioStoreSuffix = "_Studio",

	ProfileKeyPrefix = "Player_",

	SchemaVersion = 1,
}

return Persistence
