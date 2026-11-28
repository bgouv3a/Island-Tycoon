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
	Inputs: { [string]: number }, -- estoque de entrada por ponto (máquinas que processam; Logic/Production)
	Orders: { [string]: any }, -- pedidos comerciais: Next e Slots (ver Logic/Orders)
	Stage: number, -- estágio da ilha: 1 inicial, 2 produtiva (ver Logic/Stages)
}

return {}
