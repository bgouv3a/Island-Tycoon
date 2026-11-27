--!strict
--[[
	Atribuição de ilhas: cada chave (UserId do jogador) recebe um slot exclusivo.
	Ao sair, o slot volta a ficar livre. Lógica pura, sem serviços do Roblox.

	- Dois jogadores nunca recebem o mesmo slot.
	- Atribuir de novo a mesma chave devolve o slot que ela já tem.
]]

local IslandAllocator = {}

export type Allocator = {
	SlotCount: number,
	BySlot: { [number]: number }, -- slot → chave
	ByKey: { [number]: number }, -- chave → slot
}

function IslandAllocator.new(slotCount: number): Allocator
	assert(slotCount >= 1 and slotCount % 1 == 0, "slotCount deve ser inteiro e maior que zero")
	return {
		SlotCount = slotCount,
		BySlot = {},
		ByKey = {},
	}
end

-- Devolve o slot da chave (o mesmo, se já tiver um). Retorna nil se não houver slot livre.
function IslandAllocator.Assign(allocator: Allocator, key: number): number?
	local existing = allocator.ByKey[key]
	if existing ~= nil then
		return existing
	end
	for slot = 1, allocator.SlotCount do
		if allocator.BySlot[slot] == nil then
			allocator.BySlot[slot] = key
			allocator.ByKey[key] = slot
			return slot
		end
	end
	return nil
end

-- Libera o slot da chave. Devolve o slot liberado, ou nil se a chave não tinha slot.
function IslandAllocator.Release(allocator: Allocator, key: number): number?
	local slot = allocator.ByKey[key]
	if slot == nil then
		return nil
	end
	allocator.ByKey[key] = nil
	allocator.BySlot[slot] = nil
	return slot
end

function IslandAllocator.GetSlot(allocator: Allocator, key: number): number?
	return allocator.ByKey[key]
end

return IslandAllocator
