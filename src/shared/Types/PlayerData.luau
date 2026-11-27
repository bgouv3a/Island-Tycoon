--!strict
--[[
	Formato dos dados persistidos de cada jogador.
	Campos de gameplay serão adicionados pelos sistemas aprovados no GDD.
]]

export type PlayerData = {
	SchemaVersion: number,
	Resources: { [string]: number }, -- saldo por identificador de recurso (ver Config/Gameplay)
	Buildings: { [string]: string }, -- construções: ponto da ilha → estrutura (ver Logic/Build)
	Storage: { [string]: number }, -- estoque das construções produtivas: ponto → quantidade (ver Logic/Production)
	Levels: { [string]: number }, -- nível de melhoria por ponto (ausente = 1; ver Logic/Upgrade)
	Expansions: { [string]: boolean }, -- expansões liberadas (ver Config/Economy.Expansions)
	Stats: { [string]: number }, -- estatísticas acumuladas, usadas pelos objetivos (ver Logic/Stats)
	Objective: number, -- quantos objetivos iniciais foram concluídos (ver Logic/Objectives)
}

return {}
