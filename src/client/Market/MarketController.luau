--!strict
--[[
	Painel de venda do mercado do píer. O prompt "SellPrompt" só abre o painel; a venda é o
	pedido SellResource(recurso, quantidade) e quem decide preço, saldo e alcance é o servidor.
	O resultado (SellResult) é a única fonte de verdade para a mensagem exibida.
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
local Effects = require(script.Parent.Parent.UI.Effects)
local Format = require(script.Parent.Parent.UI.Format)
local Panel = require(script.Parent.Parent.UI.Panel)
local World = require(script.Parent.Parent.UI.World)
local ResourceController = require(script.Parent.Parent.Resources.ResourceController)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SellResource = Remotes:WaitForChild("SellResource") :: RemoteEvent
local SellResult = Remotes:WaitForChild("SellResult") :: RemoteEvent

local SMALL_LOT = 10
local ROW_HEIGHT = 56
local WIDTH = 430
local PENDING_TIMEOUT = 3

local MESSAGES: { [string]: string } = {
	Insufficient = "Você não tem essa quantidade para vender.",
	OutOfReach = "Chegue mais perto do balcão.",
	NotLoaded = "Seus dados ainda estão carregando. Tente em instantes.",
	NotSellable = "Este recurso não pode ser vendido.",
	NoIsland = "Você ainda não tem uma ilha.",
}

type Row = {
	Id: string,
	Balance: TextLabel,
	Small: TextButton,
	All: TextButton,
}

local MarketController = {}

local initialized = false
local panel: Panel.Panel? = nil
local status: TextLabel? = nil
local rows: { Row } = {}
local counter: BasePart? = nil
local pendingToken = 0
local pending = false

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

local function refresh()
	for _, row in rows do
		local balance = math.floor(ResourceController.Get(row.Id))
		row.Balance.Text = `Tenho {balance} · {Economy.Market.Prices[row.Id]} moeda por un.`
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
	local token = pendingToken
	refresh()
	SellResource:FireServer(resourceId, amount)
	-- Segurança: se a resposta não vier, libera os botões.
	task.delay(PENDING_TIMEOUT, function()
		if pending and pendingToken == token then
			pending = false
			refresh()
		end
	end)
end

local function buildRow(body: Frame, resourceId: string, index: number): Row
	local frame = Instance.new("Frame")
	frame.Name = resourceId
	frame.Position = UDim2.fromOffset(0, (index - 1) * ROW_HEIGHT)
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 6)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.Parent = body
	Theme.Corner(frame, UDim.new(0, 12))
	Theme.Stroke(frame, Palette.UiNeutral, 2)

	local iconBack = Instance.new("Frame")
	iconBack.AnchorPoint = Vector2.new(0, 0.5)
	iconBack.Position = UDim2.new(0, 6, 0.5, 0)
	iconBack.Size = UDim2.fromOffset(38, 38)
	iconBack.BackgroundColor3 = Color3.fromRGB(255, 232, 196)
	iconBack.Parent = frame
	Theme.Corner(iconBack, UDim.new(0.5, 0))
	Theme.ResourceIcon(iconBack, resourceId).Size = UDim2.fromScale(0.84, 0.84)

	local name = Theme.Label(frame, Format.Name(resourceId), Theme.TitleFont, Palette.UiText)
	name.Position = UDim2.fromOffset(52, 3)
	name.Size = UDim2.fromOffset(150, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local balance = Theme.Label(frame, "", Theme.BodyFont, Palette.UiMuted)
	balance.Position = UDim2.fromOffset(52, 26)
	balance.Size = UDim2.fromOffset(160, 18)
	balance.TextXAlignment = Enum.TextXAlignment.Left

	local small = Theme.Button(frame, "Vender 10", Palette.UiGood, Palette.UiGoodDark)
	small.Name = "Small"
	small.AnchorPoint = Vector2.new(1, 0.5)
	small.Position = UDim2.new(1, -118, 0.5, 0)
	small.Size = UDim2.fromOffset(100, 38)
	small.Activated:Connect(function()
		sell(resourceId, SMALL_LOT)
	end)

	local all = Theme.Button(frame, "Vender tudo", Palette.UiAccent, Palette.UiAccentDark)
	all.Name = "All"
	all.AnchorPoint = Vector2.new(1, 0.5)
	all.Position = UDim2.new(1, -8, 0.5, 0)
	all.Size = UDim2.fromOffset(104, 38)
	all.Activated:Connect(function()
		sell(resourceId, Economy.Market.MaxLot)
	end)

	return { Id = resourceId, Balance = balance, Small = small, All = all }
end

local function buildPanel()
	local ids: { string } = {}
	for _, id in Format.OrderedIds() do
		if Economy.Market.Prices[id] ~= nil then
			table.insert(ids, id)
		end
	end
	local height = 44 + #ids * ROW_HEIGHT + 30 + 24
	local built = Panel.Create({
		Name = "MarketPanel",
		Title = "Mercado do píer",
		Width = WIDTH,
		Height = height,
		CloseDistance = Economy.Market.ReachStuds + 6,
	})
	for index, id in ids do
		table.insert(rows, buildRow(built.Body, id, index))
	end
	local label = Theme.Label(built.Body, "", Theme.BodyFont, Palette.UiMuted)
	label.Name = "Status"
	label.Position = UDim2.fromOffset(0, #ids * ROW_HEIGHT + 2)
	label.Size = UDim2.new(1, 0, 0, 24)
	status = label
	panel = built
end

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
	setStatus("Escolha quanto vender.")
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
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
end

return MarketController
