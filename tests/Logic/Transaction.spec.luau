--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Transaction = require(ReplicatedStorage.Shared.Logic.Transaction)

	describe("Transaction.Apply", function()
		it("aplica a mutação quando termina sem erro", function()
			local data = { Coins = 10, Inventory = { Wood = 1 } }
			local ok, result = Transaction.Apply(data, function(d)
				d.Coins += 5
				d.Inventory.Wood += 2
			end)
			expect(ok).to.equal(true)
			expect(result.Coins).to.equal(15)
			expect(result.Inventory.Wood).to.equal(3)
		end)

		it("não altera os dados originais em caso de sucesso", function()
			local data = { Coins = 10, Inventory = { Wood = 1 } }
			Transaction.Apply(data, function(d)
				d.Coins = 0
				d.Inventory.Wood = 0
			end)
			expect(data.Coins).to.equal(10)
			expect(data.Inventory.Wood).to.equal(1)
		end)

		it("preserva os dados originais quando a mutação falha no meio", function()
			local data = { Coins = 10, Inventory = { Wood = 1, Stone = 4 } }
			local ok, err = Transaction.Apply(data, function(d)
				d.Coins = 0
				d.Inventory.Wood = 999
				error("falha no meio da mutação")
			end)
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "falha no meio") ~= nil).to.equal(true)
			expect(data.Coins).to.equal(10)
			expect(data.Inventory.Wood).to.equal(1)
			expect(data.Inventory.Stone).to.equal(4)
		end)

		it("não devolve nenhuma alteração parcial quando falha", function()
			local data = { List = { 1, 2 } }
			local ok = Transaction.Apply(data, function(d)
				table.insert(d.List, 3)
				error("erro depois de inserir")
			end)
			expect(ok).to.equal(false)
			expect(#data.List).to.equal(2)
		end)

		it("o resultado não compartilha tabelas com o original", function()
			local data = { Inner = { Value = 1 } }
			local _, result = Transaction.Apply(data, function(d)
				d.Inner.Value = 2
			end)
			expect(result.Inner ~= data.Inner).to.equal(true)
		end)

		it("referências guardadas pela mutação não alteram o resultado depois", function()
			local data = { List = { 1 } }
			local kept: any = nil
			local ok, result = Transaction.Apply(data, function(d)
				kept = d.List
				d.List = { 1, 2 }
			end)
			expect(ok).to.equal(true)
			kept[1] = 500
			table.insert(kept, 600)
			expect(result.List[1]).to.equal(1)
			expect(#result.List).to.equal(2)
		end)

		it("trata listas e estruturas aninhadas profundas", function()
			local data = { A = { B = { C = { 1, 2, 3 } } } }
			local ok, result = Transaction.Apply(data, function(d)
				table.remove(d.A.B.C, 1)
			end)
			expect(ok).to.equal(true)
			expect(#result.A.B.C).to.equal(2)
			expect(#data.A.B.C).to.equal(3)
		end)
	end)
end
