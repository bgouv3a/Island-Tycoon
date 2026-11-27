--!strict
--[[
	Economia do Island Tycoon: recursos, preços, custos, melhorias, expansões e recompensas.
	Todos os números de balanceamento ficam aqui (valores PROVISÓRIOS, ver docs/decisoes.md D-034).

	Referência de ritmo usada no balanceamento (estimativa, a confirmar em teste com jogadores):
	- coleta manual: cerca de 0,6 madeira/s andando entre as palmeiras;
	- Serraria nível 1: 0,2 madeira/s (vale menos que a coleta, mas trabalha sozinha);
	- Serraria nível 5: 1 madeira/s (passa a coleta manual: a automação compensa).

	Identificadores (Coins, Wood, Stone, E1, ...) são salvos no perfil: podem mudar de nome
	exibido e de valor, mas nunca de identificador.
]]

export type Cost = { [string]: number } -- recurso → quantidade

export type UpgradeLevel = {
	Amount: number, -- unidades por ciclo
	IntervalSeconds: number,
	Capacity: number,
	Cost: Cost?, -- custo para chegar a este nível (o nível 1 não tem custo)
}

export type Objective = {
	Id: string,
	Text: string,
	Kind: "Stat" | "Buildings" | "Producers" | "Level" | "Expansion",
	Key: string?, -- estatística (Kind = Stat) ou área (Kind = Expansion)
	Target: number,
	Reward: Cost,
	Guide: "Tree" | "Site" | "Producer" | "Rock" | "Market" | "Expansion", -- alvo do feixe-guia no cliente
}

local Economy = {
	CurrencyId = "Coins",

	-- Recursos conhecidos, na ordem de exibição. Um material novo (ex.: Planks, tábuas feitas
	-- na Serraria a partir de madeira) entra aqui e passa a aparecer no HUD e no perfil.
	Resources = {
		Coins = { Name = "Moedas", Order = 1 },
		Wood = { Name = "Madeira", Order = 2 },
		Stone = { Name = "Pedra", Order = 3 },
	},

	-- Recursos coletáveis à mão (palmeiras e rochas da ilha).
	Nodes = {
		Tree = { ResourceId = "Wood", Amount = 2, CooldownSeconds = 6, ReachStuds = 14 },
		Rock = { ResourceId = "Stone", Amount = 2, CooldownSeconds = 12, ReachStuds = 14 },
	},

	-- Mercado no píer: venda de recursos por moedas.
	Market = {
		ReachStuds = 16,
		MaxLot = 300, -- máximo vendido por pedido (MaxLot × maior preço ≤ 1000, limite do ResourceLedger)
		Prices = { Wood = 1, Stone = 3 }, -- moedas por unidade
	},

	-- Estruturas: custo em recursos. MaxPerIsland limita quantas o jogador pode ter (opcional).
	Structures = {
		Fence = { Name = "Cerca", Cost = 2, Kind = "Decor" },
		Cabin = { Name = "Cabana", Cost = 5, Kind = "Home" },
		Sawmill = { Name = "Serraria", Cost = 15, Kind = "Producer", MaxPerIsland = 2 },
	},

	-- Melhorias das construções produtivas, por estrutura. O índice é o nível.
	Upgrades = {
		Sawmill = {
			{ Amount = 1, IntervalSeconds = 5, Capacity = 30 },
			{ Amount = 1, IntervalSeconds = 3, Capacity = 45, Cost = { Coins = 25, Stone = 4 } },
			{ Amount = 2, IntervalSeconds = 4, Capacity = 60, Cost = { Coins = 60, Stone = 10 } },
			{ Amount = 2, IntervalSeconds = 3, Capacity = 90, Cost = { Coins = 140, Stone = 20 } },
			{ Amount = 3, IntervalSeconds = 3, Capacity = 120, Cost = { Coins = 300, Stone = 40 } },
		} :: { UpgradeLevel },
	},

	-- Expansões territoriais. Os pontos de construção de cada área estão em Config/Gameplay.
	Expansions = {
		E1 = { Name = "Enseada Leste", Cost = { Coins = 120, Wood = 40, Stone = 20 } :: Cost },
	},

	-- Objetivos iniciais, em ordem. Recompensas moderadas, entregues pelo servidor ao concluir.
	Objectives = {
		{ Id = "CollectWood", Text = "Colete 6 de madeira nas palmeiras", Kind = "Stat", Key = "WoodCollected", Target = 6, Reward = { Wood = 4 }, Guide = "Tree" },
		{ Id = "FirstBuild", Text = "Construa uma cerca ou cabana", Kind = "Buildings", Target = 1, Reward = { Wood = 6 }, Guide = "Site" },
		{ Id = "BuildSawmill", Text = "Construa a Serraria (15 de madeira)", Kind = "Producers", Target = 1, Reward = { Coins = 10 }, Guide = "Site" },
		{ Id = "Harvest", Text = "Recolha a madeira da Serraria", Kind = "Stat", Key = "Harvested", Target = 1, Reward = { Wood = 5 }, Guide = "Producer" },
		{ Id = "CollectStone", Text = "Colete 4 de pedra nas rochas", Kind = "Stat", Key = "StoneCollected", Target = 4, Reward = { Coins = 10 }, Guide = "Rock" },
		{ Id = "Sell", Text = "Ganhe 10 moedas vendendo no píer", Kind = "Stat", Key = "CoinsEarned", Target = 10, Reward = { Coins = 15 }, Guide = "Market" },
		{ Id = "Upgrade", Text = "Melhore a Serraria para o nível 2", Kind = "Level", Target = 2, Reward = { Stone = 6 }, Guide = "Producer" },
		{ Id = "Expand", Text = "Expanda a ilha para a Enseada Leste", Kind = "Expansion", Key = "E1", Target = 1, Reward = { Coins = 40 }, Guide = "Expansion" },
	} :: { Objective },
}

return Economy
