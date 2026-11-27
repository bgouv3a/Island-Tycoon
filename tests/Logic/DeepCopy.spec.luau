--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local DeepCopy = require(ReplicatedStorage.Shared.Logic.DeepCopy)

	describe("DeepCopy", function()
		it("devolve valores que não são tabelas sem alteração", function()
			expect(DeepCopy.Clone(5)).to.equal(5)
			expect(DeepCopy.Clone("texto")).to.equal("texto")
			expect(DeepCopy.Clone(true)).to.equal(true)
			expect(DeepCopy.Clone(nil)).to.equal(nil)
		end)

		it("copia o nível superior sem compartilhar a tabela", function()
			local original = { Coins = 10 }
			local copy = DeepCopy.Clone(original)
			expect(copy ~= original).to.equal(true)
			expect(copy.Coins).to.equal(10)
			copy.Coins = 99
			expect(original.Coins).to.equal(10)
		end)

		it("copia estruturas aninhadas e listas recursivamente", function()
			local original = { Inventory = { Slots = { 1, 2, { Id = "wood" } } } }
			local copy = DeepCopy.Clone(original)
			copy.Inventory.Slots[3].Id = "stone"
			table.insert(copy.Inventory.Slots, 4)
			copy.Inventory.Slots[1] = 50
			expect(original.Inventory.Slots[3].Id).to.equal("wood")
			expect(#original.Inventory.Slots).to.equal(3)
			expect(original.Inventory.Slots[1]).to.equal(1)
		end)

		it("não compartilha tabelas aninhadas com o original", function()
			local original = { Inner = { Value = 1 } }
			local copy = DeepCopy.Clone(original)
			expect(copy.Inner ~= original.Inner).to.equal(true)
		end)

		it("preserva referências circulares sem entrar em laço", function()
			local original: { [string]: any } = { Name = "ciclo" }
			original.Self = original
			local copy = DeepCopy.Clone(original)
			expect(copy.Self).to.equal(copy)
			expect(copy ~= original).to.equal(true)
		end)
	end)
end
