--!strict
--[[
	Cartão de objetivos e feixe-guia. O estado vem do servidor (RequestObjective, ObjectiveChanged):
	o cliente só mostra o objetivo atual, o progresso, a recompensa e um feixe de luz até o alvo
	indicado por `Guide`. Nada aqui decide ou concede recompensa.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)
local Palette = require(Shared.Art.Palette)
local Onboarding = require(Shared.Logic.Onboarding)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Effects = require(script.Parent.Parent.UI.Effects)
local Format = require(script.Parent.Parent.UI.Format)
local World = require(script.Parent.Parent.UI.World)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestObjective = Remotes:WaitForChild("RequestObjective") :: RemoteEvent
local ObjectiveChanged = Remotes:WaitForChild("ObjectiveChanged") :: RemoteEvent

local REFRESH_SECONDS = 0.4
local SCAN_SECONDS = 3
local HIDE_BEAM_DISTANCE = 9
local FINAL_SECONDS = 6
local REQUEST_RETRY_SECONDS = 4
local REQUEST_RETRIES = 3

type Reward = { [string]: number }
type State = {
	Index: number,
	Total: number,
	Done: boolean,
	Id: string?,
	Text: string?,
	Current: number?,
	Target: number?,
	Guide: string?,
	Reward: Reward?,
}

local OnboardingController = {}

local initialized = false
local state: State? = nil
local announced: { [string]: boolean } = {}
local sawActive = false
local finalToken = 0

local card: Frame? = nil
local header: TextLabel? = nil
local body: TextLabel? = nil
local fill: Frame? = nil
local progressLabel: TextLabel? = nil
local progressTrack: Frame? = nil
local rewardLabel: TextLabel? = nil

local beam: Beam? = nil
local fromAttachment: Attachment? = nil
local toAttachment: Attachment? = nil

-- Candidatos do feixe, atualizados por varredura periódica da ilha própria.
local scannedIsland: Model? = nil
local lastScan = 0
local nodeParts: { BasePart } = {}
local padParts: { BasePart } = {}
local marketParts: { BasePart } = {}
local boardParts: { BasePart } = {}

local function buildCard()
	local gui = Instance.new("ScreenGui")
	gui.Name = "OnboardingHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- Lateral direita, espelhando o HUD de recursos: fora do chat e acima dos botões do celular.
	local frame = Instance.new("Frame")
	frame.Name = "Objective"
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -12, 0.36, 0)
	frame.Size = UDim2.fromScale(0.3, 0.2)
	frame.BackgroundColor3 = Palette.UiPanel
	frame.Visible = false
	frame.Parent = gui
	Theme.Corner(frame, UDim.new(0, 16))
	Theme.Stroke(frame, Palette.UiAccentDark, 3)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 2.3
	ratio.Parent = frame
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(210, 92)
	limit.MaxSize = Vector2.new(310, 135)
	limit.Parent = frame

	local top = Theme.Label(frame, "", Theme.TitleFont, Palette.UiAccentDark)
	top.Position = UDim2.fromScale(0.05, 0.05)
	top.Size = UDim2.fromScale(0.9, 0.16)
	top.TextXAlignment = Enum.TextXAlignment.Left

	local text = Theme.Label(frame, "", Theme.BodyFont, Palette.UiText)
	text.Position = UDim2.fromScale(0.05, 0.23)
	text.Size = UDim2.fromScale(0.9, 0.33)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top

	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.Position = UDim2.fromScale(0.05, 0.6)
	track.Size = UDim2.fromScale(0.9, 0.15)
	track.BackgroundColor3 = Palette.UiNeutral
	track.Parent = frame
	Theme.Corner(track, UDim.new(0.5, 0))

	local inner = Instance.new("Frame")
	inner.Name = "Fill"
	inner.Size = UDim2.fromScale(0, 1)
	inner.BackgroundColor3 = Palette.UiGood
	inner.Parent = track
	Theme.Corner(inner, UDim.new(0.5, 0))

	local count = Theme.Label(track, "", Theme.TitleFont, Palette.UiTextLight)
	count.Size = UDim2.fromScale(1, 1)
	count.TextStrokeColor3 = Palette.UiPanelDark
	count.TextStrokeTransparency = 0.3

	local reward = Theme.Label(frame, "", Theme.BodyFont, Palette.UiWood)
	reward.Position = UDim2.fromScale(0.05, 0.8)
	reward.Size = UDim2.fromScale(0.9, 0.14)
	reward.TextXAlignment = Enum.TextXAlignment.Left

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	card = frame
	header = top
	body = text
	fill = inner
	progressLabel = count
	progressTrack = track
	rewardLabel = reward
end

local function showCard()
	local frame = card
	if frame ~= nil and not frame.Visible then
		frame.Visible = true
		Theme.Pop(frame, 0.12)
	end
end

local function render(current: State)
	local frame = card
	local top = header
	local text = body
	local inner = fill
	local count = progressLabel
	local track = progressTrack
	local reward = rewardLabel
	if
		frame == nil
		or top == nil
		or text == nil
		or inner == nil
		or count == nil
		or track == nil
		or reward == nil
	then
		return
	end
	if current.Done then
		return
	end
	showCard()
	top.Text = `Objetivo {current.Index}/{current.Total}`
	text.Text = current.Text or ""
	local target = current.Target or 0
	local value = current.Current or 0
	track.Visible = target > 0
	if target > 0 then
		count.Text = `{math.min(value, target)}/{target}`
		TweenService:Create(inner, TweenInfo.new(0.3), { Size = UDim2.fromScale(Onboarding.Progress(value, target), 1) })
			:Play()
	end
	local rewardText = if current.Reward ~= nil then Format.Reward(current.Reward) else ""
	reward.Text = if rewardText ~= "" then `Recompensa: {rewardText}` else ""
end

local function showFinal()
	local frame = card
	local top = header
	local text = body
	local track = progressTrack
	local reward = rewardLabel
	if frame == nil or top == nil or text == nil or track == nil or reward == nil then
		return
	end
	showCard()
	top.Text = "Parabéns!"
	text.Text = "Você concluiu todos os objetivos. Continue explorando e expandindo sua ilha!"
	track.Visible = false
	reward.Text = ""
	finalToken += 1
	local token = finalToken
	task.delay(FINAL_SECONDS, function()
		if finalToken == token then
			frame.Visible = false
		end
	end)
end

local function hideCard()
	finalToken += 1
	local frame = card
	if frame ~= nil then
		frame.Visible = false
	end
end

-- Um único aviso para todos os objetivos concluídos de uma mensagem.
local function announce(completed: any)
	if type(completed) ~= "table" then
		return
	end
	local total: Reward = {}
	local count = 0
	for _, entry in completed do
		if type(entry) == "table" and type(entry.Id) == "string" and not announced[entry.Id] then
			announced[entry.Id] = true
			count += 1
			if type(entry.Reward) == "table" then
				for id, amount in entry.Reward do
					if type(id) == "string" and type(amount) == "number" then
						total[id] = (total[id] or 0) + amount
					end
				end
			end
		end
	end
	if count == 0 then
		return
	end
	local reward = Format.Reward(total)
	local prefix = if count == 1 then "Objetivo concluído!" else `{count} objetivos concluídos!`
	Toast.Show(if reward ~= "" then `{prefix} {reward}` else prefix, Palette.UiGood, 4)
	Effects.Sound(Audio.Build, nil)
end

local function readState(raw: any): State?
	if type(raw) ~= "table" or type(raw.Index) ~= "number" or type(raw.Total) ~= "number" then
		return nil
	end
	local reward: Reward? = nil
	if type(raw.Reward) == "table" then
		reward = raw.Reward
	end
	return {
		Index = raw.Index,
		Total = raw.Total,
		Done = raw.Done == true,
		Id = if type(raw.Id) == "string" then raw.Id else nil,
		Text = if type(raw.Text) == "string" then raw.Text else nil,
		Current = if type(raw.Current) == "number" then raw.Current else nil,
		Target = if type(raw.Target) == "number" then raw.Target else nil,
		Guide = if type(raw.Guide) == "string" then raw.Guide else nil,
		Reward = reward,
	}
end

local function onObjectiveChanged(rawState: any, completed: any)
	local parsed = readState(rawState)
	if parsed == nil then
		return
	end
	state = parsed
	announce(completed)
	if parsed.Done then
		if sawActive then
			sawActive = false
			showFinal()
		else
			hideCard()
		end
	else
		sawActive = true
		render(parsed)
	end
end

-- Feixe-guia -----------------------------------------------------------------------------------

local function ensureBeam(): Beam
	local existing = beam
	if existing ~= nil then
		return existing
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "GuideFrom"
	local a1 = Instance.new("Attachment")
	a1.Name = "GuideTo"
	a1.Parent = Workspace.Terrain

	local guide = Instance.new("Beam")
	guide.Name = "OnboardingGuide"
	guide.Attachment0 = a0
	guide.Attachment1 = a1
	guide.Color = ColorSequence.new(Palette.UiAccent)
	guide.LightEmission = 0.6
	guide.FaceCamera = true
	guide.Width0 = 0.7
	guide.Width1 = 0.7
	guide.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	guide.TextureMode = Enum.TextureMode.Wrap
	guide.TextureLength = 3
	guide.TextureSpeed = 1.5
	guide.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.3, 0.15),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	guide.Enabled = false
	guide.Parent = Workspace.Terrain

	beam = guide
	fromAttachment = a0
	toAttachment = a1
	return guide
end

local function setGuide(target: BasePart?, root: BasePart?)
	local guide = ensureBeam()
	local a0 = fromAttachment
	local a1 = toAttachment
	if target == nil or root == nil or a0 == nil or a1 == nil then
		guide.Enabled = false
		return
	end
	if a0.Parent ~= root then
		-- Ao renascer, o personagem antigo é destruído junto com o attachment (Parent travado):
		-- cria um novo no corpo atual em vez de mover o antigo.
		a0:Destroy()
		local fresh = Instance.new("Attachment")
		fresh.Name = "GuideFrom"
		fresh.Parent = root
		guide.Attachment0 = fresh
		fromAttachment = fresh
	end
	a1.WorldPosition = target.Position + Vector3.new(0, 2, 0)
	guide.Enabled = (root.Position - target.Position).Magnitude > HIDE_BEAM_DISTANCE
end

local function rescan(island: Model)
	table.clear(nodeParts)
	table.clear(padParts)
	table.clear(marketParts)
	table.clear(boardParts)
	for _, descendant in island:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("NodeKind") ~= nil then
				table.insert(nodeParts, descendant)
			elseif descendant:GetAttribute("SiteId") ~= nil then
				table.insert(padParts, descendant)
			elseif descendant:GetAttribute("Market") == true then
				table.insert(marketParts, descendant)
			elseif descendant:GetAttribute("Area") ~= nil then
				table.insert(boardParts, descendant)
			end
		end
	end
	scannedIsland = island
	lastScan = os.clock()
end

local function nearest(list: { BasePart }, from: Vector3, accept: (BasePart) -> boolean): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in list do
		if part.Parent ~= nil and accept(part) then
			local distance = (part.Position - from).Magnitude
			if distance < bestDistance then
				best = part
				bestDistance = distance
			end
		end
	end
	return best
end

-- Peça "Output" (ou principal) da máquina produtiva mais próxima; prefere as com estoque.
local function nearestProducer(island: Model, from: Vector3): BasePart?
	local builds = island:FindFirstChild("Builds")
	if builds == nil then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	local bestHasStock = false
	for _, child in builds:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Producer") ~= nil then
			local output = child:FindFirstChild("Output", true)
			local part = if output ~= nil and output:IsA("BasePart")
				then output
				else (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true))
			if part ~= nil then
				local stored = child:GetAttribute("Stored")
				local hasStock = type(stored) == "number" and stored > 0
				local distance = (part.Position - from).Magnitude
				if (hasStock and not bestHasStock) or (hasStock == bestHasStock and distance < bestDistance) then
					best = part
					bestDistance = distance
					bestHasStock = hasStock
				end
			end
		end
	end
	return best
end

local function isBoardAvailable(board: BasePart): boolean
	local node: Instance? = board
	while node ~= nil do
		if node:GetAttribute("Unlocked") == true then
			return false
		end
		node = node.Parent
	end
	return true
end

local function findTarget(guide: string, island: Model, from: Vector3): BasePart?
	if guide == "Tree" or guide == "Rock" then
		return nearest(nodeParts, from, function(part: BasePart): boolean
			return part:GetAttribute("NodeKind") == guide and part:GetAttribute("Ready") == true
		end)
	elseif guide == "Site" then
		return nearest(padParts, from, function(part: BasePart): boolean
			return part:GetAttribute("Open") == true
		end)
	elseif guide == "Producer" then
		return nearestProducer(island, from)
	elseif guide == "Market" then
		return nearest(marketParts, from, function(): boolean
			return true
		end)
	elseif guide == "Expansion" then
		return nearest(boardParts, from, isBoardAvailable)
	end
	return nil
end

local function updateGuide()
	local current = state
	local island = World.FindOwnIsland()
	local root = World.Root()
	if current == nil or current.Done or current.Guide == nil or island == nil or root == nil then
		setGuide(nil, nil)
		return
	end
	if island ~= scannedIsland or os.clock() - lastScan >= SCAN_SECONDS then
		rescan(island)
	end
	setGuide(findTarget(current.Guide, island, root.Position), root)
end

function OnboardingController.Init()
	assert(not initialized, "OnboardingController.Init chamado mais de uma vez")
	initialized = true

	buildCard()
	ObjectiveChanged.OnClientEvent:Connect(onObjectiveChanged)
	RequestObjective:FireServer()

	task.spawn(function()
		-- O servidor pode ainda estar carregando o perfil: repete o pedido algumas vezes.
		local retries = 0
		while true do
			if state == nil and retries < REQUEST_RETRIES then
				-- ainda sem estado
				retries += 1
				task.wait(REQUEST_RETRY_SECONDS)
				if state == nil then
					RequestObjective:FireServer()
				end
			else
				updateGuide()
				task.wait(REFRESH_SECONDS)
			end
		end
	end)
end

return OnboardingController
