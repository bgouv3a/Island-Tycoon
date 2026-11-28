--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Logic = ReplicatedStorage.Shared.Logic
	local Production = require(Logic.Production)
	local Orders = require(Logic.Orders)
	local Stages = require(Logic.Stages)
	local Build = require(Logic.Build)
	local Objectives = require(Logic.Objectives)
	local DeepCopy = require(Logic.DeepCopy)
	local ProfileSource = require(Logic.ProfileSource)
	local Economy = require(ReplicatedStorage.Shared.Config.Economy)

	local WORKSHOP: Production.Rule = {
		ResourceId = "Planks",
		Amount = 1,
		IntervalSeconds = 6,
		Capacity = 20,
		InputId = "Wood",
		InputAmount = 2,
		InputCapacity = 30,
	}

	describe("Production.StepConverter", function()
		it("consome 2 de entrada para cada tábua produzida", function()
			local stored, input, progress, produced, consumed = Production.StepConverter(0, 10, 0, 12, WORKSHOP)
			expect(produced).to.equal(2)
			expect(consumed).to.equal(4)
			expect(stored).to.equal(2)
			expect(input).to.equal(6)
			expect(progress).to.equal(0)
		end)

		it("para sem matéria-prima e zera o progresso (nada produzido sem consumo)", function()
			local stored, input, progress, produced, consumed = Production.StepConverter(0, 1, 5, 30, WORKSHOP)
			expect(produced).to.equal(0)
			expect(consumed).to.equal(0)
			expect(stored).to.equal(0)
			expect(input).to.equal(1)
			expect(progress).to.equal(0)
		end)

		it("produz só o que a entrada permite", function()
			local stored, input, _, produced = Production.StepConverter(0, 5, 0, 60, WORKSHOP)
			expect(produced).to.equal(2)
			expect(input).to.equal(1)
			expect(stored).to.equal(2)
		end)

		it("para com a saída cheia sem consumir", function()
			local stored, input, _, produced, consumed = Production.StepConverter(20, 30, 0, 60, WORKSHOP)
			expect(produced).to.equal(0)
			expect(consumed).to.equal(0)
			expect(stored).to.equal(20)
			expect(input).to.equal(30)
		end)

		it("ignora passos inválidos", function()
			local _, _, _, produced = Production.StepConverter(0, 30, 0, 0 / 0, WORKSHOP)
			expect(produced).to.equal(0)
		end)
	end)

	describe("Production.Supply", function()
		local rules: Production.Rules = { Workshop = WORKSHOP, Sawmill = { ResourceId = "Wood", Amount = 1, IntervalSeconds = 5, Capacity = 30 } }
		local function request(amount: number, site: string?, distance: number?): Production.SupplyRequest
			return { OwnerSlot = 1, TargetSlot = 1, SiteId = site or "B7", Distance = distance or 3, Reach = 16, Amount = amount }
		end

		it("move madeira do saldo para a entrada, limitado ao espaço livre", function()
			local data: { [string]: any } = { Resources = { Wood = 100 }, Buildings = { B7 = "Workshop" }, Inputs = { B7 = 25 } }
			local result, moved = Production.Supply(data, request(20), rules)
			expect(result).to.equal("Ok")
			expect(moved).to.equal(5)
			expect(data.Inputs.B7).to.equal(30)
			expect(data.Resources.Wood).to.equal(95)
		end)

		it("move só o saldo disponível e recusa sem saldo ou com entrada cheia", function()
			local data: { [string]: any } = { Resources = { Wood = 3 }, Buildings = { B7 = "Workshop" } }
			local _, moved = Production.Supply(data, request(10), rules)
			expect(moved).to.equal(3)
			expect((Production.Supply(data, request(10), rules))).to.equal("Insufficient")
			data.Inputs.B7 = 30
			data.Resources.Wood = 50
			expect((Production.Supply(data, request(10), rules))).to.equal("InputFull")
			expect(data.Resources.Wood).to.equal(50)
		end)

		it("recusa máquina sem entrada, quantidade inválida e fora do alcance", function()
			local data: { [string]: any } = { Resources = { Wood = 50 }, Buildings = { B7 = "Workshop", B5 = "Sawmill" } }
			expect((Production.Supply(data, request(5, "B5"), rules))).to.equal("NoInput")
			expect((Production.Supply(data, request(0), rules))).to.equal("InvalidAmount")
			expect((Production.Supply(data, request(2.5), rules))).to.equal("InvalidAmount")
			expect((Production.Supply(data, request(0 / 0), rules))).to.equal("InvalidAmount")
			expect((Production.Supply(data, request(5, "B7", 40), rules))).to.equal("OutOfReach")
			expect(data.Resources.Wood).to.equal(50)
			expect(data.Inputs).to.equal(nil)
		end)
	end)

	describe("Orders", function()
		local config: Orders.Config = {
			Slots = 3,
			CurrencyId = "Coins",
			Templates = {
				{ Id = "A", Name = "", Needs = { Wood = 20 }, Reward = 32 },
				{ Id = "B", Name = "", Needs = { Stone = 10 }, Reward = 45 },
				{ Id = "C", Name = "", Needs = { Planks = 6 }, Reward = 45 },
				{ Id = "D", Name = "", Needs = { Wood = 5, Stone = 5 }, Reward = 30 },
			},
		}
		local function request(slot: number, number: number, distance: number?): Orders.DeliverRequest
			return { OwnerSlot = 1, TargetSlot = 1, Slot = slot, OrderNumber = number, Distance = distance or 3, Reach = 16, Bonus = 0 }
		end

		it("começa com os pedidos 1, 2 e 3 e mantém pedidos válidos já salvos", function()
			local state = Orders.Normalize(nil, config)
			expect(state.Slots[1]).to.equal(1)
			expect(state.Slots[3]).to.equal(3)
			expect(state.Next).to.equal(4)
			local kept = Orders.Normalize({ Next = 9, Slots = { 5, 7, 8 } }, config)
			expect(kept.Slots[2]).to.equal(7)
			expect(kept.Next).to.equal(9)
			local fixed = Orders.Normalize({ Next = 4, Slots = { 2, 2, 99 } }, config)
			expect(fixed.Slots[1]).to.equal(2)
			expect(fixed.Slots[2] ~= 2).to.equal(true)
		end)

		it("entrega consome os recursos, paga e troca o pedido da vaga", function()
			local data: { [string]: any } = { Resources = { Wood = 25 } }
			local result, reward = Orders.Deliver(data, request(1, 1), config)
			expect(result).to.equal("Ok")
			expect(reward).to.equal(32)
			expect(data.Resources.Wood).to.equal(5)
			expect(data.Resources.Coins).to.equal(32)
			expect(data.Orders.Slots[1]).to.equal(4)
			expect(data.Stats.OrdersDelivered).to.equal(1)
		end)

		it("recusa a mesma entrega repetida (pedido já trocado) sem pagar de novo", function()
			local data: { [string]: any } = { Resources = { Wood = 100 } }
			Orders.Deliver(data, request(1, 1), config)
			expect((Orders.Deliver(data, request(1, 1), config))).to.equal("Stale")
			expect(data.Resources.Coins).to.equal(32)
			expect(data.Resources.Wood).to.equal(80)
		end)

		it("recusa sem recursos, vaga inválida, fora do alcance e ilha alheia sem alterar nada", function()
			local data: { [string]: any } = { Resources = { Wood = 19 } }
			expect((Orders.Deliver(data, request(1, 1), config))).to.equal("Insufficient")
			expect((Orders.Deliver(data, request(4, 1), config))).to.equal("InvalidSlot")
			expect((Orders.Deliver(data, request(1.5, 1), config))).to.equal("InvalidSlot")
			expect((Orders.Deliver(data, request(1, 1, 50), config))).to.equal("OutOfReach")
			local other = request(1, 1)
			other.TargetSlot = 2
			expect((Orders.Deliver(data, other, config))).to.equal("NotOwner")
			expect(data.Resources.Wood).to.equal(19)
			expect(data.Orders).to.equal(nil)
		end)

		it("aplica o bônus do estágio com valor inteiro e a sequência é cíclica", function()
			expect(Orders.RewardFor(config.Templates[1], 0.25)).to.equal(40)
			expect(Orders.RewardFor(config.Templates[1], 0 / 0)).to.equal(32)
			expect(Orders.TemplateFor(config, 5).Id).to.equal("A")
		end)

		it("pedidos da configuração pagam mais que a venda direta, dentro do limite do saldo", function()
			for _, template in Economy.Orders.Templates do
				local direct = 0
				for resourceId, amount in template.Needs do
					direct += amount * Economy.Market.Prices[resourceId]
				end
				expect(template.Reward > direct).to.equal(true)
				expect(template.Reward < direct * 2).to.equal(true)
				expect(Orders.RewardFor(template, 0.25) <= 1000).to.equal(true)
			end
		end)
	end)

	describe("Stages", function()
		local stages: { Stages.Stage } = Economy.Stages :: any

		it("só avança com todos os requisitos e paga a recompensa uma vez", function()
			local data: { [string]: any } = { Resources = {}, Expansions = { E1 = true }, Stats = { PlanksProduced = 20, OrdersDelivered = 1 } }
			expect((Stages.Advance(data, stages))).to.equal("NotReady")
			expect(data.Stage).to.equal(nil)
			data.Stats.OrdersDelivered = 2
			local result, stage = Stages.Advance(data, stages)
			expect(result).to.equal("Ok")
			expect(stage).to.equal(2)
			expect(data.Resources.Coins).to.equal(100)
			expect((Stages.Advance(data, stages))).to.equal("MaxStage")
			expect(data.Resources.Coins).to.equal(100)
		end)

		it("estágio salvo inválido conta como 1 e o bônus vale a partir do estágio 2", function()
			expect(Stages.Current({ Stage = 0 / 0 }, stages)).to.equal(1)
			expect(Stages.OrderBonus({ Stage = 1 }, stages)).to.equal(0)
			expect(Stages.OrderBonus({ Stage = 2 }, stages)).to.equal(0.25)
		end)
	end)

	describe("Build (preço com vários recursos e limite por estágio)", function()
		local catalog: Build.Catalog = {
			Sites = { B1 = true, B2 = true, B3 = true },
			Structures = { Workshop = { Name = "", Cost = 0, Price = { Wood = 40, Coins = 50 }, MaxPerStage = { 1, 2 } } },
			CurrencyId = "Wood",
		}
		local function request(site: string): Build.Request
			return { OwnerSlot = 1, TargetSlot = 1, SiteId = site, StructureId = "Workshop", Distance = 2, Reach = 16 }
		end

		it("cobra o preço com vários recursos, tudo ou nada", function()
			local data: { [string]: any } = { Resources = { Wood = 40, Coins = 49 }, Buildings = {} }
			expect(Build.Apply(data :: any, request("B1"), catalog)).to.equal("Insufficient")
			expect(data.Resources.Wood).to.equal(40)
			data.Resources.Coins = 50
			expect(Build.Apply(data :: any, request("B1"), catalog)).to.equal("Ok")
			expect(data.Resources.Wood).to.equal(0)
			expect(data.Resources.Coins).to.equal(0)
		end)

		it("o limite cresce com o estágio da ilha", function()
			local data: { [string]: any } = { Resources = { Wood = 999, Coins = 999 }, Buildings = { B1 = "Workshop" }, Stage = 1 }
			expect(Build.Apply(data :: any, request("B2"), catalog)).to.equal("Limit")
			data.Stage = 2
			expect(Build.Apply(data :: any, request("B2"), catalog)).to.equal("Ok")
			expect(Build.Apply(data :: any, request("B3"), catalog)).to.equal("Limit")
		end)
	end)

	describe("Objectives (estruturas e estágio)", function()
		local context: Objectives.Context = { Producers = {} }
		it("conta estruturas por tipo e lê o estágio", function()
			local quarry: Objectives.Definition = { Id = "Q", Text = "", Kind = "Structure", Key = "Quarry", Target = 1, Reward = { Wood = 1 }, Guide = "Site" }
			local stage: Objectives.Definition = { Id = "S", Text = "", Kind = "Stage", Target = 2, Reward = { Wood = 1 }, Guide = "Stage" }
			expect(Objectives.Progress(quarry, { Buildings = { B1 = "Sawmill" } }, context)).to.equal(0)
			expect(Objectives.Progress(quarry, { Buildings = { B1 = "Quarry" } }, context)).to.equal(1)
			expect(Objectives.Progress(stage, {}, context)).to.equal(1)
			expect(Objectives.Progress(stage, { Stage = 2 }, context)).to.equal(2)
		end)
	end)

	describe("Proteção do perfil", function()
		it("Freeze impede escrita em qualquer nível e Clone devolve uma cópia editável", function()
			local data = DeepCopy.Freeze({ Resources = { Wood = 5 }, Buildings = {} })
			expect(pcall(function()
				data.Resources.Wood = 999
			end)).to.equal(false)
			expect(pcall(function()
				(data :: any).Hack = true
			end)).to.equal(false)
			expect(data.Resources.Wood).to.equal(5)
			local copy = DeepCopy.Clone(data)
			copy.Resources.Wood = 6
			expect(copy.Resources.Wood).to.equal(6)
			expect(data.Resources.Wood).to.equal(5)
		end)

		it("o perfil temporário só é usado no Studio e com o atributo exatamente verdadeiro", function()
			expect(ProfileSource.UseMock(true, true)).to.equal(true)
			expect(ProfileSource.UseMock(false, true)).to.equal(false)
			expect(ProfileSource.UseMock(true, "true")).to.equal(false)
			expect(ProfileSource.UseMock(true, nil)).to.equal(false)
		end)
	end)
end
