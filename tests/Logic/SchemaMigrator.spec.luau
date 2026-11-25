--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local SchemaMigrator = require(ReplicatedStorage.Shared.Logic.SchemaMigrator)

	describe("SchemaMigrator.GetStatus", function()
		it("retorna Current para a versão atual", function()
			expect(SchemaMigrator.GetStatus(2, 2)).to.equal("Current")
		end)

		it("retorna NeedsMigration para versão antiga", function()
			expect(SchemaMigrator.GetStatus(1, 3)).to.equal("NeedsMigration")
		end)

		it("retorna TooNew para versão mais nova (nunca alterar)", function()
			expect(SchemaMigrator.GetStatus(3, 2)).to.equal("TooNew")
		end)

		it("retorna Invalid para valores ausentes ou malformados", function()
			expect(SchemaMigrator.GetStatus(nil, 1)).to.equal("Invalid")
			expect(SchemaMigrator.GetStatus("2", 1)).to.equal("Invalid")
			expect(SchemaMigrator.GetStatus(0, 1)).to.equal("Invalid")
			expect(SchemaMigrator.GetStatus(1.5, 2)).to.equal("Invalid")
			expect(SchemaMigrator.GetStatus(0 / 0, 1)).to.equal("Invalid")
			expect(SchemaMigrator.GetStatus(math.huge, 1)).to.equal("Invalid")
		end)
	end)

	describe("SchemaMigrator.Apply", function()
		it("aplica as migrações em sequência e atualiza SchemaVersion", function()
			local data = { SchemaVersion = 1, Name = "a" }
			SchemaMigrator.Apply(data, 1, 3, {
				[2] = function(d)
					d.Name = d.Name .. "b"
				end,
				[3] = function(d)
					d.Name = d.Name .. "c"
				end,
			})
			expect(data.Name).to.equal("abc")
			expect(data.SchemaVersion).to.equal(3)
		end)

		it("falha se uma migração estiver faltando", function()
			local ok = pcall(SchemaMigrator.Apply, { SchemaVersion = 1 }, 1, 2, {})
			expect(ok).to.equal(false)
		end)
	end)
end
