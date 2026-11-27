--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ResourceLedger = require(ReplicatedStorage.Shared.Logic.ResourceLedger)

	describe("ResourceLedger", function()
		it("soma a quantidade ao saldo do recurso", function()
			local ledger = { Wood = 2 }
			expect(ResourceLedger.Add(ledger, "Wood", 3)).to.equal(true)
			expect(ledger.Wood).to.equal(5)
		end)

		it("começa do zero para um recurso novo", function()
			local ledger: { [string]: number } = {}
			expect(ResourceLedger.Add(ledger, "Wood", 1)).to.equal(true)
			expect(ResourceLedger.Get(ledger, "Wood")).to.equal(1)
		end)

		it("rejeita quantidade zero, negativa, decimal, NaN e infinita sem alterar o saldo", function()
			local ledger = { Wood = 4 }
			expect(ResourceLedger.Add(ledger, "Wood", 0)).to.equal(false)
			expect(ResourceLedger.Add(ledger, "Wood", -1)).to.equal(false)
			expect(ResourceLedger.Add(ledger, "Wood", 1.5)).to.equal(false)
			expect(ResourceLedger.Add(ledger, "Wood", 0 / 0)).to.equal(false)
			expect(ResourceLedger.Add(ledger, "Wood", math.huge)).to.equal(false)
			expect(ledger.Wood).to.equal(4)
		end)

		it("rejeita identificador vazio, longo ou que não é texto", function()
			local ledger: { [string]: number } = {}
			expect(ResourceLedger.Add(ledger, "", 1)).to.equal(false)
			expect(ResourceLedger.Add(ledger, string.rep("a", 33), 1)).to.equal(false)
			expect(ResourceLedger.Add(ledger, 5 :: any, 1)).to.equal(false)
			expect(next(ledger)).to.equal(nil)
		end)

		it("Get devolve zero para recurso ausente ou com valor corrompido", function()
			expect(ResourceLedger.Get({}, "Wood")).to.equal(0)
			expect(ResourceLedger.Get({ Wood = "x" } :: any, "Wood")).to.equal(0)
		end)

		it("Spend subtrai a quantidade exata do saldo", function()
			local ledger = { Wood = 5 }
			expect(ResourceLedger.Spend(ledger, "Wood", 2)).to.equal(true)
			expect(ledger.Wood).to.equal(3)
		end)

		it("Spend aceita gastar todo o saldo, mas não deixa valor negativo", function()
			local ledger = { Wood = 2 }
			expect(ResourceLedger.Spend(ledger, "Wood", 2)).to.equal(true)
			expect(ledger.Wood).to.equal(0)
			expect(ResourceLedger.Spend(ledger, "Wood", 1)).to.equal(false)
			expect(ledger.Wood).to.equal(0)
		end)

		it("Spend recusa saldo insuficiente sem alterar nada", function()
			local ledger = { Wood = 1 }
			expect(ResourceLedger.Spend(ledger, "Wood", 2)).to.equal(false)
			expect(ledger.Wood).to.equal(1)
		end)

		it("Spend recusa recurso ausente, quantidade inválida e valor corrompido", function()
			local ledger: { [string]: any } = { Wood = 9, Stone = "x" }
			expect(ResourceLedger.Spend(ledger, "Stone", 1)).to.equal(false)
			expect(ResourceLedger.Spend(ledger, "Gold", 1)).to.equal(false)
			expect(ResourceLedger.Spend(ledger, "Wood", 0)).to.equal(false)
			expect(ResourceLedger.Spend(ledger, "Wood", -3)).to.equal(false)
			expect(ResourceLedger.Spend(ledger, "Wood", 0.5)).to.equal(false)
			expect(ResourceLedger.Spend(ledger, "Wood", 0 / 0)).to.equal(false)
			expect(ledger.Wood).to.equal(9)
		end)
	end)
end
