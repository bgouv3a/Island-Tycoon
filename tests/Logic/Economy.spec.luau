--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Logic = ReplicatedStorage.Shared.Logic
	local Cost = require(Logic.Cost)
	local Market = require(Logic.Market)
	local Stats = require(Logic.Stats)
	local Economy = require(ReplicatedStorage.Shared.Config.Economy)

	describe("Cost", function()
		it("desconta todos os recursos quando o saldo cobre o custo", function()
			local ledger = { Coins = 30, Stone = 5 }
			expect(Cost.Spend(ledger, { Coins = 25, Stone = 4 })).to.equal(true)
			expect(ledger.Coins).to.equal(5)
			expect(ledger.Stone).to.equal(1)
		end)

		it("não desconta nada se faltar um dos recursos", function()
			local ledger = { Coins = 30, Stone = 3 }
			expect(Cost.Spend(ledger, { Coins = 25, Stone = 4 })).to.equal(false)
			expect(ledger.Coins).to.equal(30)
			expect(ledger.Stone).to.equal(3)
		end)

		it("recusa custos inválidos (vazio, negativo, fracionário, NaN)", function()
			expect(Cost.IsValid({})).to.equal(false)
			expect(Cost.IsValid({ Coins = -1 })).to.equal(false)
			expect(Cost.IsValid({ Coins = 1.5 })).to.equal(false)
			expect(Cost.IsValid({ Coins = 0 / 0 })).to.equal(false)
			expect(Cost.Spend({ Coins = 10 }, { Coins = -5 })).to.equal(false)
		end)

		it("entrega uma recompensa com vários recursos", function()
			local ledger: { [string]: number } = { Wood = 1 }
			expect(Cost.Grant(ledger, { Wood = 4, Coins = 10 })).to.equal(true)
			expect(ledger.Wood).to.equal(5)
			expect(ledger.Coins).to.equal(10)
		end)
	end)

	describe("Market", function()
		local config: Market.Config = { CurrencyId = "Coins", MaxLot = 300, Prices = { Wood = 1, Stone = 3 } }
		local function request(resourceId: string, amount: number, distance: number?): Market.SellRequest
			return { OwnerSlot = 1, TargetSlot = 1, ResourceId = resourceId, Amount = amount, Distance = distance or 4, Reach = 16 }
		end

		it("troca o recurso por moedas na mesma operação", function()
			local data: { [string]: any } = { Resources = { Stone = 10, Coins = 2 } }
			local result, earned = Market.Sell(data, request("Stone", 4), config)
			expect(result).to.equal("Ok")
			expect(earned).to.equal(12)
			expect(data.Resources.Stone).to.equal(6)
			expect(data.Resources.Coins).to.equal(14)
			expect(Stats.Get(data, "CoinsEarned")).to.equal(12)
		end)

		it("recusa vender mais do que o saldo, sem alterar nada", function()
			local data: { [string]: any } = { Resources = { Wood = 3 } }
			local result = Market.Sell(data, request("Wood", 4), config)
			expect(result).to.equal("Insufficient")
			expect(data.Resources.Wood).to.equal(3)
			expect(data.Resources.Coins).to.equal(nil)
		end)

		it("recusa quantidades inválidas", function()
			local data: { [string]: any } = { Resources = { Wood = 500 } }
			for _, amount in { 0, -1, 1.5, 0 / 0, 301, math.huge } do
				expect((Market.Sell(data, request("Wood", amount), config))).to.equal("InvalidAmount")
			end
			expect(data.Resources.Wood).to.equal(500)
		end)

		it("recusa vender moedas ou recursos sem preço", function()
			local data: { [string]: any } = { Resources = { Coins = 50, Gold = 5 } }
			expect((Market.Sell(data, request("Coins", 5), config))).to.equal("NotSellable")
			expect((Market.Sell(data, request("Gold", 1), config))).to.equal("NotSellable")
		end)

		it("recusa fora do alcance e na ilha de outro jogador", function()
			local data: { [string]: any } = { Resources = { Wood = 10 } }
			expect((Market.Sell(data, request("Wood", 1, 40), config))).to.equal("OutOfReach")
			expect((Market.Sell(data, request("Wood", 1, 0 / 0), config))).to.equal("OutOfReach")
			local other = request("Wood", 1)
			other.TargetSlot = 2
			expect((Market.Sell(data, other, config))).to.equal("NotOwner")
			expect(data.Resources.Wood).to.equal(10)
		end)

		it("o maior lote ao maior preço cabe no limite do saldo", function()
			for _, price in Economy.Market.Prices do
				expect(Economy.Market.MaxLot * price <= 1000).to.equal(true)
			end
		end)
	end)
end
