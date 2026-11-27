--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Production = require(ReplicatedStorage.Shared.Logic.Production)

	local rule: Production.Rule = { ResourceId = "Wood", Amount = 1, IntervalSeconds = 5, Capacity = 30 }
	local rules: Production.Rules = { Sawmill = rule }

	local function request(overrides: { [string]: any }?): Production.HarvestRequest
		local value: Production.HarvestRequest = {
			OwnerSlot = 1,
			TargetSlot = 1,
			SiteId = "B5",
			Distance = 4,
			Reach = 16,
		}
		for key, item in overrides or {} do
			(value :: any)[key] = item
		end
		return value
	end

	local function state(wood: number, stored: number): any
		return { Resources = { Wood = wood }, Buildings = { B1 = "Fence", B5 = "Sawmill" }, Storage = { B5 = stored } }
	end

	describe("Production.Step", function()
		it("produz 1 unidade a cada 5 segundos", function()
			local stored, progress, produced = Production.Step(0, 0, 4.9, rule)
			expect(stored).to.equal(0)
			expect(produced).to.equal(0)
			stored, progress, produced = Production.Step(stored, progress, 0.2, rule)
			expect(stored).to.equal(1)
			expect(produced).to.equal(1)
			expect(math.abs(progress - 0.1) < 1e-6).to.equal(true)
		end)

		it("acumula o progresso entre passos curtos", function()
			local stored, progress = 0, 0
			for _ = 1, 10 do
				stored, progress = Production.Step(stored, progress, 1, rule)
			end
			expect(stored).to.equal(2)
		end)

		it("nunca passa da capacidade e pausa quando cheio", function()
			local stored, progress, produced = Production.Step(29, 0, 60, rule)
			expect(stored).to.equal(30)
			expect(produced).to.equal(1)
			expect(progress).to.equal(0)
			stored, progress, produced = Production.Step(stored, progress, 60, rule)
			expect(stored).to.equal(30)
			expect(produced).to.equal(0)
			expect(progress).to.equal(0)
		end)

		it("ignora intervalos inválidos (zero, negativo ou NaN)", function()
			for _, dt in { 0, -5, 0 / 0 } do
				local stored, _, produced = Production.Step(3, 1, dt, rule)
				expect(stored).to.equal(3)
				expect(produced).to.equal(0)
			end
		end)
	end)

	describe("Production.Sanitize", function()
		it("mantém só pontos com construção produtiva", function()
			local result = Production.Sanitize({ B1 = 9, B5 = 7, X9 = 3 }, { B1 = "Fence", B5 = "Sawmill" }, rules)
			expect(result.B5).to.equal(7)
			expect(result.B1).to.equal(nil)
			expect(result.X9).to.equal(nil)
		end)

		it("corrige valores inválidos e limita à capacidade", function()
			local buildings = { B5 = "Sawmill", B6 = "Sawmill", B7 = "Sawmill", B8 = "Sawmill" }
			local result = Production.Sanitize({ B5 = 999, B6 = -2, B7 = 2.5, B8 = "x" }, buildings, rules)
			expect(result.B5).to.equal(30)
			expect(result.B6).to.equal(0)
			expect(result.B7).to.equal(0)
			expect(result.B8).to.equal(0)
		end)

		it("cria estoque zero para produtores sem estoque salvo", function()
			local result = Production.Sanitize(nil, { B5 = "Sawmill" }, rules)
			expect(result.B5).to.equal(0)
		end)
	end)

	describe("Production.Harvest", function()
		it("move todo o estoque para o saldo e zera o estoque", function()
			local data = state(3, 12)
			local result, amount = Production.Harvest(data, request(), rules)
			expect(result).to.equal("Ok")
			expect(amount).to.equal(12)
			expect(data.Resources.Wood).to.equal(15)
			expect(data.Storage.B5).to.equal(0)
		end)

		it("não entrega o mesmo estoque duas vezes", function()
			local data = state(0, 8)
			Production.Harvest(data, request(), rules)
			local result, amount = Production.Harvest(data, request(), rules)
			expect(result).to.equal("Empty")
			expect(amount).to.equal(0)
			expect(data.Resources.Wood).to.equal(8)
		end)

		it("recusa ilha de outro jogador sem alterar nada", function()
			local data = state(0, 8)
			local result = Production.Harvest(data, request({ TargetSlot = 2 }), rules)
			expect(result).to.equal("NotOwner")
			expect(data.Storage.B5).to.equal(8)
			expect(data.Resources.Wood).to.equal(0)
		end)

		it("recusa jogador sem ilha", function()
			local data = state(0, 8)
			local value = request()
			value.OwnerSlot = nil
			expect((Production.Harvest(data, value, rules))).to.equal("NoIsland")
		end)

		it("recusa pontos sem construção produtiva", function()
			local data = state(0, 8)
			expect((Production.Harvest(data, request({ SiteId = "B1" }), rules))).to.equal("NotProducer")
			expect((Production.Harvest(data, request({ SiteId = "B9" }), rules))).to.equal("NotProducer")
		end)

		it("recusa fora do alcance, inclusive distância NaN", function()
			local data = state(0, 8)
			expect((Production.Harvest(data, request({ Distance = 40 }), rules))).to.equal("OutOfReach")
			expect((Production.Harvest(data, request({ Distance = 0 / 0 }), rules))).to.equal("OutOfReach")
			expect(data.Storage.B5).to.equal(8)
		end)

		it("limita um estoque salvo acima da capacidade", function()
			local data = state(0, 500)
			local result, amount = Production.Harvest(data, request(), rules)
			expect(result).to.equal("Ok")
			expect(amount).to.equal(30)
		end)

		it("recusa dados sem estoque", function()
			local data = { Resources = { Wood = 0 }, Buildings = { B5 = "Sawmill" } }
			expect((Production.Harvest(data :: any, request(), rules))).to.equal("Invalid")
		end)
	end)
end
