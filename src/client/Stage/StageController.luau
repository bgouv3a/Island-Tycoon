--!strict
--[[
	Painel do estágio da ilha. Mostra os requisitos do próximo estágio (barras), os benefícios e o
	botão "Avançar". O estado vem do servidor (ObjectiveChanged, via ClientState); o avanço é o
	pedido AdvanceStage() e StageResult é a única fonte de verdade para o resultado.
	Abre pelo selo do cartão de objetivos (StageController.Open).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)
local Palette = require(Shared.Art.Palette)
local Theme = require(script.Parent.Parent.UI.Theme)
local Components = require(script.Parent.Parent.UI.Components)
local Effects = require(script.Parent.Parent.UI.Effects)
local Panel = require(script.Parent.Parent.UI.Panel)
local Toast = require(script.Parent.Parent.UI.Toast)
local World = require(script.Parent.Parent.UI.World)
local ClientState = require(script.Parent.Parent.State.ClientState)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AdvanceStage = Remotes:WaitForChild("AdvanceStage") :: RemoteEvent
local StageResult = Remotes:WaitForChild("StageResult") :: RemoteEvent

local WIDTH = 420
local HEIGHT = 390
local PENDING_TIMEOUT = 3

local MESSAGES: { [string]: string } = {
	NotReady = "Ainda faltam requisitos.",
	MaxStage = "A ilha já está no último estágio.",
	NotLoaded = "Seus dados ainda estão carregando. Tente em instantes.",
}

local StageController = {}

local initialized = false
local panel: Panel.Panel? = nil
local subtitle: TextLabel? = nil
local list: ScrollingFrame? = nil
local action: TextButton? = nil
local statusLabel: TextLabel? = nil
local pending = false
local pendingToken = 0
local lastStage = 0

local function setStatus(text: string, color: Color3?)
	local label = statusLabel
	if label ~= nil then
		label.Text = text
		label.TextColor3 = color or Palette.UiMuted
	end
end

local function clearList()
	local scroll = list
	if scroll == nil then
		return
	end
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addHeading(scroll: ScrollingFrame, text: string, order: number)
	local label = Components.Text(scroll, text, Theme.TitleFont, Palette.UiAccentDark, 18)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -8, 0, 22)
	label.TextXAlignment = Enum.TextXAlignment.Left
end

local function refresh()
	local current = panel
	local scroll = list
	local button = action
	local sub = subtitle
	local stage = ClientState.GetStage()
	if current == nil or scroll == nil or button == nil or sub == nil or not current.IsOpen() then
		return
	end
	clearList()
	if stage == nil then
		sub.Text = "Carregando..."
		button.Text = "Avançar"
		button.Active = false
		Theme.Recolor(button, Palette.UiNeutral, Palette.UiMuted)
		return
	end
	local nextName = stage.NextName
	sub.Text = if nextName ~= nil then `{stage.Name}  →  {nextName}` else `{stage.Name} (último estágio)`

	local order = 0
	if nextName ~= nil then
		order += 1
		addHeading(scroll, "Requisitos", order)
		for _, requirement in stage.Requirements do
			order += 1
			local card = Components.Card(scroll, 50, order)
			local text = Components.Text(card, requirement.Text, Theme.BodyFont, Palette.UiText, 16)
			text.Position = UDim2.fromOffset(10, 3)
			text.Size = UDim2.new(1, -20, 0, 22)
			text.TextXAlignment = Enum.TextXAlignment.Left
			local bar = Components.ProgressBar(card)
			bar.Track.Position = UDim2.new(0, 10, 0, 28)
			bar.Track.Size = UDim2.new(1, -20, 0, 16)
			local done = requirement.Current >= requirement.Target
			bar.Set(
				requirement.Current / math.max(requirement.Target, 1),
				`{math.min(requirement.Current, requirement.Target)}/{requirement.Target}`,
				if done then Palette.UiGood else Palette.UiAccent
			)
		end
		if #stage.Benefits > 0 then
			order += 1
			addHeading(scroll, "Benefícios", order)
			for _, benefit in stage.Benefits do
				order += 1
				local line = Components.Text(scroll, `• {benefit}`, Theme.BodyFont, Palette.UiText, 16)
				line.LayoutOrder = order
				line.Size = UDim2.new(1, -8, 0, 22)
				line.TextXAlignment = Enum.TextXAlignment.Left
			end
		end
	else
		order += 1
		local label = Components.Text(scroll, "Sua ilha já alcançou o estágio mais alto por enquanto.", Theme.BodyFont, Palette.UiText, 16)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -8, 0, 44)
		label.TextXAlignment = Enum.TextXAlignment.Left
	end

	if pending then
		button.Text = "Avançando..."
		button.Active = false
		Theme.Recolor(button, Palette.UiNeutral, Palette.UiMuted)
	elseif nextName == nil then
		button.Text = "Estágio máximo"
		button.Active = false
		Theme.Recolor(button, Palette.UiNeutral, Palette.UiMuted)
	elseif stage.Ready then
		button.Text = `Avançar para {nextName}`
		button.Active = true
		Theme.Recolor(button, Palette.UiGood, Palette.UiGoodDark)
	else
		button.Text = "Avançar"
		button.Active = false
		Theme.Recolor(button, Palette.UiNeutral, Palette.UiMuted)
	end
end

local function press()
	local current = panel
	local stage = ClientState.GetStage()
	if current == nil or stage == nil or pending then
		return
	end
	if not stage.Ready or stage.NextName == nil then
		setStatus(MESSAGES.NotReady, Palette.UiBad)
		current.Shake()
		return
	end
	pending = true
	pendingToken += 1
	local token = pendingToken
	setStatus("Avançando...")
	refresh()
	AdvanceStage:FireServer()
	task.delay(PENDING_TIMEOUT, function()
		if pending and pendingToken == token then
			pending = false
			refresh()
		end
	end)
end

local function celebrate(stageNumber: number)
	local name = "Nova ilha"
	local stage = ClientState.GetStage()
	if stage ~= nil then
		name = stage.Name
	end
	Toast.Show(`{name} alcançada!`, Palette.UiGood, 5)
	Effects.Sound(Audio.Build, nil)
	local root = World.Root()
	if root ~= nil then
		Effects.Burst(root.Position + Vector3.new(0, 3, 0), Palette.UiAccent, 40, "Sparkle")
		task.delay(0.25, function()
			Effects.Burst(root.Position + Vector3.new(0, 6, 0), Palette.Gold, 30, "Sparkle")
		end)
	end
	lastStage = stageNumber
end

local function onStageResult(result: any, stageNumber: any)
	if type(result) ~= "string" then
		return
	end
	pending = false
	pendingToken += 1
	if result == "Ok" then
		celebrate(if type(stageNumber) == "number" then stageNumber else lastStage)
		setStatus("Estágio liberado!", Palette.UiGoodDark)
	else
		setStatus(MESSAGES[result] or "Não foi possível avançar.", Palette.UiBad)
		local current = panel
		if current ~= nil then
			current.Shake()
		end
	end
	refresh()
end

local function buildPanel()
	local built = Panel.Create({
		Name = "StagePanel",
		Title = "Estágio da ilha",
		Width = WIDTH,
		Height = HEIGHT,
		CloseDistance = math.huge,
		OnClosed = function()
			pending = false
		end,
	})
	local body = built.Body

	local sub = Components.Text(body, "", Theme.TitleFont, Palette.UiWood, 22)
	sub.Size = UDim2.new(1, 0, 0, 28)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	subtitle = sub

	local holder = Instance.new("Frame")
	holder.Name = "ListHolder"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 34)
	holder.Size = UDim2.new(1, 0, 1, -34 - 50 - 24)
	holder.Parent = body
	list = Components.ScrollList(holder, 6)

	local status = Components.Text(body, "", Theme.BodyFont, Palette.UiMuted, 14)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 0, 1, -48)
	status.Size = UDim2.new(1, 0, 0, 20)
	statusLabel = status

	local button = Theme.Button(body, "Avançar", Palette.UiNeutral, Palette.UiMuted)
	button.Name = "Advance"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.fromScale(0.5, 1)
	button.Size = UDim2.new(1, -20, 0, 42)
	button.Activated:Connect(press)
	action = button
	panel = built
end

-- Abre o painel (sem peça de referência: fecha por X ou Esc).
function StageController.Open()
	local current = panel
	if current == nil then
		return
	end
	setStatus("")
	current.Open(nil)
	refresh()
end

function StageController.Init()
	assert(not initialized, "StageController.Init chamado mais de uma vez")
	initialized = true
	buildPanel()
	ClientState.OnChanged(refresh)
	StageResult.OnClientEvent:Connect(onStageResult)
end

return StageController
