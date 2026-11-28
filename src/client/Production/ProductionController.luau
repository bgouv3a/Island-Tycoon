--!strict
--[[
	Interface e feedback da produção (Serraria, Pedreira, Carpintaria). Não decide nada: o cliente só
	pede o recolhimento (HarvestProduction) e o saldo exibido é sempre o que o servidor envia.

	Feedback: indicador sobre o telhado (entrada e saída nas máquinas que processam, barra, "Cheio!",
	"Sem madeira"), animação de lâmina, roda, tora e peças com atributo Spin/Bob enquanto a máquina
	trabalha (nem cheia, nem sem matéria-prima), serragem, popups e som ao recolher.
	O indicador some enquanto um prompt da mesma máquina está visível (evita sobreposição).
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
local Components = require(script.Parent.Parent.UI.Components)
local Effects = require(script.Parent.Parent.UI.Effects)
local Format = require(script.Parent.Parent.UI.Format)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HarvestProduction = Remotes:WaitForChild("HarvestProduction") :: RemoteEvent
local HarvestResult = Remotes:WaitForChild("HarvestResult") :: RemoteEvent

local ANIMATE_DISTANCE = 120 -- só anima máquinas perto da câmera
local ANIMATE_DELAY = 1.5 -- espera o fim de Effects.BuildIn
local RESOLVE_RETRY_SECONDS = 0.5
local RESOLVE_WINDOW_SECONDS = 8 -- depois disso, só retenta se algo essencial faltar
local DEFAULT_CAPACITY = 30
local BLADE_SPEED = 9 -- rad/s (nível 1)
local SPEED_PER_LEVEL = 0.35 -- cada nível acelera a animação em 35%
local WHEEL_SPEED = 3 -- rad/s
local LOG_AMPLITUDE = 0.3 -- studs para cada lado (curso total de 0,6)
local LOG_SPEED = 2.2 -- rad/s
local BOB_SPEED = 3 -- rad/s do vaivém de peças com atributo Bob
local PULSE_SPEED = 7 -- rad/s do texto "Cheio!"
local INDICATOR_HEIGHT = 9 -- studs acima do centro da máquina: acima do telhado
local INDICATOR_DISTANCE = 60
local SAWDUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

type Animated = { Part: BasePart, Base: CFrame?, Spin: number?, Bob: number? }

type Section = { Label: TextLabel, Fill: Frame }

type Entry = {
	Model: Model,
	Output: BasePart?,
	Born: number,
	NextResolve: number,
	IsOwn: boolean,
	Gui: BillboardGui?,
	Pill: Frame?,
	Out: Section?,
	In: Section?,
	Warn: Frame?,
	Stroke: UIStroke?,
	Badge: TextLabel?,
	Level: number,
	Phase: number, -- tempo de animação acumulado (cresce mais rápido em níveis altos)
	Blade: Animated?,
	Wheel: Animated?,
	Log: Animated?,
	Extras: { [BasePart]: Animated }, -- peças genéricas com atributo Spin ou Bob
	Emitter: ParticleEmitter?,
	Full: boolean?, -- nil até o primeiro refresh (sem popup no estado inicial)
	Starved: boolean,
	Prompts: number, -- prompts desta máquina visíveis agora
	Animating: boolean,
	Connections: { RBXScriptConnection },
}

type Rule = { ResourceId: string, Input: { ResourceId: string, Amount: number }? }
local PRODUCERS: { [string]: Rule } = Gameplay.Production.Producers
local STRUCTURES: { [string]: { Name: string } } = Gameplay.Build.Structures

-- Cor das lascas ao recolher e da poeira da máquina, por recurso produzido.
local OUTPUT_COLORS: { [string]: Color3 } = {
	Wood = Palette.Plank,
	Stone = Palette.RockLight,
	Planks = Palette.PlankLight,
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

local function ruleOf(model: Model): Rule?
	local producerId = model:GetAttribute("Producer")
	return if type(producerId) == "string" then PRODUCERS[producerId] else nil
end

local function structureName(model: Model): string
	local producerId = model:GetAttribute("Producer")
	local structure = if type(producerId) == "string" then STRUCTURES[producerId] else nil
	return if structure ~= nil then structure.Name else "Máquina"
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

-- Uma seção do indicador: ícone do recurso, quantidade e barra. `x`/`width` em fração do indicador.
local function buildSection(pill: Frame, resourceId: string, x: number, width: number, barColor: Color3): Section
	local section = Instance.new("Frame")
	section.Name = `Section{resourceId}`
	section.BackgroundTransparency = 1
	section.Position = UDim2.fromScale(x, 0)
	section.Size = UDim2.fromScale(width, 1)
	section.Parent = pill

	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "Icon"
	iconHolder.AnchorPoint = Vector2.new(0, 0.5)
	iconHolder.Position = UDim2.fromScale(0.05, 0.5)
	iconHolder.Size = UDim2.fromScale(0.3, 0.8)
	iconHolder.BackgroundColor3 = Color3.fromRGB(255, 232, 196)
	iconHolder.Parent = section
	Theme.Corner(iconHolder, UDim.new(0.5, 0))
	local iconRatio = Instance.new("UIAspectRatioConstraint")
	iconRatio.AspectRatio = 1
	iconRatio.Parent = iconHolder
	Theme.ResourceIcon(iconHolder, resourceId).Size = UDim2.fromScale(0.82, 0.82)

	local label = Theme.Label(section, "0", Theme.TitleFont, Palette.UiTextLight)
	label.Name = "Amount"
	label.Position = UDim2.fromScale(0.4, 0.06)
	label.Size = UDim2.fromScale(0.58, 0.56)
	label.TextStrokeColor3 = Palette.UiPanelDark
	label.TextStrokeTransparency = 0
	local labelLimit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if labelLimit ~= nil then
		labelLimit.MaxTextSize = 60
	end

	local bar = Components.ProgressBar(section)
	bar.Track.Position = UDim2.fromScale(0.4, 0.68)
	bar.Track.Size = UDim2.fromScale(0.56, 0.2)
	Theme.Stroke(bar.Track, Palette.UiPanelDark, 1.5)
	bar.Set(0, nil, barColor)
	return { Label = label, Fill = bar.Fill }
end

local function buildIndicator(entry: Entry, anchor: BasePart)
	local rule = ruleOf(entry.Model)
	local processes = rule ~= nil and rule.Input ~= nil

	local gui = Instance.new("BillboardGui")
	gui.Name = "ProductionIndicator"
	gui.Size = UDim2.fromScale(if processes then 10 else 7, 3.8)
	-- Acima do telhado e centrado na máquina: longe dos prompts, que ficam junto das peças de baixo.
	gui.StudsOffset = Vector3.new(0, INDICATOR_HEIGHT, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = INDICATOR_DISTANCE
	gui.AlwaysOnTop = false
	gui.Adornee = anchor

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.05)
	pill.Size = UDim2.fromScale(1, 0.62)
	pill.BackgroundColor3 = Palette.UiPanel
	pill.Parent = gui
	Theme.Corner(pill, UDim.new(0.5, 0))
	local stroke = Theme.Stroke(pill, Palette.UiWood, 3)

	local outputId = if rule ~= nil then rule.ResourceId else Gameplay.Resources.WoodId
	local outSection: Section
	local inSection: Section? = nil
	if processes and rule ~= nil and rule.Input ~= nil then
		inSection = buildSection(pill, rule.Input.ResourceId, 0, 0.45, Palette.UiWood)
		local arrow = Theme.Label(pill, "→", Theme.TitleFont, Palette.UiWood)
		arrow.Name = "Arrow"
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
		arrow.Size = UDim2.fromScale(0.1, 0.6)
		outSection = buildSection(pill, outputId, 0.55, 0.45, Palette.UiGood)
	else
		outSection = buildSection(pill, outputId, 0, 1, Palette.UiGood)
	end

	-- Aviso de falta de matéria-prima, logo abaixo da pílula.
	local warn = Instance.new("Frame")
	warn.Name = "Warn"
	warn.AnchorPoint = Vector2.new(0.5, 0)
	warn.Position = UDim2.fromScale(0.5, 0.7)
	warn.Size = UDim2.fromScale(0.62, 0.26)
	warn.BackgroundColor3 = Palette.UiBad
	warn.Visible = false
	warn.Parent = gui
	Theme.Corner(warn, UDim.new(0.5, 0))
	Theme.Stroke(warn, Color3.fromRGB(176, 60, 54), 2.5)
	local warnText = Theme.Label(warn, "Sem matéria-prima", Theme.TitleFont, Palette.UiTextLight)
	warnText.Name = "Text"
	warnText.Position = UDim2.fromScale(0.06, 0.08)
	warnText.Size = UDim2.fromScale(0.88, 0.84)
	if rule ~= nil and rule.Input ~= nil then
		warnText.Text = `Sem {Format.Name(rule.Input.ResourceId):lower()}`
	end

	-- Selo de nível, sobre a borda superior esquerda.
	local badge = Instance.new("Frame")
	badge.Name = "LevelBadge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.fromScale(0.02, 0.05)
	badge.Size = UDim2.fromScale(if processes then 0.17 else 0.24, 0.26)
	badge.BackgroundColor3 = Palette.UiAccent
	badge.Parent = gui
	Theme.Corner(badge, UDim.new(0.5, 0))
	Theme.Stroke(badge, Palette.UiAccentDark, 2.5)
	local badgeText = Theme.Label(badge, "Nv 1", Theme.TitleFont, Palette.UiTextLight)
	badgeText.Position = UDim2.fromScale(0.08, 0.06)
	badgeText.Size = UDim2.fromScale(0.84, 0.88)
	badgeText.TextStrokeColor3 = Palette.UiAccentDark
	badgeText.TextStrokeTransparency = 0

	gui.Enabled = entry.Prompts == 0
	gui.Parent = anchor
	entry.Gui = gui
	entry.Pill = pill
	entry.Out = outSection
	entry.In = inSection
	entry.Warn = warn
	entry.Stroke = stroke
	entry.Badge = badgeText
end

local function setSection(section: Section, text: string, ratio: number, color: Color3, textColor: Color3)
	section.Label.Text = text
	section.Label.TextColor3 = textColor
	TweenService:Create(section.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
		:Play()
	section.Fill.BackgroundColor3 = color
end

local function refresh(entry: Entry)
	local out = entry.Out
	local stroke = entry.Stroke
	if out == nil or stroke == nil then
		return
	end
	local model = entry.Model
	local stored, capacity, full = readStock(model)
	setSection(
		out,
		if full then "Cheio!" else `{stored}/{capacity}`,
		stored / capacity,
		if full then Palette.UiBad else Palette.UiGood,
		if full then Color3.fromRGB(255, 120, 108) else Palette.UiTextLight
	)
	if not full then
		Theme.Scale(out.Label).Scale = 1
	end

	local starved = false
	local input = entry.In
	if input ~= nil then
		local amount = model:GetAttribute("Input")
		local inputCapacity = model:GetAttribute("InputCapacity")
		local current = if type(amount) == "number" then amount else 0
		local limit = if type(inputCapacity) == "number" and inputCapacity > 0 then inputCapacity else 1
		starved = model:GetAttribute("Starved") == true
		setSection(
			input,
			`{current}/{limit}`,
			current / limit,
			if starved then Palette.UiBad else Palette.UiWood,
			if starved then Color3.fromRGB(255, 120, 108) else Palette.UiTextLight
		)
	end
	entry.Starved = starved
	local warn = entry.Warn
	if warn ~= nil then
		warn.Visible = starved
	end
	stroke.Color = if full or starved then Palette.UiBad else Palette.UiWood

	local badge = entry.Badge
	if badge ~= nil then
		local level = model:GetAttribute("Level")
		local shown = if type(level) == "number" then level else 1
		badge.Text = `Nv {shown}`
		if shown ~= entry.Level then
			entry.Level = shown
			if badge.Parent ~= nil and badge.Parent:IsA("GuiObject") then
				Theme.Pop(badge.Parent, 0.3)
			end
		end
	end

	if entry.Full == false and full and entry.IsOwn and entry.Output ~= nil then
		Popup.Show(entry.Output, `{structureName(model)} cheia!`, Palette.UiBad)
	end
	entry.Full = full
end

-- Peças com atributo Spin ou Bob (e BaseCFrame) dentro do modelo, além de Blade/Wheel/Log.
local function scanExtras(entry: Entry)
	local special = { Blade = true, Wheel = true, Log = true }
	for _, descendant in entry.Model:GetDescendants() do
		if descendant:IsA("BasePart") and entry.Extras[descendant] == nil and not special[descendant.Name] then
			local spin = descendant:GetAttribute("Spin")
			local bob = descendant:GetAttribute("Bob")
			local hasSpin = type(spin) == "number"
			local hasBob = type(bob) == "number"
			if hasSpin or hasBob then
				local base = descendant:GetAttribute("BaseCFrame")
				entry.Extras[descendant] = {
					Part = descendant,
					Base = if typeof(base) == "CFrame" then base else nil,
					Spin = if hasSpin then spin else nil,
					Bob = if hasBob then bob else nil,
				}
			end
		end
	end
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
		buildIndicator(entry, model.PrimaryPart or output)
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
	scanExtras(entry)
	if entry.Emitter == nil then
		local blade = entry.Blade
		local rule = ruleOf(model)
		local color = if rule ~= nil then OUTPUT_COLORS[rule.ResourceId] else nil
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Sawdust"
		emitter.Texture = SAWDUST_TEXTURE
		emitter.Color = ColorSequence.new(color or Palette.Plank)
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
	for _, extra in entry.Extras do
		restore(extra)
	end
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
	-- Peças genéricas: Spin gira no eixo X local (rad/s); Bob sobe e desce no eixo Y do mundo (studs).
	for _, extra in entry.Extras do
		if extra.Part.Parent ~= nil then
			local cframe = baseOf(extra)
			local spin = extra.Spin
			if spin ~= nil then
				cframe = cframe * CFrame.Angles(phase * spin, 0, 0)
			end
			local bob = extra.Bob
			if bob ~= nil then
				cframe = CFrame.new(0, math.sin(phase * BOB_SPEED) * bob, 0) * cframe
			end
			extra.Part.CFrame = cframe
		end
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
		if entry.Pill == nil or entry.Emitter == nil or now - entry.Born < RESOLVE_WINDOW_SECONDS then
			if now >= entry.NextResolve then
				entry.NextResolve = now + RESOLVE_RETRY_SECONDS
				resolve(entry)
			end
		end

		local output = entry.Output
		local near = output ~= nil and (output.Position - cameraPosition).Magnitude <= ANIMATE_DISTANCE
		local working = not (entry.Full == true) and not entry.Starved
		if near and working and now - entry.Born >= ANIMATE_DELAY then
			animate(entry, dt)
		elseif entry.Animating then
			stopAnimation(entry)
		end

		-- "Cheio!" pulsando
		local out = entry.Out
		if entry.Full == true and near and out ~= nil then
			Theme.Scale(out.Label).Scale = 1 + 0.1 * math.sin(now * PULSE_SPEED)
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
	local gui = entry.Gui
	if gui ~= nil and gui.Parent ~= nil then
		gui:Destroy()
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
		Gui = nil,
		Pill = nil,
		Out = nil,
		In = nil,
		Warn = nil,
		Stroke = nil,
		Badge = nil,
		Level = 1,
		Phase = 0,
		Blade = nil,
		Wheel = nil,
		Log = nil,
		Extras = {},
		Emitter = nil,
		Full = nil,
		Starved = false,
		Prompts = 0,
		Animating = false,
		Connections = {},
	}
	entries[model] = entry
	for _, attribute in { "Stored", "Capacity", "Full", "Level", "Input", "InputCapacity", "Starved" } do
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

-- Máquina dona do prompt (o prompt fica numa peça de dentro do modelo).
local function entryOfPrompt(prompt: ProximityPrompt): Entry?
	local node: Instance? = prompt.Parent
	while node ~= nil do
		if node:IsA("Model") and entries[node] ~= nil then
			return entries[node]
		end
		node = node.Parent
	end
	return nil
end

-- Enquanto um prompt da máquina está visível, o indicador some para não cobrir nem se sobrepor a ele.
local function setPromptShown(prompt: ProximityPrompt, shown: boolean)
	local entry = entryOfPrompt(prompt)
	if entry == nil then
		return
	end
	entry.Prompts = math.max(entry.Prompts + (if shown then 1 else -1), 0)
	local gui = entry.Gui
	if gui ~= nil then
		gui.Enabled = entry.Prompts == 0
	end
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
		local rule = ruleOf(entry.Model)
		local resourceId = if rule ~= nil then rule.ResourceId else Gameplay.Resources.WoodId
		Popup.Show(output, `+{amount} {Format.Name(resourceId)}`)
		Effects.Burst(output.Position + Vector3.new(0, 3, 0), OUTPUT_COLORS[resourceId] or Palette.Plank, 14, "Chips")
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
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		setPromptShown(prompt, true)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		setPromptShown(prompt, false)
	end)
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
