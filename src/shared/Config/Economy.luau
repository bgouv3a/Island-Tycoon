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
	InputCapacity: number?, -- estoque de entrada (só máquinas que consomem matéria-prima)
	Cost: Cost?, -- custo para chegar a este nível (o nível 1 não tem custo)
}

export type OrderTemplate = { Id: string, Name: string, Needs: Cost, Reward: number }

export type Objective = {
	Id: string,
	Text: string,
	Kind: "Stat" | "Buildings" | "Producers" | "Level" | "Expansion" | "Structure" | "Stage",
	Key: string?, -- estatística (Stat), área (Expansion) ou estrutura (Structure)
	Target: number,
	Reward: Cost,
	Guide: "Tree" | "Site" | "Producer" | "Rock" | "Market" | "Expansion" | "Stage", -- alvo do feixe-guia no cliente
	GuideKey: string?, -- estrutura alvo quando Guide = Producer (padrão: Sawmill)
}

local Economy = {
	CurrencyId = "Coins",

	-- Recursos conhecidos, na ordem de exibição. Um material novo (ex.: Planks, tábuas feitas
	-- na Serraria a partir de madeira) entra aqui e passa a aparecer no HUD e no perfil.
	Resources = {
		Coins = { Name = "Moedas", Order = 1 },
		Wood = { Name = "Madeira", Order = 2 },
		Stone = { Name = "Pedra", Order = 3 },
		Planks = { Name = "Tábuas", Order = 4 }, -- material processado (Carpintaria: 2 madeira → 1 tábua)
	},

	-- Recursos coletáveis à mão (palmeiras e rochas da ilha).
	Nodes = {
		Tree = { ResourceId = "Wood", Amount = 2, CooldownSeconds = 6, ReachStuds = 14 },
		Rock = { ResourceId = "Stone", Amount = 2, CooldownSeconds = 12, ReachStuds = 14 },
	},

	-- Mercado no píer: venda de recursos por moedas.
	Market = {
		ReachStuds = 16,
		MaxLot = 200, -- máximo vendido por pedido (MaxLot × maior preço ≤ 1000, limite do ResourceLedger)
		Prices = { Wood = 1, Stone = 3, Planks = 5 }, -- moedas por unidade
	},

	-- Pedidos comerciais do píer: 3 vagas, preenchidas em ordem fixa por Templates (em ciclo).
	-- Pagam cerca de 1,4 a 1,6 vez a venda direta, sempre consumindo os recursos inteiros na entrega.
	-- Sem sorteio, sem prazo e sem renovação diária: o próximo pedido só aparece após uma entrega.
	Orders = {
		Slots = 3,
		Templates = {
			{ Id = "O1", Name = "Lenha para o farol", Needs = { Wood = 20 }, Reward = 32 },
			{ Id = "O2", Name = "Pedras para o cais", Needs = { Stone = 10 }, Reward = 45 },
			{ Id = "O3", Name = "Tábuas para barcos", Needs = { Planks = 6 }, Reward = 45 },
			{ Id = "O4", Name = "Reforma da vila", Needs = { Wood = 30, Stone = 8 }, Reward = 80 },
			{ Id = "O5", Name = "Assoalho do armazém", Needs = { Planks = 12 }, Reward = 90 },
			{ Id = "O6", Name = "Muro do porto", Needs = { Stone = 20 }, Reward = 90 },
			{ Id = "O7", Name = "Casa de praia", Needs = { Wood = 40, Planks = 8 }, Reward = 120 },
			{ Id = "O8", Name = "Estaleiro", Needs = { Planks = 20, Stone = 12 }, Reward = 190 },
		} :: { OrderTemplate },
	},

	-- Estágios da ilha. O estágio 2 é liberado pelo jogador (botão) quando os requisitos são cumpridos.
	Stages = {
		{ Name = "Ilha inicial" },
		{
			Name = "Ilha produtiva",
			Requirements = {
				{ Kind = "Expansion", Key = "E1", Target = 1, Text = "Liberar a Enseada Leste" },
				{ Kind = "Stat", Key = "PlanksProduced", Target = 20, Text = "Produzir 20 tábuas" },
				{ Kind = "Stat", Key = "OrdersDelivered", Target = 2, Text = "Entregar 2 pedidos" },
			},
			Reward = { Coins = 100 } :: Cost,
			OrderBonus = 0.25, -- pedidos pagam 25% a mais
			Benefits = { "+1 máquina de cada tipo", "Pedidos pagam 25% a mais", "100 moedas" },
		},
	},

	-- Estruturas: custo em recursos. MaxPerIsland limita quantas o jogador pode ter (opcional).
	Structures = {
		Fence = { Name = "Cerca", Cost = 2, Kind = "Decor" },
		Cabin = { Name = "Cabana", Cost = 5, Kind = "Home" },
		-- MaxPerStage: limite por estágio da ilha (índice = estágio).
		Sawmill = { Name = "Serraria", Cost = 15, Kind = "Producer", MaxPerIsland = 2, MaxPerStage = { 2, 3 } },
		-- Price: custo com vários recursos (substitui Cost em madeira).
		Quarry = { Name = "Pedreira", Cost = 0, Price = { Wood = 20, Coins = 30 } :: Cost, Kind = "Producer", MaxPerIsland = 1, MaxPerStage = { 1, 2 } },
		Workshop = { Name = "Carpintaria", Cost = 0, Price = { Wood = 40, Stone = 10, Coins = 50 } :: Cost, Kind = "Producer", MaxPerIsland = 1, MaxPerStage = { 1, 2 } },
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
		-- Pedreira: 0,125 pedra/s no nível 1 (a coleta manual rende cerca de 0,3/s).
		Quarry = {
			{ Amount = 1, IntervalSeconds = 8, Capacity = 20 },
			{ Amount = 1, IntervalSeconds = 6, Capacity = 30, Cost = { Coins = 40, Wood = 10 } },
			{ Amount = 2, IntervalSeconds = 8, Capacity = 40, Cost = { Coins = 90, Wood = 25 } },
			{ Amount = 2, IntervalSeconds = 6, Capacity = 60, Cost = { Coins = 180, Wood = 40 } },
		} :: { UpgradeLevel },
		-- Carpintaria: consome 2 madeira por tábua (Gameplay.Production.Producers.Workshop.Input).
		Workshop = {
			{ Amount = 1, IntervalSeconds = 6, Capacity = 20, InputCapacity = 30 },
			{ Amount = 1, IntervalSeconds = 4, Capacity = 30, InputCapacity = 50, Cost = { Coins = 60, Stone = 10 } },
			{ Amount = 2, IntervalSeconds = 5, Capacity = 40, InputCapacity = 80, Cost = { Coins = 140, Stone = 20, Planks = 10 } },
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
		{ Id = "BuildQuarry", Text = "Construa uma Pedreira", Kind = "Structure", Key = "Quarry", Target = 1, Reward = { Wood = 10 }, Guide = "Site" },
		{ Id = "BuildWorkshop", Text = "Construa uma Carpintaria", Kind = "Structure", Key = "Workshop", Target = 1, Reward = { Coins = 20 }, Guide = "Site" },
		{ Id = "MakePlanks", Text = "Abasteça a Carpintaria e produza 5 tábuas", Kind = "Stat", Key = "PlanksProduced", Target = 5, Reward = { Wood = 10 }, Guide = "Producer", GuideKey = "Workshop" },
		{ Id = "DeliverOrder", Text = "Entregue um pedido no mercado do píer", Kind = "Stat", Key = "OrdersDelivered", Target = 1, Reward = { Stone = 5 }, Guide = "Market" },
		{ Id = "ProductiveIsland", Text = "Torne-se uma Ilha produtiva", Kind = "Stage", Target = 2, Reward = { Coins = 50 }, Guide = "Stage" },
	} :: { Objective },
}

return Economy
