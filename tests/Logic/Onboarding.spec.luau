--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Onboarding = require(ReplicatedStorage.Shared.Logic.Onboarding)

	local function state(overrides: { [string]: any }?): Onboarding.State
		local value: Onboarding.State = {
			Wood = 0,
			Buildings = 0,
			FirstCost = 2,
			Producers = 0,
			ProducerCost = 15,
			Stored = 0,
			Harvested = false,
			StartedWithProducer = false,
		}
		for key, item in overrides or {} do
			(value :: any)[key] = item
		end
		return value
	end

	describe("Onboarding.Step", function()
		it("começa pedindo madeira quando o saldo não cobre a primeira estrutura", function()
			expect(Onboarding.Step(state({ Wood = 0 }))).to.equal("Collect")
			expect(Onboarding.Step(state({ Wood = 1 }))).to.equal("Collect")
		end)

		it("pede a primeira construção quando o saldo cobre o custo", function()
			expect(Onboarding.Step(state({ Wood = 2 }))).to.equal("Build")
		end)

		it("depois da primeira construção, pede madeira para a Serraria", function()
			expect(Onboarding.Step(state({ Wood = 6, Buildings = 1 }))).to.equal("SaveForProducer")
			expect(Onboarding.Step(state({ Wood = 15, Buildings = 1 }))).to.equal("BuildProducer")
		end)

		it("com a Serraria, espera a produção e depois pede a coleta", function()
			local base = { Buildings = 2, Producers = 1 }
			expect(Onboarding.Step(state(base))).to.equal("WaitProduction")
			base.Stored = 3 :: any
			expect(Onboarding.Step(state(base))).to.equal("Harvest")
		end)

		it("termina depois da primeira coleta da produção", function()
			expect(Onboarding.Step(state({ Buildings = 2, Producers = 1, Stored = 0, Harvested = true }))).to.equal("Done")
		end)

		it("quem começa a sessão com Serraria não vê a orientação", function()
			expect(Onboarding.Step(state({ Buildings = 2, Producers = 1, Stored = 9, StartedWithProducer = true }))).to.equal(
				"Done"
			)
		end)

		it("a Serraria como primeira construção pula direto para a produção", function()
			expect(Onboarding.Step(state({ Buildings = 1, Producers = 1 }))).to.equal("WaitProduction")
		end)

		it("trata saldo NaN como insuficiente", function()
			expect(Onboarding.Step(state({ Wood = 0 / 0 }))).to.equal("Collect")
			expect(Onboarding.Step(state({ Wood = 0 / 0, Buildings = 1 }))).to.equal("SaveForProducer")
		end)
	end)

	describe("Onboarding.Progress", function()
		it("vai de 0 a 1 e não passa de 1", function()
			expect(Onboarding.Progress(0, 2)).to.equal(0)
			expect(Onboarding.Progress(1, 2)).to.equal(0.5)
			expect(Onboarding.Progress(5, 2)).to.equal(1)
			expect(Onboarding.Progress(0 / 0, 15)).to.equal(0)
		end)
	end)
end
