--!strict
--[[
	Interface e feedback da produção (Serraria). Não decide nada: o cliente só pede o recolhimento
	(HarvestProduction) e o saldo exibido é sempre o que o servidor envia.

	Feedback: indicador de estoque sobre a construção (N/capacidade, barra, "Cheio!"), animação
	de lâmina, roda e tora enquanto produz, serragem, popups e som ao recolher.
	Tudo é local: peças e partículas criadas/movidas aqui não afetam o servidor.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Audio = require(Shared.Config.Audio)
local Palette = require(Shared.Art.Palette)
local Popup = require(script.Parent.Parent.UI.Popup)
local Theme = require(script.Parent.Parent.UI.Theme)
local Effects = require(script.Parent.Parent.UI.Effects)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HarvestProduction = Remotes:WaitForChild("HarvestProduction") :: RemoteEvent
local HarvestResult = Remotes:WaitForChild("HarvestResult") :: RemoteEvent

local ANIMATE_DISTANCE = 120 -- só anima serrarias perto da câmera
local ANIMATE_DELAY = 1.5 -- espera o fim de Effects.BuildIn
local RESOLVE_RETRY_SECONDS = 0.5
local DEFAULT_CAPACITY = 30
local BLADE_SPEED = 9 -- rad/s (nível 1)
local SPEED_PER_LEVEL = 0.35 -- cada nível acelera a animação em 35%
local WHEEL_SPEED = 3 -- rad/s
local LOG_AMPLITUDE = 0.3 -- studs para cada lado (curso total de 0,6)
local LOG_SPEED = 2.2 -- rad/s
local PULSE_SPEED = 7 -- rad/s do texto "Cheio!"
local SAWDUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

type Animated = { Part: BasePart, Base: CFrame? }

type Entry = {
	Model: Model,
	Output: BasePart?,
	Born: number,
	NextResolve: number,
	IsOwn: boolean,
	Pill: Frame?,
	Label: TextLabel?,
	Fill: Frame?,
	Stroke: UIStroke?,
	Badge: TextLabel?,
	Level: number,
	Phase: number, -- tempo de animação acumulado (cresce mais rápido em níveis altos)
	Blade: Animated?,
	Wheel: Animated?,
	Log: Animated?,
	Emitter: ParticleEmitter?,
	Full: boolean?, -- nil até o primeiro refresh (sem popup no estado inicial)
	Animating: boolean,
	Connections: { RBXScriptConnection },
}

local ProductionController = {}

local initialized = false
local harvested = false
local entries: { [Model]: Entry } = {}
local pendingWatch: { [Model]: RBXScriptConnection } = {}
local callbacks: { () -> () } = {}

local function isOwnModel(model: Model): boolean
	local builds = model.Parent
	local island = if builds ~= nil then builds.Parent else nil
	return island ~= nil and island:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
end

-- Peça do indicador e do prompt: "Output", ou a peça principal, ou a primeira peça.
local function findOutput(model: Model): BasePart?
	local named = model:FindFirstChild("Output", true)
	if named ~= nil and named:IsA("BasePart") then
		return named
	end
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function findAnimated(model: Model, name: string): Animated?
	local part = model:FindFirstChild(name, true)
	if part == nil or not part:IsA("BasePart") then
		return nil
	end
	local base = part:GetAttribute("BaseCFrame")
	return { Part = part, Base = if typeof(base) == "CFrame" then base else nil }
end

local function readStock(model: Model): (number, number, boolean)
	local stored = model:GetAttribute("Stored")
	local capacity = model:GetAttribute("Capacity")
	local full = model:GetAttribute("Full")
	return if type(stored) == "number" then stored else 0,
		if type(capacity) == "number" and capacity > 0 then capacity else DEFAULT_CAPACITY,
		full == true
end

local function buildIndicator(entry: Entry, output: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ProductionIndicator"
	gui.Size = UDim2.fromScale(7, 2.7)
	gui.StudsOffset = Vector3.new(0, 5.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Adornee = output

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.56)
	pill.Size = UDim2.fromScale(1, 0.82)
	pill.BackgroundColor3 = Palette.UiPanel
	pill.Parent = gui
	Theme.Corner(pill, UDim.new(0.5, 0))
	local stroke = Theme.Stroke(pill, Palette.UiWood, 3)

	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "Icon"
	iconHolder.AnchorPoint = Vector2.new(0, 0.5)
	iconHolder.Position = UDim2.fromScale(0.04, 0.5)
	iconHolder.Size = UDim2.fromScale(0.27, 0.8)
	iconHolder.BackgroundColor3 = Color3.fromRGB(255, 232, 196)
	iconHolder.Parent = pill
	Theme.Corner(iconHolder, UDim.new(0.5, 0))
	local iconRatio = Instance.new("UIAspectRatioConstraint")
	iconRatio.AspectRatio = 1
	iconRatio.Parent = iconHolder
	Theme.WoodIcon(iconHolder).Size = UDim2.fromScale(0.82, 0.82)

	local label = Theme.Label(pill, "0", Theme.TitleFont, Palette.UiTextLight)
	label.Name = "Amount"
	label.Position = UDim2.fromScale(0.34, 0.06)
	label.Size = UDim2.fromScale(0.6, 0.56)
	label.TextStrokeColor3 = Palette.UiPanelDark
	label.TextStrokeTransparency = 0
	local labelLimit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if labelLimit ~= nil then
		labelLimit.MaxTextSize = 60
	end

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromScale(0.36, 0.68)
	track.Size = UDim2.fromScale(0.56, 0.2)
	track.BackgroundColor3 = Palette.UiNeutral
	track.Parent = pill
	Theme.Corner(track, UDim.new(0.5, 0))
	Theme.Stroke(track, Palette.UiPanelDark, 1.5)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Palette.UiGood
	fill.Parent = track
	Theme.Corner(fill, UDim.new(0.5, 0))

	-- Selo de nível, sobre a borda superior esquerda.
	local badge = Instance.new("Frame")
	badge.Name = "LevelBadge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.fromScale(0.03, 0.12)
	badge.Size = UDim2.fromScale(0.3, 0.3)
	badge.BackgroundColor3 = Palette.UiAccent
	badge.Parent = gui
	Theme.Corner(badge, UDim.new(0.5, 0))
	Theme.Stroke(badge, Palette.UiAccentDark, 2.5)
	local badgeText = Theme.Label(badge, "Nv 1", Theme.TitleFont, Palette.UiTextLight)
	badgeText.Position = UDim2.fromScale(0.08, 0.06)
	badgeText.Size = UDim2.fromScale(0.84, 0.88)
	badgeText.TextStrokeColor3 = Palette.UiAccentDark
	badgeText.TextStrokeTransparency = 0

	gui.Parent = output
	entry.Pill = pill
	entry.Label = label
	entry.Fill = fill
	entry.Stroke = stroke
	entry.Badge = badgeText
end

local function refresh(entry: Entry)
	local label = entry.Label
	local fill = entry.Fill
	local stroke = entry.Stroke
	if label == nil or fill == nil or stroke == nil then
		return
	end
	local stored, capacity, full = readStock(entry.Model)
	local ratio = math.clamp(stored / capacity, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
	fill.BackgroundColor3 = if full then Palette.UiBad else Palette.UiGood
	stroke.Color = if full then Palette.UiBad else Palette.UiWood
	label.TextColor3 = if full then Color3.fromRGB(255, 120, 108) else Palette.UiTextLight
	local badge = entry.Badge
	if badge ~= nil then
		local level = entry.Model:GetAttribute("Level")
		local shown = if type(level) == "number" then level else 1
		badge.Text = `Nv {shown}`
		if shown ~= entry.Level then
			entry.Level = shown
			if badge.Parent ~= nil and badge.Parent:IsA("GuiObject") then
				Theme.Pop(badge.Parent, 0.3)
			end
		end
	end
	if not full then
		label.Text = `{stored}/{capacity}`
		Theme.Scale(label).Scale = 1
	else
		label.Text = "Cheio!"
	end

	if entry.Full == false and full and entry.IsOwn and entry.Output ~= nil then
		Popup.Show(entry.Output, "Serraria cheia!", Palette.UiBad)
	end
	entry.Full = full
end

-- Cria o que depende das peças do modelo (podem chegar depois do modelo). Idempotente.
local function resolve(entry: Entry)
	local model = entry.Model
	local output = entry.Output
	if output == nil or output.Parent == nil then
		output = findOutput(model)
		entry.Output = output
	end
	if output == nil then
		return
	end
	if entry.Pill == nil then
		buildIndicator(entry, output)
		refresh(entry)
	end
	if entry.Blade == nil then
		entry.Blade = findAnimated(model, "Blade")
	end
	if entry.Wheel == nil then
		entry.Wheel = findAnimated(model, "Wheel")
	end
	if entry.Log == nil then
		entry.Log = findAnimated(model, "Log")
	end
	if entry.Emitter == nil then
		local blade = entry.Blade
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Sawdust"
		emitter.Texture = SAWDUST_TEXTURE
		emitter.Color = ColorSequence.new(Palette.Plank)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Acceleration = Vector3.new(0, -6, 0)
		emitter.Rate = 7
		emitter.LightInfluence = 1
		emitter.Enabled = false
		emitter.Parent = if blade ~= nil then blade.Part else output
		entry.Emitter = emitter
	end
end

local function restore(animated: Animated?)
	if animated ~= nil and animated.Base ~= nil and animated.Part.Parent ~= nil then
		animated.Part.CFrame = animated.Base
	end
end

local function stopAnimation(entry: Entry)
	entry.Animating = false
	local emitter = entry.Emitter
	if emitter ~= nil then
		emitter.Enabled = false
	end
	restore(entry.Blade)
	restore(entry.Wheel)
	restore(entry.Log)
end

-- Base de repouso: atributo BaseCFrame, ou o CFrame atual na primeira vez (após a animação de chegada).
local function baseOf(animated: Animated): CFrame
	local base = animated.Base
	if base == nil then
		base = animated.Part.CFrame
		animated.Base = base
	end
	return base :: CFrame
end

local function animate(entry: Entry, dt: number)
	entry.Phase += dt * (1 + SPEED_PER_LEVEL * (entry.Level - 1))
	local phase = entry.Phase
	entry.Animating = true
	local emitter = entry.Emitter
	if emitter ~= nil then
		emitter.Enabled = true
	end
	local blade = entry.Blade
	if blade ~= nil and blade.Part.Parent ~= nil then
		blade.Part.CFrame = baseOf(blade) * CFrame.Angles(phase * BLADE_SPEED, 0, 0)
	end
	local wheel = entry.Wheel
	if wheel ~= nil and wheel.Part.Parent ~= nil then
		wheel.Part.CFrame = baseOf(wheel) * CFrame.Angles(phase * WHEEL_SPEED, 0, 0)
	end
	local log = entry.Log
	if log ~= nil and log.Part.Parent ~= nil then
		log.Part.CFrame = baseOf(log) * CFrame.new(math.sin(phase * LOG_SPEED) * LOG_AMPLITUDE, 0, 0)
	end
end

local function onStep(dt: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local now = os.clock()
	for _, entry in entries do
		if entry.Pill == nil or entry.Blade == nil or entry.Emitter == nil then
			if now >= entry.NextResolve then
				entry.NextResolve = now + RESOLVE_RETRY_SECONDS
				resolve(entry)
			end
		end

		local output = entry.Output
		local near = output ~= nil and (output.Position - cameraPosition).Magnitude <= ANIMATE_DISTANCE
		local full = entry.Full == true
		if near and not full and now - entry.Born >= ANIMATE_DELAY then
			animate(entry, dt)
		elseif entry.Animating then
			stopAnimation(entry)
		end

		-- "Cheio!" pulsando
		local label = entry.Label
		if full and near and label ~= nil then
			Theme.Scale(label).Scale = 1 + 0.1 * math.sin(now * PULSE_SPEED)
		end
	end
end

local function unregister(model: Model)
	local watch = pendingWatch[model]
	if watch ~= nil then
		watch:Disconnect()
		pendingWatch[model] = nil
	end
	local entry = entries[model]
	if entry == nil then
		return
	end
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	if entry.Animating then
		stopAnimation(entry)
	end
	local pill = entry.Pill
	if pill ~= nil and pill.Parent ~= nil and pill.Parent.Parent ~= nil then
		pill.Parent:Destroy()
	end
	local emitter = entry.Emitter
	if emitter ~= nil then
		emitter:Destroy()
	end
	entries[model] = nil
end

local function register(model: Model)
	if entries[model] ~= nil then
		return
	end
	local entry: Entry = {
		Model = model,
		Output = nil,
		Born = os.clock(),
		NextResolve = 0,
		IsOwn = isOwnModel(model),
		Pill = nil,
		Label = nil,
		Fill = nil,
		Stroke = nil,
		Badge = nil,
		Level = 1,
		Phase = 0,
		Blade = nil,
		Wheel = nil,
		Log = nil,
		Emitter = nil,
		Full = nil,
		Animating = false,
		Connections = {},
	}
	entries[model] = entry
	for _, attribute in { "Stored", "Capacity", "Full", "Level" } do
		table.insert(
			entry.Connections,
			model:GetAttributeChangedSignal(attribute):Connect(function()
				refresh(entry)
			end)
		)
	end
	resolve(entry)
end

local function consider(instance: Instance)
	if not instance:IsA("Model") or entries[instance] ~= nil or pendingWatch[instance] ~= nil then
		return
	end
	if instance:GetAttribute("Producer") ~= nil then
		register(instance)
	elseif instance:GetAttribute("StructureId") ~= nil then
		-- Atributos podem chegar depois do modelo.
		pendingWatch[instance] = instance:GetAttributeChangedSignal("Producer"):Connect(function()
			if instance:GetAttribute("Producer") ~= nil then
				local watch = pendingWatch[instance]
				if watch ~= nil then
					watch:Disconnect()
					pendingWatch[instance] = nil
				end
				register(instance)
			end
		end)
	end
end

local function watchIslands(islands: Instance)
	for _, descendant in islands:GetDescendants() do
		consider(descendant)
	end
	islands.DescendantAdded:Connect(consider)
	islands.DescendantRemoving:Connect(function(instance: Instance)
		if instance:IsA("Model") then
			unregister(instance)
		end
	end)
end

local function findEntryBySite(siteId: string): Entry?
	for _, entry in entries do
		if entry.IsOwn and entry.Model:GetAttribute("SiteId") == siteId then
			return entry
		end
	end
	return nil
end

local function playHarvestSound(output: BasePart)
	local sound = Instance.new("Sound")
	sound.SoundId = Audio.Collect.Id
	sound.Volume = Audio.Collect.Volume
	sound.PlaybackSpeed = 1.2
	sound.RollOffMaxDistance = 90
	sound.Parent = output
	sound:Play()
	Debris:AddItem(sound, 4)
end

local function onHarvestResult(siteId: any, result: any, amount: any)
	if type(siteId) ~= "string" or type(result) ~= "string" then
		return
	end
	local entry = findEntryBySite(siteId)
	local output = if entry ~= nil then entry.Output else nil
	if entry == nil or output == nil then
		return
	end

	if result == "Ok" and type(amount) == "number" then
		Popup.Show(output, `+{amount} {Gameplay.Resources.WoodName}`)
		Effects.Burst(output.Position + Vector3.new(0, 3, 0), Palette.Plank, 14, "Chips")
		Effects.Burst(output.Position + Vector3.new(0, 4, 0), Palette.UiAccent, 10, "Sparkle")
		playHarvestSound(output)
		local pill = entry.Pill
		if pill ~= nil then
			Theme.Pop(pill, 0.2)
		end
		harvested = true
		for _, callback in callbacks do
			task.spawn(callback)
		end
	elseif result == "Empty" then
		Popup.Show(output, "Ainda vazio", Palette.UiMuted)
	elseif result == "OutOfReach" then
		Popup.Show(output, "Chegue mais perto", Palette.UiMuted)
	end
end

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer or prompt.Name ~= "HarvestPrompt" then
		return
	end
	local siteId = prompt:GetAttribute("SiteId")
	if type(siteId) == "string" then
		HarvestProduction:FireServer(siteId)
	end
end

-- Já recolheu produção nesta sessão (usado pela orientação).
function ProductionController.HarvestedThisSession(): boolean
	return harvested
end

-- Registra uma função chamada a cada recolhimento bem-sucedido (confirmado pelo servidor).
function ProductionController.OnHarvest(callback: () -> ())
	table.insert(callbacks, callback)
end

function ProductionController.Init()
	assert(not initialized, "ProductionController.Init chamado mais de uma vez")
	initialized = true

	HarvestResult.OnClientEvent:Connect(onHarvestResult)
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	RunService.Heartbeat:Connect(onStep)

	local existing = Workspace:FindFirstChild("Islands")
	if existing ~= nil then
		watchIslands(existing)
	else
		task.spawn(function()
			watchIslands(Workspace:WaitForChild("Islands"))
		end)
	end
end

return ProductionController
