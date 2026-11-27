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

	-- Só no Studio: com este atributo verdadeiro no Workspace (definido em modo Edit, antes do Play),
	-- cada jogador recebe um perfil novo e temporário do ProfileStore.Mock, que fica só na memória
	-- e não lê nem grava nenhum DataStore. Serve para testar a experiência de jogador novo.
	StudioFreshProfileAttribute = "FreshProfile",

	SchemaVersion = 5,
}

return Persistence
