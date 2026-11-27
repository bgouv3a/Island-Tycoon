--!strict
--[[
	Consultas ao mundo replicado usadas por vários controllers: ilha própria, dono de uma peça
	e raiz do personagem. Só leitura, sem decisões de jogo.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local World = {}

-- Ilha do próprio jogador, identificada pelo atributo OwnerUserId publicado pelo servidor.
function World.FindOwnIsland(): Model?
	local islands = Workspace:FindFirstChild("Islands")
	if islands == nil then
		return nil
	end
	for _, island in islands:GetChildren() do
		if island:IsA("Model") and island:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return island
		end
	end
	return nil
end

-- A peça pertence à ilha do próprio jogador?
function World.IsOwn(instance: Instance): boolean
	local node: Instance? = instance
	while node ~= nil do
		local owner = node:GetAttribute("OwnerUserId")
		if owner ~= nil then
			return owner == Players.LocalPlayer.UserId
		end
		node = node.Parent
	end
	return false
end

function World.Root(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Centro da caixa que envolve todas as peças de um contêiner (nil se não houver peças).
function World.BoundsCenter(container: Instance): Vector3?
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			found = true
			low = low:Min(descendant.Position)
			high = high:Max(descendant.Position)
		end
	end
	if not found then
		return nil
	end
	return (low + high) / 2
end

return World
