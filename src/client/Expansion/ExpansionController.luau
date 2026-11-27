--!strict
--[[
	Expansão da ilha. O prompt "ExpandPrompt" (segurar) envia ExpandIsland(área); quem valida custo,
	alcance e posse é o servidor. Sobre a placa da própria ilha, um rótulo mostra o nome da área e
	o custo (verde se o saldo cobre, vermelho se não).

	ExpandResult: "Ok" (compra aprovada, a área sobe do mar) e depois "Ready" (área pronta).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Audio = require(Shared.Config.Audio)
local Palette = require(Shared.Art.Palette)
local Toast = require(script.Parent.Parent.UI.Toast)
local Effects = require(script.Parent.Parent.UI.Effects)
local Format = require(script.Parent.Parent.UI.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local World = require(script.Parent.Parent.UI.World)
local ResourceController = require(script.Parent.Parent.Resources.ResourceController)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ExpandIsland = Remotes:WaitForChild("ExpandIsland") :: RemoteEvent
local ExpandResult = Remotes:WaitForChild("ExpandResult") :: RemoteEvent

local SCAN_SECONDS = 1
local FOLDER_WAIT = 5

type SignLabel = { Gui: BillboardGui, Text: TextLabel, Board: BasePart, Area: string }

local MESSAGES: { [string]: string } = {
	AlreadyOwned = "Esta área já é sua.",
	OutOfReach = "Chegue mais perto da placa para expandir.",
	NotLoaded = "Seus dados ainda estão carregando. Tente em instantes.",
}

local ExpansionController = {}

local initialized = false
local labels: { [BasePart]: SignLabel } = {}
local expected = 0
local found = 0

local function snapshot(): { [string]: number }
	local balances: { [string]: number } = {}
	for _, id in Format.OrderedIds() do
		balances[id] = ResourceController.Get(id)
	end
	return balances
end

-- Texto rico: nome da área e, em seguida, cada parte do custo colorida pelo saldo.
local function labelText(area: string): string
	local expansion = Economy.Expansions[area]
	if expansion == nil then
		return area
	end
	local good = Palette.UiGoodDark:ToHex()
	local bad = Palette.UiBad:ToHex()
	local parts: { string } = {}
	for _, id in Format.OrderedIds() do
		local need = expansion.Cost[id]
		if need ~= nil and need > 0 then
			local color = if ResourceController.Get(id) >= need then good else bad
			table.insert(parts, `<font color="#{color}">{need} {Format.Name(id)}</font>`)
		end
	end
	return `{expansion.Name}\n{table.concat(parts, "  ")}`
end

local function refreshLabel(entry: SignLabel)
	entry.Text.Text = labelText(entry.Area)
	local holder = entry.Board:FindFirstAncestorWhichIsA("Model")
	-- A placa só aparece enquanto a área não foi liberada (o servidor publica Unlocked no modelo).
	local node: Instance? = entry.Board
	local unlocked = false
	while node ~= nil do
		if node:GetAttribute("Unlocked") == true then
			unlocked = true
			break
		end
		node = node.Parent
	end
	entry.Gui.Enabled = not unlocked and holder ~= nil
end

local function createLabel(board: BasePart, area: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ExpansionLabel"
	gui.Size = UDim2.fromScale(7.5, 2.8)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Adornee = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Palette.UiPanel
	frame.Parent = gui
	Theme.Corner(frame, UDim.new(0.25, 0))
	Theme.Stroke(frame, Palette.UiAccentDark, 3)

	local text = Theme.Label(frame, "", Theme.TitleFont, Palette.UiText)
	text.RichText = true
	text.Position = UDim2.fromScale(0.05, 0.08)
	text.Size = UDim2.fromScale(0.9, 0.84)
	local limit = text:FindFirstChildOfClass("UITextSizeConstraint")
	if limit ~= nil then
		limit.MaxTextSize = 48
	end

	gui.Parent = board
	local entry: SignLabel = { Gui = gui, Text = text, Board = board, Area = area }
	labels[board] = entry
	refreshLabel(entry)
end

-- Procura placas de expansão da própria ilha ainda sem rótulo (podem surgir depois).
local function scan()
	local island = World.FindOwnIsland()
	if island == nil then
		return
	end
	for _, descendant in island:GetDescendants() do
		if descendant:IsA("BasePart") and labels[descendant] == nil then
			local area = descendant:GetAttribute("Area")
			if type(area) == "string" and Economy.Expansions[area] ~= nil then
				createLabel(descendant, area)
				found += 1
			end
		end
	end
end

local function refreshAll()
	for board, entry in labels do
		if board.Parent == nil then
			entry.Gui:Destroy()
			labels[board] = nil
			found -= 1
		else
			refreshLabel(entry)
		end
	end
end

-- Centro da área nova (pasta AreaXX da ilha própria), esperando a replicação se preciso.
local function areaCenter(area: string): Vector3?
	local deadline = os.clock() + FOLDER_WAIT
	while os.clock() < deadline do
		local island = World.FindOwnIsland()
		local folder = if island ~= nil then island:FindFirstChild("Area" .. area) else nil
		if folder ~= nil then
			local center = World.BoundsCenter(folder)
			if center ~= nil then
				return center
			end
		end
		task.wait(0.25)
	end
	return nil
end

local function celebrate(area: string)
	local expansion = Economy.Expansions[area]
	local name = if expansion ~= nil then expansion.Name else area
	Toast.Show(`{name} liberada! Novos pontos de construção`, Palette.UiGood, 5)
	task.spawn(function()
		local center = areaCenter(area)
		if center == nil then
			Effects.Sound(Audio.Build, nil)
			return
		end
		Effects.Burst(center + Vector3.new(0, 4, 0), Palette.UiAccent, 80, "Sparkle")
		Effects.Burst(center + Vector3.new(0, 10, 0), Palette.FlowerPink, 50, "Sparkle")
		Effects.Burst(center + Vector3.new(0, 2, 0), Palette.Sand, 40, "Dust")
		task.delay(0.4, function()
			Effects.Burst(center + Vector3.new(0, 14, 0), Palette.Gold, 70, "Sparkle")
		end)
		-- Som no ponto: peça temporária para o som 3D.
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = center
		holder.Parent = workspace
		Effects.Sound(Audio.Build, holder)
		task.delay(5, function()
			holder:Destroy()
		end)
	end)
end

local function onExpandResult(area: any, result: any)
	if type(area) ~= "string" or type(result) ~= "string" then
		return
	end
	if result == "Ok" then
		Toast.Show("A ilha está crescendo!", Palette.UiAccent, 4)
	elseif result == "Ready" then
		celebrate(area)
	elseif result == "Insufficient" then
		local expansion = Economy.Expansions[area]
		local lack = if expansion ~= nil then Format.Missing(expansion.Cost, snapshot()) else ""
		Toast.Show(if lack ~= "" then `Faltam {lack} para expandir.` else "Recursos insuficientes para expandir.", Palette.UiBad)
	else
		Toast.Show(MESSAGES[result] or "Não foi possível expandir.", Palette.UiBad)
	end
end

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer or prompt.Name ~= "ExpandPrompt" then
		return
	end
	local area = prompt:GetAttribute("Area")
	if type(area) == "string" then
		ExpandIsland:FireServer(area)
	end
end

function ExpansionController.Init()
	assert(not initialized, "ExpansionController.Init chamado mais de uma vez")
	initialized = true

	for _ in Economy.Expansions do
		expected += 1
	end

	ExpandResult.OnClientEvent:Connect(onExpandResult)
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	ResourceController.OnChanged(refreshAll)

	task.spawn(function()
		while true do
			if found < expected then
				scan() -- varredura completa só enquanto faltar placa
			end
			refreshAll()
			task.wait(SCAN_SECONDS)
		end
	end)
end

return ExpansionController
