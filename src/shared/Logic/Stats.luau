--!strict
--[[
	Estatísticas acumuladas do jogador (Stats no perfil): madeira coletada, coletas da Serraria,
	moedas ganhas etc. Servem aos objetivos. Lógica pura; usada dentro de DataService.Mutate.
]]

local Stats = {}

-- Soma `amount` (inteiro positivo) à estatística `key`. Valores inválidos são ignorados.
function Stats.Add(data: { [string]: any }, key: string, amount: number)
	if type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount <= 0 then
		return
	end
	local stats = data.Stats
	if type(stats) ~= "table" then
		stats = {}
		data.Stats = stats
	end
	local current = stats[key]
	stats[key] = (if type(current) == "number" and current == current then current else 0) + amount
end

function Stats.Get(data: { [string]: any }, key: string): number
	local stats = data.Stats
	local value = if type(stats) == "table" then stats[key] else nil
	return if type(value) == "number" and value == value then value else 0
end

return Stats
