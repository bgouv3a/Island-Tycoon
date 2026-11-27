--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Collect = require(ReplicatedStorage.Shared.Logic.Collect)

	local function base(): Collect.Check
		return {
			OwnerSlot = 1,
			NodeSlot = 1,
			ReadyAt = 0,
			Now = 100,
			Distance = 5,
			Reach = 14,
		}
	end

	describe("Collect.Evaluate", function()
		it("permite coletar a própria árvore pronta e dentro do alcance", function()
			expect(Collect.Evaluate(base())).to.equal("Ok")
		end)

		it("nega jogador sem ilha", function()
			local c = base()
			c.OwnerSlot = nil
			expect(Collect.Evaluate(c)).to.equal("NoIsland")
		end)

		it("nega árvore de outra ilha", function()
			local c = base()
			c.NodeSlot = 2
			expect(Collect.Evaluate(c)).to.equal("NotOwner")
		end)

		it("nega árvore em cooldown e libera quando o tempo passa", function()
			local c = base()
			c.ReadyAt = 200
			expect(Collect.Evaluate(c)).to.equal("Cooldown")
			c.Now = 200
			expect(Collect.Evaluate(c)).to.equal("Ok")
		end)

		it("nega jogador fora do alcance", function()
			local c = base()
			c.Distance = 15
			expect(Collect.Evaluate(c)).to.equal("OutOfReach")
		end)

		it("nega distância NaN", function()
			local c = base()
			c.Distance = 0 / 0
			expect(Collect.Evaluate(c)).to.equal("OutOfReach")
		end)
	end)
end
