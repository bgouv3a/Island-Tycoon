--!strict
--[[
	Painel de melhoria das construções produtivas (Serraria). O prompt "UpgradePrompt" (tecla F)
	só abre o painel; a compra é o pedido UpgradeProducer(siteId). Custo, saldo, nível e alcance
	são decididos pelo servidor: o painel só mostra o que a máquina publica (atributos) e a config.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gameplay = require(Shared.Config.Gameplay)
local Audio = require(Shared.Config.Audio)
local Palette = require(Shared.Art.Palette)
local Popup = require(script.Parent.Parent.UI.Popup)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)
local Effects = require(script.Parent.Parent.UI.Effects)
local Format = require(script.Parent.Parent.UI.Format)
local Panel = require(script.Parent.Parent.UI.Panel)
local World = require(script.Parent.Parent.UI.World)
local ResourceController = require(script.Parent.Parent.Resources.ResourceController)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpgradeProducer = Remotes:WaitForChild("UpgradeProducer") :: RemoteEvent
local UpgradeResult = Remotes:WaitForChild("UpgradeResult") :: RemoteEvent

local WIDTH = 430
local HEIGHT = 330
local PENDING_TIMEOUT = 3
local WATCHED = { "Level", "MaxLevel", "Amount", "IntervalSeconds", "Capacity" }

type LevelRule = { Amount: number, IntervalSeconds: number, Capacity: number, Cost: { [string]: number }? }
type ProducerRule = { ResourceId: string, Levels: { LevelRule } }

local PRODUCERS: { [string]: ProducerRule } = Gameplay.Production.Producers
local STRUCTURES: { [string]: { Name: string } } = Gameplay.Build.Structures

local MESSAGES: { [string]: string } = {
	MaxLevel = "Esta construção já está no nível máximo.",
	OutOfReach = "Chegue mais perto da máquina para melhorar.",
	NotUpgradable = "Esta construção não pode ser melhorada.",
	NotLoaded = "Seus dados ainda estão carregando. Tente em instantes.",
}

local UpgradeController = {}

local initialized = false
local panel: Panel.Panel? = nil
local production: TextLabel? = nil
local capacity: TextLabel? = nil
local costRow: Frame? = nil
local statusLabel: TextLabel? = nil
local action: TextButton? = nil
local currentModel: Model? = nil
local currentSite: string? = nil
local connections: { RBXScriptConnection } = {}
local pending = false
local pendingToken = 0

local function setStatus(text: string, color: Color3?)
	local label = statusLabel
	if label ~= nil then
		label.Text = text
		label.TextColor3 = color or Palette.UiMuted
	end
end

local function numberAttribute(model: Model, name: string, fallback: number): number
	local value = model:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

local function rateText(rule: LevelRule): string
	return `{rule.Amount} a cada {rule.IntervalSeconds} s`
end

local function clearCosts()
	local row = costRow
	if row == nil then
		return
	end
	for _, child in row:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- Uma pastilha por recurso do custo: ícone e "tenho/preciso", verde se cobre, vermelha se não.
local function addCostChip(row: Frame, resourceId: string, need: number, order: number)
	local chip = Components.ResourceChip(row, resourceId, order, 126, 38)
	chip.Set(math.floor(ResourceController.Get(resourceId)), need)
end

local function refresh()
	local current = panel
	local model = currentModel
	local productionLabel = production
	local capacityLabel = capacity
	local row = costRow
	local button = action
	if current == nil or model == nil or productionLabel == nil or capacityLabel == nil or row == nil or button == nil then
		return
	end
	local producerId = model:GetAttribute("Producer")
	local rule = if type(producerId) == "string" then PRODUCERS[producerId] else nil
	if rule == nil then
		return
	end
	local structure = STRUCTURES[producerId :: string]
	local name = if structure ~= nil then structure.Name else "Máquina"
	local maxLevel = numberAttribute(model, "MaxLevel", #rule.Levels)
	local level = math.clamp(numberAttribute(model, "Level", 1), 1, maxLevel)
	local now = rule.Levels[level]
	local nextRule = if level < maxLevel then rule.Levels[level + 1] else nil

	current.Title.Text = `{name} · Nível {level}/{maxLevel}`
	local produced = Format.Name(rule.ResourceId):lower()
	local nowCapacity = numberAttribute(model, "Capacity", now.Capacity)
	local nowRate: LevelRule = {
		Amount = numberAttribute(model, "Amount", now.Amount),
		IntervalSeconds = numberAttribute(model, "IntervalSeconds", now.IntervalSeconds),
		Capacity = nowCapacity,
	}
	if nextRule ~= nil then
		productionLabel.Text = `Produção ({produced}): {rateText(nowRate)}  →  {rateText(nextRule)}`
		capacityLabel.Text = `Capacidade: {nowCapacity}  →  {nextRule.Capacity}`
	else
		productionLabel.Text = `Produção ({produced}): {rateText(nowRate)}`
		capacityLabel.Text = `Capacidade: {nowCapacity}`
	end

	clearCosts()
	if nextRule == nil then
		button.Text = "Nível máximo"
		button.Active = false
		Theme.Recolor(button, Palette.UiNeutral, Palette.UiMuted)
		return
	end
	local cost = nextRule.Cost or {}
	local order = 0
	local missing = false
	for _, id in Format.OrderedIds() do
		local need = cost[id]
		if need ~= nil and need > 0 then
			order += 1
			addCostChip(row, id, need, order)
			if ResourceController.Get(id) < need then
				missing = true
			end
		end
	end
	if pending then
		button.Text = "Melhorando..."
		button.Active = false
		Theme.Recolor(button, Palette.UiNeutral, Palette.UiMuted)
	elseif missing then
		button.Text = "Faltam recursos"
		button.Active = true
		Theme.Recolor(button, Palette.UiNeutral, Palette.UiMuted)
	else
		button.Text = `Melhorar para o nível {level + 1}`
		button.Active = true
		Theme.Recolor(button, Palette.UiGood, Palette.UiGoodDark)
	end
end

local function disconnectAll()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function onClosed()
	disconnectAll()
	currentModel = nil
	currentSite = nil
	pending = false
end

local function press()
	local current = panel
	local model = currentModel
	local site = currentSite
	if current == nil or model == nil or site == nil or pending then
		return
	end
	local producerId = model:GetAttribute("Producer")
	local rule = if type(producerId) == "string" then PRODUCERS[producerId] else nil
	if rule == nil then
		return
	end
	local maxLevel = numberAttribute(model, "MaxLevel", #rule.Levels)
	local level = numberAttribute(model, "Level", 1)
	if level >= maxLevel then
		setStatus(MESSAGES.MaxLevel, Palette.UiBad)
		current.Shake()
		return
	end
	local cost = rule.Levels[level + 1].Cost or {}
	local balances: { [string]: number } = {}
	for _, id in Format.OrderedIds() do
		balances[id] = ResourceController.Get(id)
	end
	local lack = Format.Missing(cost, balances)
	if lack ~= "" then
		setStatus(`Faltam {lack} para melhorar.`, Palette.UiBad)
		current.Shake()
		return
	end
	pending = true
	pendingToken += 1
	local token = pendingToken
	setStatus("Melhorando...")
	refresh()
	UpgradeProducer:FireServer(site)
	task.delay(PENDING_TIMEOUT, function()
		if pending and pendingToken == token then
			pending = false
			refresh()
		end
	end)
end

local function buildPanel()
	local built = Panel.Create({
		Name = "UpgradePanel",
		Title = "Melhoria",
		Width = WIDTH,
		Height = HEIGHT,
		CloseDistance = Gameplay.Production.ReachStuds + 6,
		OnClosed = onClosed,
	})
	local body = built.Body

	local function line(text: string, y: number, height: number, color: Color3): TextLabel
		local label = Theme.Label(body, text, Theme.BodyFont, color)
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, height)
		label.TextXAlignment = Enum.TextXAlignment.Left
		return label
	end

	production = line("", 0, 30, Palette.UiText)
	capacity = line("", 34, 28, Palette.UiText)
	line("Custo da melhoria", 70, 22, Palette.UiMuted)

	local row = Instance.new("Frame")
	row.Name = "Cost"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 94)
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	costRow = row

	local button = Theme.Button(body, "Melhorar", Palette.UiGood, Palette.UiGoodDark)
	button.Name = "Action"
	button.Position = UDim2.fromOffset(0, 144)
	button.Size = UDim2.new(1, 0, 0, 52)
	button.Activated:Connect(press)
	action = button

	statusLabel = line("", 202, 24, Palette.UiMuted)
	panel = built
end

local function findModelBySite(siteId: string): Model?
	local island = World.FindOwnIsland()
	local builds = if island ~= nil then island:FindFirstChild("Builds") else nil
	if builds == nil then
		return nil
	end
	for _, child in builds:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("SiteId") == siteId then
			return child
		end
	end
	return nil
end

local function onUpgradeResult(siteId: any, result: any, level: any)
	if type(siteId) ~= "string" or type(result) ~= "string" then
		return
	end
	pending = false
	pendingToken += 1
	local current = panel
	local model = if currentSite == siteId then currentModel else findModelBySite(siteId)

	if result == "Ok" then
		local newLevel = if type(level) == "number" then level else 0
		local producerId = if model ~= nil then model:GetAttribute("Producer") else nil
		local structure = if type(producerId) == "string" then STRUCTURES[producerId] else nil
		local name = if structure ~= nil then structure.Name else "Máquina"
		setStatus(`{name} nível {newLevel}!`, Palette.UiGoodDark)
		if model ~= nil then
			local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if part ~= nil then
				local pivot = model:GetPivot().Position
				Effects.Burst(pivot + Vector3.new(0, 3, 0), Palette.UiAccent, 28, "Sparkle")
				Effects.Burst(pivot + Vector3.new(0, 1, 0), Palette.Sand, 14, "Dust")
				Effects.Sound(Audio.Build, part)
				Popup.Show(part, `{name} nível {newLevel}!`, Palette.UiAccent)
			end
		end
	else
		local text = MESSAGES[result]
		if result == "Insufficient" and model ~= nil then
			local producerId = model:GetAttribute("Producer")
			local rule = if type(producerId) == "string" then PRODUCERS[producerId] else nil
			local nextRule = if rule ~= nil then rule.Levels[numberAttribute(model, "Level", 1) + 1] else nil
			local balances: { [string]: number } = {}
			for _, id in Format.OrderedIds() do
				balances[id] = ResourceController.Get(id)
			end
			local lack = if nextRule ~= nil then Format.Missing(nextRule.Cost or {}, balances) else ""
			text = if lack ~= "" then `Faltam {lack} para melhorar.` else "Recursos insuficientes."
		end
		setStatus(text or "Não foi possível melhorar.", Palette.UiBad)
		if current ~= nil then
			current.Shake()
		end
	end
	refresh()
end

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer or prompt.Name ~= "UpgradePrompt" then
		return
	end
	local current = panel
	local siteId = prompt:GetAttribute("SiteId")
	if current == nil or type(siteId) ~= "string" then
		return
	end
	local node: Instance? = prompt.Parent
	while node ~= nil and not (node:IsA("Model") and node:GetAttribute("Producer") ~= nil) do
		node = node.Parent
	end
	local anchor = prompt.Parent
	if node == nil or anchor == nil or not anchor:IsA("BasePart") or not World.IsOwn(node) then
		return
	end
	local model = node :: Model

	disconnectAll()
	currentModel = model
	currentSite = siteId
	pending = false
	for _, name in WATCHED do
		table.insert(connections, model:GetAttributeChangedSignal(name):Connect(refresh))
	end
	table.insert(connections, ResourceController.OnChanged(refresh))
	setStatus("Melhore para produzir mais e guardar mais.")
	current.Open(anchor)
	refresh()
end

function UpgradeController.Init()
	assert(not initialized, "UpgradeController.Init chamado mais de uma vez")
	initialized = true

	buildPanel()
	UpgradeResult.OnClientEvent:Connect(onUpgradeResult)
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
end

return UpgradeController
