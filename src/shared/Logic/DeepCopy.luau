--!strict
--[[
	Cópia profunda de dados no formato de tabela (JSON-like). Lógica pura, sem serviços do Roblox.

	- Tabelas aninhadas e listas são copiadas recursivamente: a cópia não compartilha tabelas com o original.
	- Referências circulares são preservadas (a cópia também é circular) e não causam laço infinito.
	- Metatables não são copiadas: os dados do jogador não usam metatables.
]]

local DeepCopy = {}

local function copy(value: any, seen: { [any]: any }): any
	if type(value) ~= "table" then
		return value
	end
	local existing = seen[value]
	if existing ~= nil then
		return existing
	end
	local result: { [any]: any } = {}
	seen[value] = result
	for key, inner in value do
		result[key] = copy(inner, seen)
	end
	return result
end

-- Retorna uma cópia independente de value. Valores que não são tabelas são devolvidos sem alteração.
function DeepCopy.Clone(value: any): any
	return copy(value, {})
end

return DeepCopy
