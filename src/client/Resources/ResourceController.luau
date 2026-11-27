--!strict
--[[
	Interface e feedback da coleta e do saldo. Não decide nada: o cliente só pede a coleta
	(CollectResource), e o saldo exibido é sempre o que o servidor envia (ResourcesChanged).

	HUD compacto com um recurso por linha (Moedas e Madeira sempre; Pedra depois da primeira
	vez que o jogador a tiver). Feedback de coleta: popup "+N Recurso", lascas, som e contagem
	de recuperação sobre o nó coletado.

	API para outros controllers: Get(id), OnChanged(callback).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)
local Palette = require(Shared.Art.Palette)
local Popup = require(script.Parent.Parent.UI.Popup)
local Theme = require(script.Parent.Parent.UI.Theme)
local Effects = require(script.Parent.Parent.UI.Effects)
local Format = require(script.Parent.Parent.UI.Format)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CollectResource = Remotes:WaitForChild("CollectResource") :: RemoteEvent
local RequestResources = Remotes:WaitForChild("RequestResources") :: RemoteEvent
local ResourcesChanged = Remotes:WaitForChild("ResourcesChanged") :: RemoteEvent
local ResourceCollected = Remotes:WaitForChild("ResourceCollected") :: RemoteEvent

local ALWAYS_VISIBLE: { [string]: boolean } = { Coins = true, Wood = true }
local ROW_WIDTH = 168
local ROW_HEIGHT = 34
local RETRY_SECONDS = 0.3
local RETRY_COUNT = 6

type Row = { Frame: Frame, Amount: TextLabel }

local ResourceController = {}

local initialized = false
local rows: { [string]: Row } = {}
local balances: { [string]: number } = {}
local seenPositive: { [string]: boolean } = {}
local changedEvent = Instance.new("BindableEvent")
local nodes: { [string]: BasePart } = {}

local function buildRow(parent: Frame, resourceId: string, order: number): Row
	local frame = Instance.new("Frame")
	frame.Name = resourceId
	frame.LayoutOrder = order
	frame.Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT)
	frame.BackgroundColor3 = Palette.UiPanel
	frame.Visible = ALWAYS_VISIBLE[resourceId] == true
	frame.Parent = parent
	Theme.Corner(frame, UDim.new(0.5, 0))
	Theme.Stroke(frame, Palette.UiWood, 2.5)

	local iconBack = Instance.new("Frame")
	iconBack.Name = "Icon"
	iconBack.AnchorPoint = Vector2.new(0, 0.5)
	iconBack.Position = UDim2.new(0, 4, 0.5, 0)
	iconBack.Size = UDim2.fromOffset(ROW_HEIGHT - 8, ROW_HEIGHT - 8)
	iconBack.BackgroundColor3 = Color3.fromRGB(255, 232, 196)
	iconBack.Parent = frame
	Theme.Corner(iconBack, UDim.new(0.5, 0))
	Theme.ResourceIcon(iconBack, resourceId).Size = UDim2.fromScale(0.84, 0.84)

	local amount = Theme.Label(frame, "0", Theme.TitleFont, Palette.UiText)
	amount.Name = "Amount"
	amount.Position = UDim2.new(0, ROW_HEIGHT + 2, 0, 3)
	amount.Size = UDim2.new(0, 62, 1, -6)
	amount.TextXAlignment = Enum.TextXAlignment.Left

	local caption = Theme.Label(frame, Format.Name(resourceId), Theme.BodyFont, Palette.UiMuted)
	caption.Name = "Caption"
	caption.Position = UDim2.new(0, ROW_HEIGHT + 66, 0, 8)
	caption.Size = UDim2.new(0, ROW_WIDTH - ROW_HEIGHT - 74, 1, -16)
	caption.TextXAlignment = Enum.TextXAlignment.Right

	return { Frame = frame, Amount = amount }
end

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ResourcesHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- Lateral esquerda: longe do chat (canto superior) e acima do analógico no celular.
	local list = Instance.new("Frame")
	list.Name = "Resources"
	list.AnchorPoint = Vector2.new(0, 0.5)
	list.Position = UDim2.new(0, 12, 0.36, 0)
	list.Size = UDim2.fromOffset(ROW_WIDTH, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, id in Format.OrderedIds() do
		rows[id] = buildRow(list, id, index)
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Encontra o nó pelo identificador publicado pelo servidor (atributo NodeId), com cache.
-- Nós de áreas de expansão surgem depois: se não achar, reescaneia.
local function findNode(nodeId: string): BasePart?
	local cached = nodes[nodeId]
	if cached ~= nil and cached.Parent ~= nil then
		return cached
	end
	local islands = Workspace:FindFirstChild("Islands")
	if islands == nil then
		return nil
	end
	for _, descendant in islands:GetDescendants() do
		if descendant:IsA("BasePart") then
			local id = descendant:GetAttribute("NodeId")
			if type(id) == "string" then
				nodes[id] = descendant
			end
		end
	end
	return nodes[nodeId]
end

-- Contagem regressiva sobre o nó até ele voltar a dar recurso.
local function showRegrow(node: BasePart, seconds: number, isTree: boolean)
	local existing = node:FindFirstChild("Regrow")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Regrow"
	gui.Size = UDim2.fromScale(3.4, 1.4)
	gui.StudsOffset = Vector3.new(0, if isTree then 5 else 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	gui.Adornee = node

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Palette.UiPanel
	label.BackgroundTransparency = 0.1
	label.TextColor3 = Palette.UiText
	label.Font = Theme.TitleFont
	label.TextScaled = true
	label.Parent = gui
	Theme.Corner(label, UDim.new(0.5, 0))
	Theme.Stroke(label, Palette.UiGoodDark, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.Parent = label

	gui.Parent = node
	task.spawn(function()
		local remaining = math.ceil(seconds)
		while remaining > 0 and gui.Parent ~= nil do
			label.Text = if isTree then `Cresce em {remaining}s` else `Volta em {remaining}s`
			task.wait(1)
			remaining -= 1
		end
		gui:Destroy()
	end)
end

local function onResourcesChanged(resources: any)
	if type(resources) ~= "table" then
		return
	end
	for id, row in rows do
		local value = resources[id]
		local amount = if type(value) == "number" then value else 0
		local previous = balances[id]
		balances[id] = amount
		if amount > 0 and not seenPositive[id] then
			seenPositive[id] = true
			row.Frame.Visible = true
		end
		row.Amount.Text = tostring(amount)
		if previous ~= nil and amount ~= previous then
			Theme.Pop(row.Frame, if amount > previous then 0.16 else 0.07)
		end
	end
	changedEvent:Fire(balances)
end

local function playCollect(node: BasePart, amount: number, resourceId: string, cooldown: number)
	local isTree = node:GetAttribute("NodeKind") ~= "Rock"
	Popup.Show(node, `+{amount} {Format.Name(resourceId)}`, if isTree then nil else Palette.RockLight)
	if isTree then
		Effects.Burst(node.Position + Vector3.new(0, 8, 0), Palette.LeafLight, 14, "Chips")
		Effects.Burst(node.Position + Vector3.new(0, 2, 0), Palette.Trunk, 10, "Chips")
	else
		Effects.Burst(node.Position + Vector3.new(0, 2, 0), Palette.RockLight, 14, "Chips")
		Effects.Burst(node.Position + Vector3.new(0, 1, 0), Palette.Rock, 10, "Chips")
	end
	Effects.Sound(Audio.Collect, node)
	showRegrow(node, cooldown, isTree)
end

local function onResourceCollected(nodeId: any, amount: any, resourceId: any, cooldown: any)
	if type(nodeId) ~= "string" or type(amount) ~= "number" or type(resourceId) ~= "string" then
		return
	end
	local seconds = if type(cooldown) == "number" then cooldown else 6
	local node = findNode(nodeId)
	if node ~= nil then
		playCollect(node, amount, resourceId, seconds)
		return
	end
	-- O nó pode ainda estar replicando (área recém-criada): tenta de novo por um instante.
	task.spawn(function()
		for _ = 1, RETRY_COUNT do
			task.wait(RETRY_SECONDS)
			local late = findNode(nodeId)
			if late ~= nil then
				playCollect(late, amount, resourceId, seconds)
				return
			end
		end
	end)
end

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer or prompt.Name ~= "CollectPrompt" then
		return
	end
	local parent = prompt.Parent
	if parent == nil then
		return
	end
	local nodeId = parent:GetAttribute("NodeId")
	if type(nodeId) == "string" then
		CollectResource:FireServer(nodeId)
	end
end

-- Saldo atual de um recurso (0 se desconhecido).
function ResourceController.Get(resourceId: string): number
	return balances[resourceId] or 0
end

-- Chama `callback(saldos)` a cada saldo recebido do servidor. Devolve a conexão.
function ResourceController.OnChanged(callback: (balances: { [string]: number }) -> ()): RBXScriptConnection
	return changedEvent.Event:Connect(callback)
end

function ResourceController.Init()
	assert(not initialized, "ResourceController.Init chamado mais de uma vez")
	initialized = true

	buildHud()
	ResourcesChanged.OnClientEvent:Connect(onResourcesChanged)
	ResourceCollected.OnClientEvent:Connect(onResourceCollected)
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)

	RequestResources:FireServer()
end

return ResourceController
