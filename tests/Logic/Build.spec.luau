--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Build = require(ReplicatedStorage.Shared.Logic.Build)

	local catalog: Build.Catalog = {
		Sites = { B1 = true, B2 = true },
		Structures = {
			Fence = { Name = "Cerca", Cost = 2 },
			Cabin = { Name = "Cabana", Cost = 5 },
		},
		CurrencyId = "Wood",
	}

	-- Pedido válido no ponto B1 da ilha 1, com o jogador perto do ponto.
	local function request(overrides: { [string]: any }?): Build.Request
		local value: Build.Request = {
			OwnerSlot = 1,
			TargetSlot = 1,
			SiteId = "B1",
			StructureId = "Fence",
			Distance = 3,
			Reach = 16,
		}
		for key, item in overrides or {} do
			(value :: any)[key] = item
		end
		return value
	end

	local function state(wood: number): { Resources: { [string]: number }, Buildings: { [string]: string } }
		return { Resources = { Wood = wood }, Buildings = {} }
	end

	describe("Build.Apply", function()
		it("constrói com recursos suficientes e registra a estrutura no ponto", function()
			local data = state(5)
			expect(Build.Apply(data, request(), catalog)).to.equal("Ok")
			expect(data.Buildings.B1).to.equal("Fence")
		end)

		it("desconta exatamente o custo da estrutura", function()
			local data = state(7)
			Build.Apply(data, request({ StructureId = "Cabin" }), catalog)
			expect(data.Resources.Wood).to.equal(2)
		end)

		it("recusa por madeira insuficiente sem alterar nada", function()
			local data = state(1)
			expect(Build.Apply(data, request(), catalog)).to.equal("Insufficient")
			expect(data.Resources.Wood).to.equal(1)
			expect(data.Buildings.B1).to.equal(nil)
		end)

		it("recusa ponto ocupado e não cobra de novo", function()
			local data = state(10)
			expect(Build.Apply(data, request(), catalog)).to.equal("Ok")
			expect(Build.Apply(data, request({ StructureId = "Cabin" }), catalog)).to.equal("Occupied")
			expect(data.Buildings.B1).to.equal("Fence")
			expect(data.Resources.Wood).to.equal(8)
		end)

		it("recusa compras duplicadas feitas em sequência: só a primeira vale", function()
			local data = state(20)
			local results = {}
			for index = 1, 5 do
				results[index] = Build.Apply(data, request(), catalog)
			end
			expect(results[1]).to.equal("Ok")
			for index = 2, 5 do
				expect(results[index]).to.equal("Occupied")
			end
			expect(data.Resources.Wood).to.equal(18)
		end)

		it("recusa construção em ilha alheia (ponto de outra ilha)", function()
			local data = state(10)
			expect(Build.Apply(data, request({ OwnerSlot = 1, TargetSlot = 2 }), catalog)).to.equal("NotOwner")
			expect(data.Buildings.B1).to.equal(nil)
			expect(data.Resources.Wood).to.equal(10)
		end)

		it("recusa jogador sem ilha", function()
			local data = state(10)
			local noIsland = request()
			noIsland.OwnerSlot = nil
			expect(Build.Apply(data, noIsland, catalog)).to.equal("NoIsland")
			expect(data.Resources.Wood).to.equal(10)
		end)

		it("recusa ponto e estrutura que não existem no catálogo", function()
			local data = state(10)
			expect(Build.Apply(data, request({ SiteId = "X9" }), catalog)).to.equal("UnknownSite")
			expect(Build.Apply(data, request({ StructureId = "Castelo" }), catalog)).to.equal("UnknownStructure")
			expect(data.Resources.Wood).to.equal(10)
		end)

		it("recusa distância acima do alcance, inclusive NaN", function()
			local data = state(10)
			expect(Build.Apply(data, request({ Distance = 40 }), catalog)).to.equal("OutOfReach")
			expect(Build.Apply(data, request({ Distance = 0 / 0 }), catalog)).to.equal("OutOfReach")
			expect(data.Buildings.B1).to.equal(nil)
		end)

		it("recusa quando o campo de construções está corrompido", function()
			local data = { Resources = { Wood = 10 }, Buildings = "x" } :: any
			expect(Build.Apply(data, request(), catalog)).to.equal("Invalid")
			expect(data.Resources.Wood).to.equal(10)
		end)

		it("constrói em pontos diferentes da mesma ilha", function()
			local data = state(10)
			expect(Build.Apply(data, request({ SiteId = "B1" }), catalog)).to.equal("Ok")
			expect(Build.Apply(data, request({ SiteId = "B2" }), catalog)).to.equal("Ok")
			expect(data.Buildings.B1).to.equal("Fence")
			expect(data.Buildings.B2).to.equal("Fence")
			expect(data.Resources.Wood).to.equal(6)
		end)
	end)

	describe("Build.Restore", function()
		it("devolve as construções salvas sem alterá-las (persistência)", function()
			local saved = { B1 = "Fence", B2 = "Cabin" }
			local restored = Build.Restore(saved, catalog)
			expect(restored.B1).to.equal("Fence")
			expect(restored.B2).to.equal("Cabin")
		end)

		it("cada ponto aparece no máximo uma vez no resultado", function()
			local restored = Build.Restore({ B1 = "Fence" }, catalog)
			local count = 0
			for _ in restored do
				count += 1
			end
			expect(count).to.equal(1)
		end)

		it("descarta pontos e estruturas desconhecidos e valores que não são texto", function()
			local saved = { B1 = "Fence", X9 = "Fence", B2 = "Castelo", B3 = 4 }
			local restored = Build.Restore(saved, catalog)
			expect(restored.B1).to.equal("Fence")
			expect(restored.X9).to.equal(nil)
			expect(restored.B2).to.equal(nil)
			expect(restored.B3).to.equal(nil)
		end)

		it("devolve vazio para dados ausentes ou inválidos", function()
			expect(next(Build.Restore(nil, catalog))).to.equal(nil)
			expect(next(Build.Restore("x", catalog))).to.equal(nil)
		end)
	end)
end
