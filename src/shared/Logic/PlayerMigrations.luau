--!strict
--[[
	Migrações dos dados do jogador, por versão de destino. Lógica pura (testável sem o Roblox).
	O DataService registra esta tabela em MIGRATIONS e a aplica sobre uma cópia dos dados.

	- v2: adiciona o saldo de recursos (Resources). Dados antigos recebem um saldo vazio.
	- v3: adiciona as construções (Buildings). Dados antigos recebem nenhuma construção.
	- v4: adiciona o estoque das construções produtivas (Storage). Dados antigos recebem estoque vazio.
	- v5: adiciona níveis de melhoria (Levels), expansões (Expansions), estatísticas (Stats) e
	  objetivos concluídos (Objective). Quem já construiu algo já coletou madeira: a estatística
	  WoodCollected começa no alvo do primeiro objetivo, para não pedir de novo o que já foi feito.
]]

-- Alvo do primeiro objetivo (Config/Economy.Objectives[1]); repetido aqui para a migração não
-- depender da configuração atual, que pode mudar depois.
local V5_WOOD_COLLECTED_FOR_BUILDERS = 6

local SchemaMigrator = require(script.Parent.SchemaMigrator)

export type Migration = SchemaMigrator.Migration

local MIGRATIONS: { [number]: Migration } = {
	[2] = function(data: { [string]: any })
		if type(data.Resources) ~= "table" then
			data.Resources = {}
		end
	end,
	[3] = function(data: { [string]: any })
		if type(data.Buildings) ~= "table" then
			data.Buildings = {}
		end
	end,
	[4] = function(data: { [string]: any })
		if type(data.Storage) ~= "table" then
			data.Storage = {}
		end
	end,
	[5] = function(data: { [string]: any })
		for _, field in { "Levels", "Expansions", "Stats" } do
			if type(data[field]) ~= "table" then
				data[field] = {}
			end
		end
		if type(data.Objective) ~= "number" then
			data.Objective = 0
		end
		local built = type(data.Buildings) == "table" and next(data.Buildings) ~= nil
		local collected = data.Stats.WoodCollected
		if built and (type(collected) ~= "number" or collected < V5_WOOD_COLLECTED_FOR_BUILDERS) then
			data.Stats.WoodCollected = V5_WOOD_COLLECTED_FOR_BUILDERS
		end
	end,
}

return MIGRATIONS
