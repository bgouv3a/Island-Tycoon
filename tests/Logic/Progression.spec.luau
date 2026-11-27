--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Logic = ReplicatedStorage.Shared.Logic
	local Upgrade = require(Logic.Upgrade)
	local Expansion = require(Logic.Expansion)
	local Objectives = require(Logic.Objectives)
	local Build = require(Logic.Build)
	local Economy = require(ReplicatedStorage.Shared.Config.Economy)
	local Gameplay = require(ReplicatedStorage.Shared.Config.Gameplay)

	local PRODUCERS: Upgrade.Producers = {
		Sawmill = {
			ResourceId = "Wood",
			Levels = {
				{ Amount = 1, IntervalSeconds = 5, Capacity = 30 },
				{ Amount = 1, IntervalSeconds = 3, Capacity = 45, Cost = { Coins = 25, Stone = 4 } },
			},
		},
	}

	local function upgradeRequest(distance: number?): Upgrade.Request
		return { OwnerSlot = 1, TargetSlot = 1, SiteId = "B5", Distance = distance or 3, Reach = 16 }
	end

	describe("Upgrade", function()
		it("sobe um nível e desconta o custo na mesma operação", function()
			local data: { [string]: any } = { Resources = { Coins = 30, Stone = 4 }, Buildings = { B5 = "Sawmill" }, Levels = {} }
			local result, level = Upgrade.Apply(data, upgradeRequest(), PRODUCERS)
			expect(result).to.equal("Ok")
			expect(level).to.equal(2)
			expect(data.Levels.B5).to.equal(2)
			expect(data.Resources.Coins).to.equal(5)
			expect(data.Resources.Stone).to.equal(0)
		end)

		it("não passa do nível máximo nem cobra de novo", function()
			local data: { [string]: any } = { Resources = { Coins = 99, Stone = 99 }, Buildings = { B5 = "Sawmill" }, Levels = { B5 = 2 } }
			local result = Upgrade.Apply(data, upgradeRequest(), PRODUCERS)
			expect(result).to.equal("MaxLevel")
			expect(data.Resources.Coins).to.equal(99)
		end)

		it("recusa sem saldo, fora do alcance e em ponto sem produtor, sem alterar nada", function()
			local data: { [string]: any } = { Resources = { Coins = 10, Stone = 4 }, Buildings = { B5 = "Sawmill", B1 = "Fence" } }
			expect((Upgrade.Apply(data, upgradeRequest(), PRODUCERS))).to.equal("Insufficient")
			expect((Upgrade.Apply(data, upgradeRequest(50), PRODUCERS))).to.equal("OutOfReach")
			local fence = upgradeRequest()
			fence.SiteId = "B1"
			expect((Upgrade.Apply(data, fence, PRODUCERS))).to.equal("NotUpgradable")
			expect(data.Levels).to.equal(nil)
			expect(data.Resources.Coins).to.equal(10)
		end)

		it("lê nível ausente ou inválido como nível 1 e aplica a regra do nível", function()
			expect(Upgrade.Level(nil, "B5", 5)).to.equal(1)
			expect(Upgrade.Level({ B5 = 0 / 0 }, "B5", 5)).to.equal(1)
			expect(Upgrade.Level({ B5 = 9 }, "B5", 5)).to.equal(5)
			local rules = Upgrade.SiteRules({ B5 = "Sawmill", B1 = "Fence" }, { B5 = 2 }, PRODUCERS)
			expect(rules.B1).to.equal(nil)
			expect(rules.B5.Capacity).to.equal(45)
			expect(rules.B5.IntervalSeconds).to.equal(3)
		end)

		it("a configuração tem custo crescente e produção crescente por nível", function()
			local levels = Economy.Upgrades.Sawmill
			for index = 2, #levels do
				local previous, current = levels[index - 1], levels[index]
				expect(current.Amount / current.IntervalSeconds > previous.Amount / previous.IntervalSeconds).to.equal(true)
				expect(current.Capacity > previous.Capacity).to.equal(true)
				if index > 2 then
					expect((current.Cost :: any).Coins > (previous.Cost :: any).Coins).to.equal(true)
				end
			end
		end)
	end)

	describe("Expansion", function()
		local AREAS: Expansion.Areas = { E1 = { Cost = { Coins = 120, Wood = 40 } } }
		local function request(area: string?, distance: number?): Expansion.Request
			return { OwnerSlot = 1, TargetSlot = 1, AreaId = area or "E1", Distance = distance or 5, Reach = 14 }
		end

		it("libera a área e desconta o custo; a segunda compra é recusada", function()
			local data: { [string]: any } = { Resources = { Coins = 200, Wood = 50 } }
			expect(Expansion.Apply(data, request(), AREAS)).to.equal("Ok")
			expect(data.Expansions.E1).to.equal(true)
			expect(data.Resources.Coins).to.equal(80)
			expect(Expansion.Apply(data, request(), AREAS)).to.equal("AlreadyOwned")
			expect(data.Resources.Coins).to.equal(80)
		end)

		it("recusa sem saldo, área desconhecida, fora do alcance e outra ilha", function()
			local data: { [string]: any } = { Resources = { Coins = 200, Wood = 10 } }
			expect(Expansion.Apply(data, request(), AREAS)).to.equal("Insufficient")
			expect(Expansion.Apply(data, request("E9"), AREAS)).to.equal("UnknownArea")
			expect(Expansion.Apply(data, request("E1", 30), AREAS)).to.equal("OutOfReach")
			local other = request()
			other.TargetSlot = 3
			expect(Expansion.Apply(data, other, AREAS)).to.equal("NotOwner")
			expect(data.Expansions).to.equal(nil)
			expect(data.Resources.Coins).to.equal(200)
		end)
	end)

	describe("Build (expansão e limite por ilha)", function()
		local catalog: Build.Catalog = {
			Sites = { B1 = true, B2 = true, B3 = true, X1 = true },
			Structures = { Sawmill = { Name = "Serraria", Cost = 15, MaxPerIsland = 2 } },
			CurrencyId = "Wood",
			SiteAreas = { X1 = "E1" },
		}
		local function request(site: string): Build.Request
			return { OwnerSlot = 1, TargetSlot = 1, SiteId = site, StructureId = "Sawmill", Distance = 2, Reach = 16 }
		end

		it("recusa construir em ponto de expansão ainda não liberada", function()
			local data: { [string]: any } = { Resources = { Wood = 50 }, Buildings = {} }
			expect(Build.Apply(data :: any, request("X1"), catalog)).to.equal("Locked")
			expect(data.Resources.Wood).to.equal(50)
			data.Expansions = { E1 = true }
			expect(Build.Apply(data :: any, request("X1"), catalog)).to.equal("Ok")
		end)

		it("respeita o limite de estruturas por ilha", function()
			local data: { [string]: any } = { Resources = { Wood = 50 }, Buildings = { B1 = "Sawmill", B2 = "Sawmill" } }
			expect(Build.Apply(data :: any, request("B3"), catalog)).to.equal("Limit")
			expect(data.Resources.Wood).to.equal(50)
		end)

		it("os pontos de expansão da configuração apontam para expansões existentes", function()
			for siteId, area in Gameplay.Build.SiteAreas do
				expect(Gameplay.Build.Sites[siteId] ~= nil).to.equal(true)
				expect(Economy.Expansions[area] ~= nil).to.equal(true)
			end
		end)
	end)

	describe("Objectives", function()
		local context: Objectives.Context = { Producers = PRODUCERS }
		local definitions: { Objectives.Definition } = {
			{ Id = "A", Text = "", Kind = "Stat", Key = "WoodCollected", Target = 6, Reward = { Wood = 4 }, Guide = "Tree" },
			{ Id = "B", Text = "", Kind = "Buildings", Target = 1, Reward = { Wood = 6 }, Guide = "Site" },
			{ Id = "C", Text = "", Kind = "Producers", Target = 1, Reward = { Coins = 10 }, Guide = "Site" },
			{ Id = "D", Text = "", Kind = "Level", Target = 2, Reward = { Stone = 1 }, Guide = "Producer" },
			{ Id = "E", Text = "", Kind = "Expansion", Key = "E1", Target = 1, Reward = { Coins = 5 }, Guide = "Expansion" },
		}

		it("calcula o progresso do objetivo atual a partir do perfil", function()
			local data: { [string]: any } = { Stats = { WoodCollected = 4 }, Resources = {} }
			local current = Objectives.Current(data, definitions)
			expect((current :: any).Id).to.equal("A")
			expect(Objectives.Progress(definitions[1], data, context)).to.equal(4)
			data.Stats.WoodCollected = 50
			expect(Objectives.Progress(definitions[1], data, context)).to.equal(6)
		end)

		it("conclui em ordem e entrega cada recompensa uma única vez", function()
			local data: { [string]: any } = { Stats = { WoodCollected = 6 }, Resources = {}, Buildings = {} }
			local done = Objectives.Advance(data, definitions, context, true)
			expect(#done).to.equal(1)
			expect(data.Objective).to.equal(1)
			expect(data.Resources.Wood).to.equal(4)
			expect(#Objectives.Advance(data, definitions, context, true)).to.equal(0)
			expect(data.Resources.Wood).to.equal(4)
		end)

		it("sem grant, marca o que já foi feito sem recompensa (perfil antigo)", function()
			local data: { [string]: any } = {
				Stats = { WoodCollected = 6 },
				Resources = { Wood = 1 },
				Buildings = { B1 = "Fence", B5 = "Sawmill" },
				Levels = {},
			}
			local done = Objectives.Advance(data, definitions, context, false)
			expect(#done).to.equal(3)
			expect(data.Objective).to.equal(3)
			expect(data.Resources.Wood).to.equal(1)
			expect(data.Resources.Coins).to.equal(nil)
		end)

		it("reconhece nível de melhoria e expansão", function()
			local data: { [string]: any } = { Buildings = { B5 = "Sawmill" }, Levels = { B5 = 2 }, Expansions = { E1 = true } }
			expect(Objectives.Progress(definitions[4], data, context)).to.equal(2)
			expect(Objectives.Progress(definitions[5], data, context)).to.equal(1)
		end)

		it("valor salvo inválido conta como nenhum objetivo concluído; todos concluídos devolve nil", function()
			expect(Objectives.Completed({ Objective = 0 / 0 }, definitions)).to.equal(0)
			expect(Objectives.Completed({ Objective = 99 }, definitions)).to.equal(#definitions)
			expect((Objectives.Current({ Objective = #definitions }, definitions))).to.equal(nil)
		end)

		it("os objetivos da configuração usam alvos e recursos válidos", function()
			for _, definition in Economy.Objectives do
				expect(definition.Target >= 1).to.equal(true)
				for resourceId in definition.Reward do
					expect(Economy.Resources[resourceId] ~= nil).to.equal(true)
				end
			end
		end)
	end)
end
