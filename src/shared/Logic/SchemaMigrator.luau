--!strict
--[[
	Controle de versão do schema de dados. Lógica pura, sem serviços do Roblox.

	Regra de segurança: dados de uma versão MAIS NOVA nunca são alterados
	por um servidor com código antigo (status "TooNew").
]]

local SchemaMigrator = {}

export type Status = "Current" | "NeedsMigration" | "TooNew" | "Invalid"

-- Migração altera os dados in-place e deve levar do version-1 para version.
export type Migration = (data: { [string]: any }) -> ()

function SchemaMigrator.GetStatus(storedVersion: any, currentVersion: number): Status
	if type(storedVersion) ~= "number" then
		return "Invalid"
	end
	if storedVersion ~= storedVersion or storedVersion < 1 or storedVersion % 1 ~= 0 or storedVersion == math.huge then
		return "Invalid"
	end
	if storedVersion > currentVersion then
		return "TooNew"
	end
	if storedVersion < currentVersion then
		return "NeedsMigration"
	end
	return "Current"
end

-- Aplica as migrações em sequência, de fromVersion até toVersion.
-- Falha se alguma migração estiver faltando, para nunca gravar dados num formato parcial.
function SchemaMigrator.Apply(
	data: { [string]: any },
	fromVersion: number,
	toVersion: number,
	migrations: { [number]: Migration }
)
	for version = fromVersion + 1, toVersion do
		local migration = migrations[version]
		if migration == nil then
			error(`Migração para a versão {version} não está registrada`)
		end
		migration(data)
		data.SchemaVersion = version
	end
end

return SchemaMigrator
