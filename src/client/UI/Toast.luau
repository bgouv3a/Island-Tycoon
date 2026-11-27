--!strict
--[[
	Avisos curtos no topo da tela ("A ilha está crescendo!", "Objetivo concluído!").
	Só visual. Um aviso com o mesmo texto de outro ainda visível não é repetido.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Art.Palette)
local Theme = require(script.Parent.Theme)

local MAX_VISIBLE = 3

local Toast = {}

local container: Frame? = nil
local visible: { [string]: Frame } = {}

local function ensureContainer(): Frame
	local existing = container
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Toasts"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	local holder = Instance.new("Frame")
	holder.Name = "List"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 10)
	holder.Size = UDim2.fromScale(0.8, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(440, math.huge)
	limit.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = holder

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	container = holder
	return holder
end

local order = 0

function Toast.Show(text: string, color: Color3?, seconds: number?)
	if visible[text] ~= nil then
		return
	end
	local holder = ensureContainer()
	local old = holder:GetChildren()
	local count = 0
	for _, child in old do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count >= MAX_VISIBLE then
		for _, child in old do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end

	order += 1
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 44)
	frame.BackgroundColor3 = Palette.UiPanelDark
	frame.BackgroundTransparency = 0.08
	frame.Parent = holder
	Theme.Corner(frame, UDim.new(0.5, 0))
	Theme.Stroke(frame, color or Palette.UiAccent, 3)

	local label = Theme.Label(frame, text, Theme.TitleFont, color or Palette.UiTextLight)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Palette.UiPanelDark
	visible[text] = frame
	Theme.Pop(frame, 0.12)

	task.delay(seconds or 3.5, function()
		if visible[text] == frame then
			visible[text] = nil
		end
		if frame.Parent == nil then
			return
		end
		TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.45, function()
			frame:Destroy()
		end)
	end)
	frame.Destroying:Once(function()
		if visible[text] == frame then
			visible[text] = nil
		end
	end)
end

return Toast
