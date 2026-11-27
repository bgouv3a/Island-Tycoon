--!strict
--[[
	Regras de coleta: quem pode coletar uma árvore, e quando. Lógica pura, sem serviços do Roblox.
	O servidor calcula os dados (dono, distância, tempo) e esta função decide.

	Ordem de verificação: ilha → dono → cooldown → alcance.
]]

local Collect = {}

export type Check = {
	OwnerSlot: number?, -- ilha do jogador (nil se não tiver ilha)
	NodeSlot: number, -- ilha da árvore
	ReadyAt: number, -- instante (os.clock) em que a árvore volta a dar recurso
	Now: number, -- instante atual (os.clock)
	Distance: number, -- distância entre o jogador e a árvore, em studs
	Reach: number, -- alcance máximo, em studs
}

export type Result = "Ok" | "NoIsland" | "NotOwner" | "Cooldown" | "OutOfReach"

function Collect.Evaluate(check: Check): Result
	if check.OwnerSlot == nil then
		return "NoIsland"
	end
	if check.OwnerSlot ~= check.NodeSlot then
		return "NotOwner"
	end
	if check.Now < check.ReadyAt then
		return "Cooldown"
	end
	-- A forma `not (a <= b)` também rejeita NaN.
	if not (check.Distance <= check.Reach) then
		return "OutOfReach"
	end
	return "Ok"
end

return Collect
