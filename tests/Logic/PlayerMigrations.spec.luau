--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PlayerMigrations = require(ReplicatedStorage.Shared.Logic.PlayerMigrations)
	local SchemaMigrator = require(ReplicatedStorage.Shared.Logic.SchemaMigrator)

	describe("PlayerMigrations (v1 → v2)", function()
		it("adiciona o saldo de recursos a dados da versão 1", function()
			local data: { [string]: any } = { SchemaVersion = 1, Coins = 7 }
			SchemaMigrator.Apply(data, 1, 2, PlayerMigrations)
			expect(type(data.Resources)).to.equal("table")
			expect(data.SchemaVersion).to.equal(2)
		end)

		it("preserva dados existentes ao migrar", function()
			local data: { [string]: any } = { SchemaVersion = 1, Coins = 7 }
			SchemaMigrator.Apply(data, 1, 2, PlayerMigrations)
			expect(data.Coins).to.equal(7)
		end)

		it("não sobrescreve um saldo que já existe", function()
			local data: { [string]: any } = { SchemaVersion = 1, Resources = { Wood = 9 } }
			SchemaMigrator.Apply(data, 1, 2, PlayerMigrations)
			expect(data.Resources.Wood).to.equal(9)
		end)
	end)

	describe("PlayerMigrations (v2 → v3: construções)", function()
		it("adiciona o campo de construções a dados da versão 2", function()
			local data: { [string]: any } = { SchemaVersion = 2, Resources = { Wood = 3 } }
			SchemaMigrator.Apply(data, 2, 3, PlayerMigrations)
			expect(type(data.Buildings)).to.equal("table")
			expect(data.SchemaVersion).to.equal(3)
		end)

		it("preserva o saldo de madeira ao migrar da versão 2", function()
			local data: { [string]: any } = { SchemaVersion = 2, Resources = { Wood = 3 } }
			SchemaMigrator.Apply(data, 2, 3, PlayerMigrations)
			expect(data.Resources.Wood).to.equal(3)
			expect(next(data.Buildings)).to.equal(nil)
		end)

		it("migra da versão 1 até a 3 em sequência, sem perder dados", function()
			local data: { [string]: any } = { SchemaVersion = 1, Coins = 7 }
			SchemaMigrator.Apply(data, 1, 3, PlayerMigrations)
			expect(data.Coins).to.equal(7)
			expect(type(data.Resources)).to.equal("table")
			expect(type(data.Buildings)).to.equal("table")
			expect(data.SchemaVersion).to.equal(3)
		end)

		it("não sobrescreve construções que já existem", function()
			local data: { [string]: any } = { SchemaVersion = 2, Resources = {}, Buildings = { B1 = "Cabin" } }
			SchemaMigrator.Apply(data, 2, 3, PlayerMigrations)
			expect(data.Buildings.B1).to.equal("Cabin")
		end)
	end)
	describe("PlayerMigrations (v3 → v4: estoque de produção)", function()
		it("adiciona o estoque vazio e preserva construções e saldo", function()
			local data: { [string]: any } =
				{ SchemaVersion = 3, Resources = { Wood = 12 }, Buildings = { B1 = "Fence", B2 = "Cabin" } }
			SchemaMigrator.Apply(data, 3, 4, PlayerMigrations)
			expect(type(data.Storage)).to.equal("table")
			expect(next(data.Storage)).to.equal(nil)
			expect(data.Resources.Wood).to.equal(12)
			expect(data.Buildings.B2).to.equal("Cabin")
			expect(data.SchemaVersion).to.equal(4)
		end)

		it("não sobrescreve um estoque que já existe", function()
			local data: { [string]: any } = { SchemaVersion = 3, Resources = {}, Buildings = {}, Storage = { B5 = 4 } }
			SchemaMigrator.Apply(data, 3, 4, PlayerMigrations)
			expect(data.Storage.B5).to.equal(4)
		end)

		it("migra da versão 1 até a 4 em sequência", function()
			local data: { [string]: any } = { SchemaVersion = 1 }
			SchemaMigrator.Apply(data, 1, 4, PlayerMigrations)
			expect(type(data.Resources)).to.equal("table")
			expect(type(data.Buildings)).to.equal("table")
			expect(type(data.Storage)).to.equal("table")
			expect(data.SchemaVersion).to.equal(4)
		end)
	end)

	describe("PlayerMigrations (v4 → v5: melhorias, expansões e objetivos)", function()
		it("adiciona níveis, expansões, estatísticas e objetivos preservando o perfil v4", function()
			local data: { [string]: any } = {
				SchemaVersion = 4,
				Resources = { Wood = 61 },
				Buildings = { B1 = "Fence", B5 = "Sawmill" },
				Storage = { B5 = 2 },
			}
			SchemaMigrator.Apply(data, 4, 5, PlayerMigrations)
			expect(data.SchemaVersion).to.equal(5)
			expect(type(data.Levels)).to.equal("table")
			expect(type(data.Expansions)).to.equal("table")
			expect(data.Objective).to.equal(0)
			expect(data.Resources.Wood).to.equal(61)
			expect(data.Buildings.B5).to.equal("Sawmill")
			expect(data.Storage.B5).to.equal(2)
		end)

		it("quem já construiu conta como tendo coletado a madeira do primeiro objetivo", function()
			local built: { [string]: any } = { SchemaVersion = 4, Resources = {}, Buildings = { B1 = "Fence" }, Storage = {} }
			SchemaMigrator.Apply(built, 4, 5, PlayerMigrations)
			expect(built.Stats.WoodCollected).to.equal(6)
			local fresh: { [string]: any } = { SchemaVersion = 4, Resources = {}, Buildings = {}, Storage = {} }
			SchemaMigrator.Apply(fresh, 4, 5, PlayerMigrations)
			expect(fresh.Stats.WoodCollected).to.equal(nil)
		end)

		it("migra da versão 1 até a 5 em sequência", function()
			local data: { [string]: any } = { SchemaVersion = 1 }
			SchemaMigrator.Apply(data, 1, 5, PlayerMigrations)
			expect(type(data.Storage)).to.equal("table")
			expect(type(data.Stats)).to.equal("table")
			expect(data.SchemaVersion).to.equal(5)
		end)
	end)
end
