--!strict
--[[
	Painel do mercado do píer, com duas abas: "Vender" e "Pedidos". O prompt "SellPrompt" só abre o
	painel. A venda é SellResource(recurso, quantidade) e a entrega é DeliverOrder(vaga, número do
	pedido); quem decide preço, saldo, alcance e recompensa é o servidor. SellResult e OrderResult
	são a única fonte de verdade para as mensagens. A lista de pedidos vem de OrdersChanged.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
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
local ClientState = require(script.Parent.Parent.State.ClientState)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SellResource = Remotes:WaitForChild("SellResource") :: RemoteEvent
local SellResult = Remotes:WaitForChild("SellResult") :: RemoteEvent
local DeliverOrder = Remotes:WaitForChild("DeliverOrder") :: RemoteEvent
local OrderResult = Remotes:WaitForChild("OrderResult") :: RemoteEvent
local RequestOrders = Remotes:WaitForChild("RequestOrders") :: RemoteEvent
local OrdersChanged = Remotes:WaitForChild("OrdersChanged") :: RemoteEvent

local SMALL_LOT = 10
local ROW_HEIGHT = 54
local ORDER_HEIGHT = 96
local WIDTH = 460
local HEIGHT = 380
local PENDING_TIMEOUT = 3
local TAB_SELL = 1
local TAB_ORDERS = 2
local DELIVER_OBJECTIVE = "DeliverOrder"

local MESSAGES: { [string]: string } = {
	Insufficient = "Você não tem essa quantidade para vender.",
	OutOfReach = "Chegue mais perto do balcão.",
	NotLoaded = "Seus dados ainda estão carregando. Tente em instantes.",
	NotSellable = "Este recurso não pode ser vendido.",
	NoIsland = "Você ainda não tem uma ilha.",
}

local ORDER_MESSAGES: { [string]: string } = {
	Stale = "Este pedido mudou. Confira a lista.",
	Insufficient = "Faltam recursos para este pedido.",
	InvalidSlot = "Pedido inválido.",
	OutOfReach = "Chegue mais perto do balcão.",
	NotOwner = "Este balcão não é da sua ilha.",
	NotLoaded = "Seus dados ainda estão carregando. Tente em instantes.",
}

type Row = {
	Id: string,
	Balance: TextLabel,
	Small: TextButton,
	All: TextButton,
}

type OrderEntry = { Slot: number, Number: number, Name: string, Needs: { [string]: number }, Reward: number }

type OrderCard = {
	Entry: OrderEntry,
	Chips: { { Id: string, Need: number, Chip: Components.Chip } },
	Bar: Components.Bar,
	Button: TextButton,
}

local MarketController = {}

local initialized = false
local panel: Panel.Panel? = nil
local tabs: Components.Tabs? = nil
local status: TextLabel? = nil
local rows: { Row } = {}
local counter: BasePart? = nil
local pendingToken = 0
local pending = false
local ordersScroll: ScrollingFrame? = nil
local orderEntries: { OrderEntry } = {}
local orderBonus = 0
local orderCards: { OrderCard } = {}
local ordersLoaded = false

local function setStatus(text: string, color: Color3?)
	local label = status
	if label ~= nil then
		label.Text = text
		label.TextColor3 = color or Palette.UiMuted
	end
end

local function lotFor(resourceId: string, wanted: number): number
	return math.min(math.floor(ResourceController.Get(resourceId)), wanted, Economy.Market.MaxLot)
end

local function canDeliver(card: OrderCard): boolean
	for _, item in card.Chips do
		if ResourceController.Get(item.Id) < item.Need then
			return false
		end
	end
	return true
end

local function refreshOrders()
	local ready = 0
	for _, card in orderCards do
		local have = 0
		local total = 0
		for _, item in card.Chips do
			local owned = math.floor(ResourceController.Get(item.Id))
			item.Chip.Set(owned, item.Need)
			have += math.min(owned, item.Need)
			total += item.Need
		end
		local ok = canDeliver(card)
		card.Bar.Set(if total > 0 then have / total else 0, `{have}/{total}`, if ok then Palette.UiGood else Palette.UiAccent)
		card.Button.Active = ok and not pending
		if ok then
			ready += 1
		end
		if ok and not pending then
			Theme.Recolor(card.Button, Palette.UiGood, Palette.UiGoodDark)
		else
			Theme.Recolor(card.Button, Palette.UiNeutral, Palette.UiMuted)
		end
	end
	local current = tabs
	if current ~= nil then
		current.SetText(TAB_ORDERS, if ready > 0 then `Pedidos ({ready})` else "Pedidos")
	end
end

local function refreshSell()
	for _, row in rows do
		local balance = math.floor(ResourceController.Get(row.Id))
		row.Balance.Text = `Tenho {balance} · {Economy.Market.Prices[row.Id]} moeda/un.`
		local can = balance > 0 and not pending
		row.Small.Text = `Vender {math.min(SMALL_LOT, math.max(balance, 1))}`
		row.Small.Active = can
		row.All.Active = can
		if can then
			Theme.Recolor(row.Small, Palette.UiGood, Palette.UiGoodDark)
			Theme.Recolor(row.All, Palette.UiAccent, Palette.UiAccentDark)
		else
			Theme.Recolor(row.Small, Palette.UiNeutral, Palette.UiMuted)
			Theme.Recolor(row.All, Palette.UiNeutral, Palette.UiMuted)
		end
	end
end

local function refresh()
	refreshSell()
	refreshOrders()
end

local function release(token: number)
	task.delay(PENDING_TIMEOUT, function()
		-- Segurança: se a resposta não vier, libera os botões.
		if pending and pendingToken == token then
			pending = false
			refresh()
		end
	end)
end

local function sell(resourceId: string, wanted: number)
	local current = panel
	if current == nil or pending then
		return
	end
	local amount = lotFor(resourceId, wanted)
	if amount < 1 then
		setStatus("Nada para vender.", Palette.UiBad)
		return
	end
	pending = true
	pendingToken += 1
	refresh()
	SellResource:FireServer(resourceId, amount)
	release(pendingToken)
end

local function deliver(entry: OrderEntry)
	local current = panel
	if current == nil or pending then
		return
	end
	pending = true
	pendingToken += 1
	setStatus("Entregando...")
	refresh()
	DeliverOrder:FireServer(entry.Slot, entry.Number)
	release(pendingToken)
end

-- Aba Vender -----------------------------------------------------------------------------------

local function buildRow(parent: ScrollingFrame, resourceId: string, index: number): Row
	local frame = Components.Card(parent, ROW_HEIGHT - 6, index)

	local icon = Components.IconBadge(frame, resourceId, 38)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 6, 0.5, 0)

	-- Colunas: ícone (fixo) | texto (flexível) | botões (largura própria). Sem sobreposição.
	local text = Instance.new("Frame")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(52, 0)
	text.Size = UDim2.new(1, -52 - 210, 1, 0)
	text.Parent = frame

	local name = Components.Text(text, Format.Name(resourceId), Theme.TitleFont, Palette.UiText, 20)
	name.Position = UDim2.fromOffset(0, 4)
	name.Size = UDim2.new(1, 0, 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local balance = Components.Text(text, "", Theme.BodyFont, Palette.UiMuted, 14)
	balance.Position = UDim2.fromOffset(0, 26)
	balance.Size = UDim2.new(1, 0, 0, 18)
	balance.TextXAlignment = Enum.TextXAlignment.Left

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(1, 0.5)
	buttons.Position = UDim2.new(1, -6, 0.5, 0)
	buttons.Size = UDim2.fromOffset(200, 38)
	buttons.Parent = frame

	local small = Theme.Button(buttons, "Vender 10", Palette.UiGood, Palette.UiGoodDark)
	small.Name = "Small"
	small.Size = UDim2.new(0.5, -3, 1, 0)
	small.Activated:Connect(function()
		sell(resourceId, SMALL_LOT)
	end)

	local all = Theme.Button(buttons, "Vender tudo", Palette.UiAccent, Palette.UiAccentDark)
	all.Name = "All"
	all.AnchorPoint = Vector2.new(1, 0)
	all.Position = UDim2.fromScale(1, 0)
	all.Size = UDim2.new(0.5, -3, 1, 0)
	all.Activated:Connect(function()
		sell(resourceId, Economy.Market.MaxLot)
	end)

	return { Id = resourceId, Balance = balance, Small = small, All = all }
end

-- Aba Pedidos ----------------------------------------------------------------------------------

local function clearOrders()
	local scroll = ordersScroll
	if scroll ~= nil then
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	table.clear(orderCards)
end

local function sortedNeeds(needs: { [string]: number }): { string }
	local ids: { string } = {}
	for _, id in Format.OrderedIds() do
		if needs[id] ~= nil then
			table.insert(ids, id)
		end
	end
	return ids
end

local function buildOrderCard(scroll: ScrollingFrame, entry: OrderEntry, index: number)
	local card = Components.Card(scroll, ORDER_HEIGHT, index)

	-- Coluna direita (largura própria): recompensa e botão. Coluna esquerda: nome, recursos, progresso.
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -8, 0, 8)
	right.Size = UDim2.new(0, 104, 1, -16)
	right.Parent = card

	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromOffset(10, 8)
	left.Size = UDim2.new(1, -10 - 8 - 104 - 8, 1, -16)
	left.Parent = card

	local name = Components.Text(left, entry.Name, Theme.TitleFont, Palette.UiText, 18)
	name.Size = UDim2.new(1, 0, 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local chipRow = Components.ChipRow(left, 28)
	chipRow.Position = UDim2.fromOffset(0, 26)
	local items: { { Id: string, Need: number, Chip: Components.Chip } } = {}
	for order, id in sortedNeeds(entry.Needs) do
		local chip = Components.ResourceChip(chipRow, id, order, 88, 26)
		table.insert(items, { Id = id, Need = entry.Needs[id], Chip = chip })
	end

	local bar = Components.ProgressBar(left)
	bar.Track.Position = UDim2.new(0, 0, 1, -16)
	bar.Track.Size = UDim2.new(1, 0, 0, 14)

	local reward = Components.Text(right, `+{entry.Reward}`, Theme.TitleFont, Palette.UiCoin, 24)
	reward.Position = UDim2.fromOffset(26, 0)
	reward.Size = UDim2.new(1, -26, 0, 26)
	reward.TextXAlignment = Enum.TextXAlignment.Left
	local coin = Components.IconBadge(right, "Coins", 22)
	coin.Position = UDim2.fromOffset(0, 2)

	if orderBonus > 0 then
		local bonus = Components.Text(right, `bônus +{math.floor(orderBonus * 100 + 0.5)}%`, Theme.BodyFont, Palette.UiGoodDark, 13)
		bonus.Position = UDim2.fromOffset(0, 26)
		bonus.Size = UDim2.new(1, 0, 0, 16)
		bonus.TextXAlignment = Enum.TextXAlignment.Left
	end

	local button = Theme.Button(right, "Entregar", Palette.UiNeutral, Palette.UiMuted)
	button.Name = "Deliver"
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.fromScale(0, 1)
	button.Size = UDim2.new(1, 0, 0, 36)
	button.Activated:Connect(function()
		deliver(entry)
	end)

	table.insert(orderCards, { Entry = entry, Chips = items, Bar = bar, Button = button })
end

local function rebuildOrders()
	local scroll = ordersScroll
	if scroll == nil then
		return
	end
	clearOrders()
	for index, entry in orderEntries do
		buildOrderCard(scroll, entry, index)
	end
	if #orderEntries == 0 then
		local empty = Components.Text(scroll, "Nenhum pedido no momento.", Theme.BodyFont, Palette.UiMuted, 16)
		empty.Size = UDim2.new(1, -8, 0, 30)
	end
	refreshOrders()
end

local function onOrdersChanged(state: any)
	if type(state) ~= "table" or type(state.Orders) ~= "table" then
		return
	end
	local list: { OrderEntry } = {}
	for _, raw in state.Orders do
		if
			type(raw) == "table"
			and type(raw.Slot) == "number"
			and type(raw.Number) == "number"
			and type(raw.Name) == "string"
			and type(raw.Needs) == "table"
			and type(raw.Reward) == "number"
		then
			local needs: { [string]: number } = {}
			for id, amount in raw.Needs do
				if type(id) == "string" and type(amount) == "number" then
					needs[id] = amount
				end
			end
			table.insert(list, { Slot = raw.Slot, Number = raw.Number, Name = raw.Name, Needs = needs, Reward = raw.Reward })
		end
	end
	table.sort(list, function(a: OrderEntry, b: OrderEntry): boolean
		return a.Slot < b.Slot
	end)
	orderEntries = list
	orderBonus = if type(state.Bonus) == "number" then state.Bonus else 0
	ordersLoaded = true
	rebuildOrders()
end

-- Resultados -----------------------------------------------------------------------------------

local function onSellResult(resourceId: any, result: any, amountSold: any, coinsEarned: any)
	if type(resourceId) ~= "string" or type(result) ~= "string" then
		return
	end
	pending = false
	pendingToken += 1
	local current = panel
	if result == "Ok" and type(amountSold) == "number" and type(coinsEarned) == "number" then
		setStatus(`Vendeu {amountSold} {Format.Name(resourceId)} por {coinsEarned} moedas.`, Palette.UiGoodDark)
		local part = counter
		if part ~= nil and part.Parent ~= nil then
			Popup.Show(part, `+{coinsEarned} moedas`, Palette.UiCoin)
			Effects.Burst(part.Position + Vector3.new(0, 4, 0), Palette.Gold, 16, "Sparkle")
			Effects.Sound(Audio.Collect, part)
		else
			Effects.Sound(Audio.Collect, nil)
		end
	else
		setStatus(MESSAGES[result] or "Não foi possível vender.", Palette.UiBad)
		if current ~= nil then
			current.Shake()
		end
	end
	refresh()
end

local function onOrderResult(_slot: any, result: any, reward: any)
	if type(result) ~= "string" then
		return
	end
	pending = false
	pendingToken += 1
	local current = panel
	if result == "Ok" and type(reward) == "number" then
		setStatus(`Pedido entregue! +{reward} moedas.`, Palette.UiGoodDark)
		local part = counter
		if part ~= nil and part.Parent ~= nil then
			Popup.Show(part, `Pedido entregue! +{reward}`, Palette.UiCoin)
			Effects.Burst(part.Position + Vector3.new(0, 4, 0), Palette.Gold, 24, "Sparkle")
			Effects.Sound(Audio.Build, part)
		else
			Effects.Sound(Audio.Build, nil)
		end
	else
		setStatus(ORDER_MESSAGES[result] or "Não foi possível entregar.", Palette.UiBad)
		if current ~= nil then
			current.Shake()
		end
	end
	refresh()
end

local function buildPanel()
	local ids: { string } = {}
	for _, id in Format.OrderedIds() do
		if Economy.Market.Prices[id] ~= nil then
			table.insert(ids, id)
		end
	end
	local built = Panel.Create({
		Name = "MarketPanel",
		Title = "Mercado do píer",
		Width = WIDTH,
		Height = HEIGHT,
		CloseDistance = Economy.Market.ReachStuds + 6,
	})
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 1, -26)
	content.Parent = built.Body

	local created = Components.Tabs(content, { "Vender", "Pedidos" }, nil)
	tabs = created

	local sellScroll = Components.ScrollList(created.Pages[TAB_SELL], 6)
	for index, id in ids do
		table.insert(rows, buildRow(sellScroll, id, index))
	end
	ordersScroll = Components.ScrollList(created.Pages[TAB_ORDERS], 6)

	local label = Components.Text(built.Body, "", Theme.BodyFont, Palette.UiMuted, 14)
	label.Name = "Status"
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.fromScale(0, 1)
	label.Size = UDim2.new(1, 0, 0, 22)
	status = label
	panel = built
end

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer or prompt.Name ~= "SellPrompt" then
		return
	end
	local part = prompt.Parent
	local current = panel
	if part == nil or not part:IsA("BasePart") or current == nil then
		return
	end
	if not World.IsOwn(part) then
		return
	end
	counter = part
	setStatus("")
	local tab = tabs
	if tab ~= nil and ClientState.ObjectiveId() == DELIVER_OBJECTIVE then
		tab.Select(TAB_ORDERS)
	end
	if not ordersLoaded then
		RequestOrders:FireServer()
	end
	current.Open(part)
	refresh()
end

function MarketController.Init()
	assert(not initialized, "MarketController.Init chamado mais de uma vez")
	initialized = true

	buildPanel()
	ResourceController.OnChanged(function()
		local current = panel
		if current ~= nil and current.IsOpen() then
			refresh()
		end
	end)
	SellResult.OnClientEvent:Connect(onSellResult)
	OrderResult.OnClientEvent:Connect(onOrderResult)
	OrdersChanged.OnClientEvent:Connect(onOrdersChanged)
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	RequestOrders:FireServer()
end

return MarketController
