--!strict
--[[
	Números e nomes da jogabilidade: ilhas, coleta, construção, produção, mercado e expansão.
	Limites vêm daqui, e não de números espalhados pelo código. Preços, custos e recompensas
	ficam em Config/Economy.
	Valores iniciais: definidos para o MVP e ajustáveis após os testes de desempenho (Fase 7).
]]

local Economy = require(script.Parent.Economy)

local Gameplay = {
	Islands = {
		MaxPerServer = 8, -- ilhas por servidor
		Columns = 4, -- ilhas por linha na grade
		Spacing = 160, -- distância entre centros de ilhas, em studs
		-- Chegada do jogador, relativa ao centro (frente da ilha é +Z). O jogador olha para a clareira.
		SpawnOffset = Vector3.new(0, 4, 16),
	},

	Resources = {
		WoodId = "Wood", -- identificador do recurso no perfil (persistido)
		WoodName = "Madeira", -- nome exibido ao jogador
		StoneId = "Stone",
		-- Quantidade, tempo de recuperação e alcance de cada tipo de coleta: Economy.Nodes.
	},

	Build = {
		ReachStuds = 16, -- distância máxima entre o jogador e o ponto de construção
		-- Pontos fixos na clareira (X, Z), relativos ao centro da ilha. Os identificadores são
		-- salvos no perfil (Buildings): podem mudar de posição, mas nunca de nome.
		-- B1 a B4: clareira central (estruturas pequenas). B5 a B8: lotes maiores na frente e nas
		-- laterais, com espaço para a Serraria e construções futuras.
		Sites = {
			B1 = Vector2.new(-13, -1),
			B2 = Vector2.new(-5, -8),
			B3 = Vector2.new(5, -8),
			B4 = Vector2.new(13, -1),
			B5 = Vector2.new(-13, 12),
			B6 = Vector2.new(13, 12),
			B7 = Vector2.new(-23, -3),
			B8 = Vector2.new(23, -3),
			-- Enseada Leste (expansão E1): só ficam disponíveis depois da expansão.
			X1 = Vector2.new(55, -11),
			X2 = Vector2.new(64, 2),
			X3 = Vector2.new(68, -12),
		},
		-- Ponto → expansão que o libera. Pontos fora desta lista estão sempre disponíveis.
		SiteAreas = { X1 = "E1", X2 = "E1", X3 = "E1" },
		-- Estruturas: custo em madeira e limite por ilha (Config/Economy). Aparência: Shared/Art/Models.
		Structures = Economy.Structures,
	},

	-- Construções produtivas, por identificador de estrutura (ver Logic/Production).
	-- Produzem somente enquanto o dono está conectado; o estoque é salvo no perfil (Storage).
	Production = {
		ReachStuds = 16, -- distância máxima para recolher o estoque
		TickSeconds = 1, -- intervalo do relógio de produção no servidor
		-- Regras por nível (quantidade, intervalo, capacidade e custo): Economy.Upgrades.
		Producers = {
			Sawmill = { ResourceId = "Wood", Levels = Economy.Upgrades.Sawmill },
			Quarry = { ResourceId = "Stone", Levels = Economy.Upgrades.Quarry },
			-- Consome Input.Amount de Input.ResourceId por ciclo; sem matéria-prima, não produz.
			Workshop = { ResourceId = "Planks", Input = { ResourceId = "Wood", Amount = 2 }, Levels = Economy.Upgrades.Workshop },
		},
	},

	-- Mercado do píer (preços em Config/Economy). Posição relativa ao centro da ilha (X, Z).
	Market = {
		Offset = Vector2.new(-8, 29),
	},

	-- Expansões: geometria da área nova, relativa ao centro da ilha (X, Z). Custo: Economy.Expansions.
	Expansions = {
		E1 = {
			Center = Vector2.new(61, -5), -- centro do gramado novo
			Radius = 14, -- raio do gramado (a praia vai até Radius + 6)
			BridgeFrom = 33, -- X onde começa a faixa de areia que liga as duas partes
			Sign = Vector2.new(33, -12), -- placa de compra, na praia leste da ilha principal
			ReachStuds = 14,
		},
	},

	Remotes = {
		-- Coleta: pedidos por jogador. Acima disso, a chamada é ignorada.
		CollectCapacity = 5,
		CollectRefillPerSecond = 2,
		-- Construção: pedidos por jogador.
		BuildCapacity = 3,
		BuildRefillPerSecond = 1,
		-- Recolher o estoque de uma construção produtiva.
		HarvestCapacity = 4,
		HarvestRefillPerSecond = 2,
		-- Venda no mercado, melhoria e expansão.
		SellCapacity = 4,
		SellRefillPerSecond = 2,
		UpgradeCapacity = 3,
		UpgradeRefillPerSecond = 1,
		ExpandCapacity = 2,
		ExpandRefillPerSecond = 0.5,
		-- Abastecer máquinas, entregar pedidos e avançar de estágio.
		SupplyCapacity = 4,
		SupplyRefillPerSecond = 2,
		DeliverCapacity = 3,
		DeliverRefillPerSecond = 1,
		StageCapacity = 2,
		StageRefillPerSecond = 0.5,
		-- Pedido do saldo inicial.
		RequestCapacity = 3,
		RequestRefillPerSecond = 1,
	},
}

return Gameplay
