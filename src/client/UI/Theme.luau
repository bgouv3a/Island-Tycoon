--!strict
--[[
	Tema da interface: fontes, cantos, contornos e botões com resposta ao toque/mouse.
	Só aparência. Cores vêm de Shared/Art/Palette.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Art.Palette)

local Theme = {}

Theme.TitleFont = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.GothamBold
Theme.Palette = Palette

local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Theme.Corner(parent: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, 12)
	corner.Parent = parent
	return corner
end

function Theme.Stroke(parent: GuiObject, color: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Theme.Padding(parent: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = parent
end

-- Escala do objeto (para animações de "pop"). Cria uma se não existir.
function Theme.Scale(object: GuiObject): UIScale
	local existing = object:FindFirstChildOfClass("UIScale")
	if existing ~= nil then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Parent = object
	return scale
end

-- Pulso rápido: cresce e volta. Usado ao ganhar recurso ou confirmar uma ação.
function Theme.Pop(object: GuiObject, amount: number?)
	local scale = Theme.Scale(object)
	scale.Scale = 1 + (amount or 0.15)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- Tremida horizontal curta: usada quando uma ação é recusada.
function Theme.Shake(object: GuiObject)
	local origin = object.Position
	task.spawn(function()
		for _, offset in { 10, -8, 6, -4, 0 } do
			object.Position = origin + UDim2.fromOffset(offset, 0)
			task.wait(0.04)
		end
		object.Position = origin
	end)
end

function Theme.Label(parent: Instance, text: string, font: Enum.Font?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font or Theme.BodyFont
	label.TextColor3 = color or Palette.UiText
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 34
	limit.MinTextSize = 10
	limit.Parent = label
	return label
end

-- Botão arredondado com sombra inferior, que cresce ao passar o mouse e encolhe ao apertar.
function Theme.Button(parent: Instance, text: string, color: Color3, shade: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.Font = Theme.TitleFont
	button.TextColor3 = Palette.UiTextLight
	button.TextScaled = true
	button.Text = text
	button.Parent = parent
	Theme.Corner(button, UDim.new(0.3, 0))
	Theme.Stroke(button, shade, 2.5)

	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 26
	limit.MinTextSize = 10
	limit.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = button

	local scale = Theme.Scale(button)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end)
	return button
end

-- Ícone de madeira desenhado com frames (tora com a ponta à mostra), sem depender de emoji
-- ou de imagem externa. Ocupa todo o `parent` e mantém proporção quadrada.
function Theme.WoodIcon(parent: GuiObject): Frame
	local holder = Instance.new("Frame")
	holder.Name = "WoodIcon"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = parent
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = holder

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.44, 0.52)
	body.Size = UDim2.fromScale(0.7, 0.4)
	body.BackgroundColor3 = Color3.fromRGB(150, 96, 52)
	body.Rotation = -18
	body.Parent = holder
	Theme.Corner(body, UDim.new(0.5, 0))

	local stripe = Instance.new("Frame")
	stripe.Name = "Bark"
	stripe.AnchorPoint = Vector2.new(0.5, 0.5)
	stripe.Position = UDim2.fromScale(0.45, 0.5)
	stripe.Size = UDim2.fromScale(0.55, 0.14)
	stripe.BackgroundColor3 = Color3.fromRGB(120, 74, 40)
	stripe.Parent = body
	Theme.Corner(stripe, UDim.new(0.5, 0))

	local cut = Instance.new("Frame")
	cut.Name = "Cut"
	cut.AnchorPoint = Vector2.new(0.5, 0.5)
	cut.Position = UDim2.fromScale(0.74, 0.43)
	cut.Size = UDim2.fromScale(0.42, 0.42)
	cut.BackgroundColor3 = Color3.fromRGB(240, 200, 140)
	cut.Parent = holder
	Theme.Corner(cut, UDim.new(0.5, 0))
	Theme.Stroke(cut, Color3.fromRGB(150, 96, 52), 2)

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.45, 0.45)
	ring.BackgroundColor3 = Color3.fromRGB(214, 160, 100)
	ring.Parent = cut
	Theme.Corner(ring, UDim.new(0.5, 0))

	return holder
end

-- Ícone de um recurso (Moedas, Madeira, Pedra) desenhado com frames, sem imagem externa.
-- Ocupa todo o `parent` e mantém proporção quadrada.
function Theme.ResourceIcon(parent: GuiObject, resourceId: string): Frame
	if resourceId == "Wood" then
		return Theme.WoodIcon(parent)
	end
	local holder = Instance.new("Frame")
	holder.Name = resourceId .. "Icon"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = parent
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = holder

	local function piece(position: UDim2, size: UDim2, color: Color3, radius: UDim, rotation: number): Frame
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = position
		frame.Size = size
		frame.BackgroundColor3 = color
		frame.Rotation = rotation
		frame.Parent = holder
		Theme.Corner(frame, radius)
		return frame
	end

	if resourceId == "Coins" then
		local disc = piece(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.84, 0.84), Palette.UiCoin, UDim.new(0.5, 0), 0)
		Theme.Stroke(disc, Palette.UiAccentDark, 2)
		local ring = piece(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Palette.Gold, UDim.new(0.5, 0), 0)
		Theme.Stroke(ring, Palette.UiAccentDark, 1.5)
	elseif resourceId == "Stone" then
		local big = piece(UDim2.fromScale(0.42, 0.6), UDim2.fromScale(0.62, 0.5), Palette.Rock, UDim.new(0.3, 0), -8)
		Theme.Stroke(big, Palette.RockDark, 2)
		local small = piece(UDim2.fromScale(0.68, 0.4), UDim2.fromScale(0.38, 0.32), Palette.RockLight, UDim.new(0.3, 0), 12)
		Theme.Stroke(small, Palette.RockDark, 2)
	else
		piece(UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.7, 0.7), Palette.UiNeutral, UDim.new(0.5, 0), 0)
	end
	return holder
end

-- Troca as cores de um botão criado por Theme.Button.
function Theme.Recolor(button: TextButton, color: Color3, shade: Color3)
	button.BackgroundColor3 = color
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil then
		stroke.Color = shade
	end
end

return Theme
