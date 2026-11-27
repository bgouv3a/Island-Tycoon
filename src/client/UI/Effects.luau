--!strict
--[[
	Efeitos de feedback no cliente: partículas, sons e animação de construção.
	Só visual e local: nada aqui altera o estado do jogo.
	Partículas usam texturas internas do Roblox (rbxasset://), sem assets externos.
]]

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Effects = {}

export type SoundConfig = { Id: string, Volume: number }
export type BurstKind = "Chips" | "Dust" | "Sparkle"

local TEXTURES: { [BurstKind]: string } = {
	Chips = "rbxasset://textures/particles/sparkles_main.dds",
	Dust = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}

-- Explosão curta de partículas em um ponto do mundo.
function Effects.Burst(position: Vector3, color: Color3, count: number, kind: BurstKind)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = TEXTURES[kind]
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = if kind == "Sparkle" then 0.6 else 0
	emitter.Enabled = false
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.SpreadAngle = Vector2.new(180, 180)
	if kind == "Chips" then
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		emitter.Speed = NumberRange.new(8, 14)
		emitter.Lifetime = NumberRange.new(0.5, 0.8)
		emitter.Acceleration = Vector3.new(0, -40, 0)
	elseif kind == "Dust" then
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		emitter.Speed = NumberRange.new(4, 8)
		emitter.Lifetime = NumberRange.new(0.8, 1.2)
		emitter.Drag = 4
	else
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		emitter.Speed = NumberRange.new(6, 12)
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Acceleration = Vector3.new(0, 6, 0)
	end
	emitter.Parent = holder
	holder.Parent = Workspace
	emitter:Emit(count)
	Debris:AddItem(holder, 2)
end

-- Toca um som. Com `at`, o som sai daquela peça (3D); sem, toca direto para o jogador.
function Effects.Sound(config: SoundConfig, at: BasePart?)
	local sound = Instance.new("Sound")
	sound.SoundId = config.Id
	sound.Volume = config.Volume
	sound.RollOffMaxDistance = 90
	if at ~= nil then
		sound.Parent = at
		sound:Play()
		Debris:AddItem(sound, 4)
	else
		sound.Parent = SoundService
		SoundService:PlayLocalSound(sound)
		Debris:AddItem(sound, 4)
	end
end

-- Animação de construção: as peças descem do alto e assentam com quique, uma após a outra.
-- Altera só a cópia local (o servidor continua dono da posição real).
function Effects.BuildIn(model: Model)
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	table.sort(parts, function(a: BasePart, b: BasePart): boolean
		return a.Position.Y < b.Position.Y
	end)
	for index, part in parts do
		local target = part.CFrame
		local transparency = part.Transparency
		part.CFrame = target + Vector3.new(0, 6, 0)
		part.Transparency = 1
		local delay = (index - 1) * 0.035
		task.delay(delay, function()
			if part.Parent == nil then
				return
			end
			TweenService
				:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = target })
				:Play()
			TweenService:Create(part, TweenInfo.new(0.15), { Transparency = transparency }):Play()
		end)
	end
end

return Effects
