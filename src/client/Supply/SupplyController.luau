--!strict
--[[
	Painel de abastecimento das máquinas que processam matéria-prima (Carpintaria). O prompt
	"SupplyPrompt" (tecla G) só abre o painel; o pedido é SupplyProducer(siteId, quantidade) e quem
	decide saldo, espaço e alcance é o servidor. SupplyResult é a única fonte de verdade da mensagem.
	O painel mostra o que a máquina publica (atributos Input, InputCapacity, Stored, Full, Starved).
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
local SupplyProducer = Remotes:WaitForChild("SupplyProducer") :: RemoteEvent
local SupplyResult = Remotes:WaitForChild("SupplyResult") :: RemoteEvent

local WIDTH = 400
local HEIGHT = 300
local SMALL_LOT = 10
local PENDING_TIMEOUT = 3
local WATCHED = { "Input", "InputCapacity", "Stored", "Capacity", "Full", "Starved" }

local PRODUCERS: { [string]: { ResourceId: string, Input: { ResourceId: string, Amount: number }? } } =
	Gameplay.Production.Producers
local STRUCTURES: { [string]: { Name: string } } = Gameplay.Build.Structures

local MESSAGES: { [string]: string } = {
	InputFull = "A entrada já está cheia.",
	Insufficient = "Você não tem essa quantidade.",
	NoInput = "Esta máquina não recebe matéria-prima.",
	InvalidAmount = "Quantidade inválida.",
	OutOfReach = "Chegue mais perto da entrada.",
	NotLoaded = "Seus dados ainda estão carregando. Tente em instantes.",
}

local SupplyController = {}

local initialized = false
local panel: Panel.Panel? = nil
local amountLabel: TextLabel? = nil
local bar: Components.Bar? = nil
local balanceLabel: TextLabel? = nil
local stateLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local smallButton: TextButton? = nil
local fillButton: TextButton? = nil
local iconSlot: Frame? = nil
local currentModel: Model? = nil
local currentSite: string? = nil
local currentInput: BasePart? = nil
local shownIcon: string? = nil
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

local function inputId(model: Model): string
	local attribute = model:GetAttribute("InputId")
	if type(attribute) == "string" then
		return attribute
	end
	local producerId = model:GetAttribute("Producer")
	local rule = if type(producerId) == "string" then PRODUCERS[producerId] else nil
	return if rule ~= nil and rule.Input ~= nil then rule.Input.ResourceId else Gameplay.Resources.WoodId
end

local function refresh()
	local current = panel
	local model = currentModel
	local amount = amountLabel
	local progress = bar
	local balance = balanceLabel
	local state = stateLabel
	local small = smallButton
	local fill = fillButton
	local slot = iconSlot
	if
		current == nil
		or model == nil
		or amount == nil
		or progress == nil
		or balance == nil
		or state == nil
		or small == nil
		or fill == nil
		or slot == nil
	then
		return
	end
	local id = inputId(model)
	local capacity = numberAttribute(model, "InputCapacity", 0)
	local stored = numberAttribute(model, "Input", 0)
	local space = math.max(capacity - stored, 0)
	local have = math.floor(ResourceController.Get(id))
	local name = Format.Name(id)

	if shownIcon ~= id then
		shownIcon = id
		for _, child in slot:GetChildren() do
			child:Destroy()
		end
		Theme.ResourceIcon(slot, id)
	end
	amount.Text = `{stored}/{capacity}`
	progress.Set(if capacity > 0 then stored / capacity else 0, `{name} na entrada`, if stored >= capacity then Palette.UiBad else Palette.UiWood)
	balance.Text = `Você tem {have} de {name:lower()}`

	if model:GetAttribute("Full") == true then
		local producerId = model:GetAttribute("Producer")
		local rule = if type(producerId) == "string" then PRODUCERS[producerId] else nil
		local output = if rule ~= nil then Format.Name(rule.ResourceId):lower() else "a produção"
		state.Text = `Saída cheia: recolha {output}`
		state.TextColor3 = Palette.UiBad
	elseif model:GetAttribute("Starved") == true then
		state.Text = `Sem {name:lower()}: abasteça para produzir`
		state.TextColor3 = Palette.UiBad
	else
		state.Text = "Trabalhando"
		state.TextColor3 = Palette.UiGoodDark
	end

	local lot = math.min(SMALL_LOT, space, have)
	local all = math.min(space, have)
	small.Text = `Abastecer {if lot > 0 then lot else SMALL_LOT}`
	fill.Text = if space <= 0 then "Entrada cheia" else "Encher"
	local canSmall = lot > 0 and not pending
	local canFill = all > 0 and not pending
	small.Active = canSmall
	fill.Active = canFill
	if canSmall then
		Theme.Recolor(small, Palette.UiGood, Palette.UiGoodDark)
	else
		Theme.Recolor(small, Palette.UiNeutral, Palette.UiMuted)
	end
	if canFill then
		Theme.Recolor(fill, Palette.UiAccent, Palette.UiAccentDark)
	else
		Theme.Recolor(fill, Palette.UiNeutral, Palette.UiMuted)
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
	currentInput = nil
	pending = false
end

-- Quanto enviar: o desejado limitado ao espaço da entrada e ao saldo (o servidor revalida).
local function amountFor(wanted: number): number
	local model = currentModel
	if model == nil then
		return 0
	end
	local space = math.max(numberAttribute(model, "InputCapacity", 0) - numberAttribute(model, "Input", 0), 0)
	return math.min(wanted, space, math.floor(ResourceController.Get(inputId(model))))
end

local function supply(wanted: number)
	local current = panel
	local site = currentSite
	if current == nil or site == nil or pending then
		return
	end
	local amount = amountFor(wanted)
	if amount < 1 then
		setStatus("Nada para abastecer.", Palette.UiBad)
		current.Shake()
		return
	end
	pending = true
	pendingToken += 1
	local token = pendingToken
	setStatus("Abastecendo...")
	refresh()
	SupplyProducer:FireServer(site, amount)
	task.delay(PENDING_TIMEOUT, function()
		if pending and pendingToken == token then
			pending = false
			refresh()
		end
	end)
end

local function onSupplyResult(siteId: any, result: any, moved: any)
	if type(siteId) ~= "string" or type(result) ~= "string" then
		return
	end
	if siteId ~= currentSite then
		return
	end
	pending = false
	pendingToken += 1
	local part = currentInput
	if result == "Ok" and type(moved) == "number" then
		local model = currentModel
		local name = if model ~= nil then Format.Name(inputId(model)) else "matéria-prima"
		setStatus(`Abasteceu {moved} de {name:lower()}.`, Palette.UiGoodDark)
		if part ~= nil and part.Parent ~= nil then
			Popup.Show(part, `+{moved} {name}`, Palette.UiWood)
			Effects.Burst(part.Position + Vector3.new(0, 2, 0), Palette.Plank, 12, "Chips")
			Effects.Sound(Audio.Collect, part)
		end
	else
		setStatus(MESSAGES[result] or "Não foi possível abastecer.", Palette.UiBad)
		local current = panel
		if current ~= nil then
			current.Shake()
		end
	end
	refresh()
end

local function findProducerModel(part: Instance): Model?
	local node: Instance? = part.Parent
	while node ~= nil do
		if node:IsA("Model") and node:GetAttribute("Producer") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer or prompt.Name ~= "SupplyPrompt" then
		return
	end
	local part = prompt.Parent
	local current = panel
	local siteId = prompt:GetAttribute("SiteId")
	if part == nil or not part:IsA("BasePart") or current == nil or type(siteId) ~= "string" then
		return
	end
	if not World.IsOwn(part) then
		return
	end
	local model = findProducerModel(part)
	if model == nil then
		return
	end
	disconnectAll()
	currentModel = model
	currentSite = siteId
	currentInput = part
	shownIcon = nil
	pending = false
	local producerId = model:GetAttribute("Producer")
	local structure = if type(producerId) == "string" then STRUCTURES[producerId] else nil
	current.Title.Text = `Abastecer {if structure ~= nil then structure.Name else "máquina"}`
	setStatus("Escolha quanto abastecer.")
	for _, attribute in WATCHED do
		table.insert(connections, model:GetAttributeChangedSignal(attribute):Connect(refresh))
	end
	current.Open(part)
	refresh()
end

local function buildPanel()
	local built = Panel.Create({
		Name = "SupplyPanel",
		Title = "Abastecer",
		Width = WIDTH,
		Height = HEIGHT,
		CloseDistance = Gameplay.Production.ReachStuds + 6,
		OnClosed = onClosed,
	})
	local body = built.Body

	-- Cartão: ícone, quantidade atual/capacidade e barra.
	local card = Components.Card(body, 92, 0)
	card.Size = UDim2.new(1, 0, 0, 92)
	local back = Instance.new("Frame")
	back.Name = "IconBack"
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0, 10, 0.5, 0)
	back.Size = UDim2.fromOffset(56, 56)
	back.BackgroundColor3 = Color3.fromRGB(255, 232, 196)
	back.Parent = card
	Theme.Corner(back, UDim.new(0.5, 0))
	local slot = Instance.new("Frame")
	slot.Name = "Slot"
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.fromScale(0.5, 0.5)
	slot.Size = UDim2.fromScale(0.84, 0.84)
	slot.BackgroundTransparency = 1
	slot.Parent = back
	iconSlot = slot

	local caption = Components.Text(card, "Entrada da máquina", Theme.BodyFont, Palette.UiMuted, 14)
	caption.Position = UDim2.fromOffset(78, 8)
	caption.Size = UDim2.new(1, -90, 0, 18)
	caption.TextXAlignment = Enum.TextXAlignment.Left

	local amount = Components.Text(card, "0/0", Theme.TitleFont, Palette.UiText, 30)
	amount.Position = UDim2.fromOffset(78, 26)
	amount.Size = UDim2.new(1, -90, 0, 34)
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amountLabel = amount

	local progress = Components.ProgressBar(card)
	progress.Track.Position = UDim2.new(0, 78, 0, 66)
	progress.Track.Size = UDim2.new(1, -90, 0, 16)
	bar = progress

	local balance = Components.Text(body, "", Theme.BodyFont, Palette.UiText, 16)
	balance.Position = UDim2.fromOffset(0, 98)
	balance.Size = UDim2.new(1, 0, 0, 22)
	balance.TextXAlignment = Enum.TextXAlignment.Left
	balanceLabel = balance

	local state = Components.Text(body, "", Theme.TitleFont, Palette.UiGoodDark, 18)
	state.Position = UDim2.fromOffset(0, 122)
	state.Size = UDim2.new(1, 0, 0, 24)
	state.TextXAlignment = Enum.TextXAlignment.Left
	stateLabel = state

	local small = Theme.Button(body, "Abastecer 10", Palette.UiGood, Palette.UiGoodDark)
	small.Name = "Small"
	small.Position = UDim2.fromOffset(0, 152)
	small.Size = UDim2.new(0.5, -4, 0, 44)
	small.Activated:Connect(function()
		supply(SMALL_LOT)
	end)
	smallButton = small

	local fill = Theme.Button(body, "Encher", Palette.UiAccent, Palette.UiAccentDark)
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(1, 0)
	fill.Position = UDim2.new(1, 0, 0, 152)
	fill.Size = UDim2.new(0.5, -4, 0, 44)
	fill.Activated:Connect(function()
		local model = currentModel
		local capacity = if model ~= nil then numberAttribute(model, "InputCapacity", 0) else 0
		supply(capacity)
	end)
	fillButton = fill

	local status = Components.Text(body, "", Theme.BodyFont, Palette.UiMuted, 14)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.Size = UDim2.new(1, 0, 0, 22)
	statusLabel = status
	panel = built
end

function SupplyController.Init()
	assert(not initialized, "SupplyController.Init chamado mais de uma vez")
	initialized = true
	buildPanel()
	ResourceController.OnChanged(function()
		local current = panel
		if current ~= nil and current.IsOpen() then
			refresh()
		end
	end)
	SupplyResult.OnClientEvent:Connect(onSupplyResult)
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
end

return SupplyController
