--!strict
--[[
	Painel pequeno na parte de baixo da tela (mercado, melhoria). Escala para caber em telas
	pequenas, fecha com o botão X, Esc/ButtonB ou ao se afastar da peça de referência.
	Só interface: quem decide é o servidor.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Art.Palette)
local Theme = require(script.Parent.Theme)
local World = require(script.Parent.World)

local CHECK_SECONDS = 0.25
local HEADER = 44

export type Panel = {
	Body: Frame,
	Title: TextLabel,
	Open: (anchor: BasePart?) -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
	Shake: () -> (),
}

export type Config = {
	Name: string,
	Title: string,
	Width: number,
	Height: number,
	CloseDistance: number,
	OnClosed: (() -> ())?,
}

local Panel = {}

function Panel.Create(config: Config): Panel
	local gui = Instance.new("ScreenGui")
	gui.Name = config.Name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -12)
	holder.Size = UDim2.fromOffset(config.Width, config.Height)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Name = "Fit"
	fit.Parent = holder

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Palette.UiPanel
	panel.Parent = holder
	Theme.Corner(panel, UDim.new(0, 18))
	Theme.Stroke(panel, Palette.UiAccentDark, 3)
	Theme.Padding(panel, 12)

	local title = Theme.Label(panel, config.Title, Theme.TitleFont, Palette.UiText)
	title.Name = "Title"
	title.Size = UDim2.new(1, -46, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, HEADER)
	body.Size = UDim2.new(1, 0, 1, -HEADER)
	body.Parent = panel

	local anchor: BasePart? = nil
	local watch: RBXScriptConnection? = nil
	local open = false
	local anchored = false -- sem peça de referência (ex.: painel de estágio), só fecha por X/Esc

	local function updateFit()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local size = camera.ViewportSize
		fit.Scale = math.clamp(math.min(size.X / (config.Width + 24), size.Y / (config.Height + 70)), 0.5, 1)
	end
	updateFit()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit)
	end

	local result: any = {}
	result.Body = body
	result.Title = title

	function result.IsOpen(): boolean
		return open
	end

	function result.Close()
		if not open then
			return
		end
		open = false
		holder.Visible = false
		anchor = nil
		if watch ~= nil then
			watch:Disconnect()
			watch = nil
		end
		local callback = config.OnClosed
		if callback ~= nil then
			callback()
		end
	end

	function result.Open(newAnchor: BasePart?)
		anchor = newAnchor
		anchored = newAnchor ~= nil
		if not open then
			open = true
			holder.Visible = true
			local scale = Theme.Scale(panel)
			scale.Scale = 0.88
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
			local elapsed = 0
			watch = RunService.Heartbeat:Connect(function(dt: number)
				elapsed += dt
				if elapsed < CHECK_SECONDS then
					return
				end
				elapsed = 0
				if not anchored then
					return
				end
				local target = anchor
				local root = World.Root()
				if target == nil or target.Parent == nil then
					result.Close()
				elseif root ~= nil and (root.Position - target.Position).Magnitude > config.CloseDistance then
					result.Close()
				end
			end)
		end
	end

	function result.Shake()
		Theme.Shake(holder)
	end

	local close = Theme.Button(panel, "X", Palette.UiBad, Color3.fromRGB(176, 60, 54))
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(34, 34)
	close.Activated:Connect(result.Close)

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			result.Close()
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return result :: Panel
end

return Panel
