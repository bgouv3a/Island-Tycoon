--!strict
--[[
	Componentes reutilizáveis da interface: texto com limite de tamanho, linha de recurso
	"tenho/preciso", barra de progresso, abas e lista rolável. Só aparência; nenhum estado de jogo.
]]

local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Art.Palette)
local Theme = require(script.Parent.Theme)

local Components = {}

local ICON_BACK = Color3.fromRGB(255, 232, 196)

-- Texto (Theme.Label) com tamanho máximo de fonte próprio: encolhe para caber, nunca estoura.
function Components.Text(parent: Instance, text: string, font: Enum.Font?, color: Color3?, maxSize: number?): TextLabel
	local label = Theme.Label(parent, text, font, color)
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if limit ~= nil then
		limit.MaxTextSize = maxSize or 18
		limit.MinTextSize = 8
	end
	return label
end

-- Ícone de recurso em círculo claro, com tamanho fixo em pixels.
function Components.IconBadge(parent: Instance, resourceId: string, size: number): Frame
	local back = Instance.new("Frame")
	back.Name = "IconBadge"
	back.Size = UDim2.fromOffset(size, size)
	back.BackgroundColor3 = ICON_BACK
	back.Parent = parent
	Theme.Corner(back, UDim.new(0.5, 0))
	Theme.ResourceIcon(back, resourceId).Size = UDim2.fromScale(0.84, 0.84)
	return back
end

export type Chip = { Frame: Frame, Label: TextLabel, Stroke: UIStroke, Set: (have: number, need: number) -> () }

-- Pastilha "ícone + tenho/preciso": verde se cobre, vermelha se não.
function Components.ResourceChip(parent: Instance, resourceId: string, order: number, width: number?, height: number?): Chip
	local w = width or 96
	local h = height or 28
	local frame = Instance.new("Frame")
	frame.Name = resourceId
	frame.LayoutOrder = order
	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.Parent = parent
	Theme.Corner(frame, UDim.new(0.5, 0))
	local stroke = Theme.Stroke(frame, Palette.UiGoodDark, 2)

	local badge = Components.IconBadge(frame, resourceId, h - 6)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 3, 0.5, 0)

	local label = Components.Text(frame, "0/0", Theme.TitleFont, Palette.UiGoodDark, math.floor(h * 0.62))
	label.Position = UDim2.new(0, h, 0, 2)
	label.Size = UDim2.new(1, -(h + 6), 1, -4)
	label.TextXAlignment = Enum.TextXAlignment.Left

	local chip: Chip
	chip = {
		Frame = frame,
		Label = label,
		Stroke = stroke,
		Set = function(have: number, need: number)
			local ok = have >= need
			label.Text = `{math.floor(have)}/{need}`
			label.TextColor3 = if ok then Palette.UiGoodDark else Palette.UiBad
			stroke.Color = if ok then Palette.UiGoodDark else Palette.UiBad
		end,
	}
	return chip
end

-- Linha horizontal (com quebra) que acomoda pastilhas.
function Components.ChipRow(parent: Instance, height: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Chips"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

export type Bar = { Track: Frame, Fill: Frame, Label: TextLabel, Set: (ratio: number, text: string?, color: Color3?) -> () }

-- Barra de progresso com texto central opcional.
function Components.ProgressBar(parent: Instance): Bar
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = Palette.UiNeutral
	track.Parent = parent
	Theme.Corner(track, UDim.new(0.5, 0))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Palette.UiGood
	fill.Parent = track
	Theme.Corner(fill, UDim.new(0.5, 0))

	local label = Components.Text(track, "", Theme.TitleFont, Palette.UiTextLight, 14)
	label.Size = UDim2.fromScale(1, 1)
	label.TextStrokeColor3 = Palette.UiPanelDark
	label.TextStrokeTransparency = 0.3

	return {
		Track = track,
		Fill = fill,
		Label = label,
		Set = function(ratio: number, text: string?, color: Color3?)
			fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
			fill.BackgroundColor3 = color or Palette.UiGood
			label.Text = text or ""
		end,
	}
end

export type Tabs = {
	Pages: { Frame },
	Select: (index: number) -> (),
	Selected: () -> number,
	SetText: (index: number, text: string) -> (),
}

-- Abas: uma barra de botões no topo de `parent` e uma página (Frame) por aba abaixo dela.
function Components.Tabs(parent: Frame, names: { string }, onSelect: ((index: number) -> ())?): Tabs
	local barHeight = 34
	local bar = Instance.new("Frame")
	bar.Name = "TabBar"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, barHeight)
	bar.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local buttons: { TextButton } = {}
	local pages: { Frame } = {}
	local selected = 1

	local function paint()
		for index, button in buttons do
			if index == selected then
				Theme.Recolor(button, Palette.UiAccent, Palette.UiAccentDark)
			else
				Theme.Recolor(button, Palette.UiNeutral, Palette.UiMuted)
			end
			pages[index].Visible = index == selected
		end
	end

	local result: Tabs
	result = {
		Pages = pages,
		Select = function(index: number)
			if buttons[index] == nil then
				return
			end
			local changed = selected ~= index
			selected = index
			paint()
			if changed and onSelect ~= nil then
				onSelect(index)
			end
		end,
		Selected = function(): number
			return selected
		end,
		SetText = function(index: number, text: string)
			local button = buttons[index]
			if button ~= nil then
				button.Text = text
			end
		end,
	}

	for index, name in names do
		local button = Theme.Button(bar, name, Palette.UiNeutral, Palette.UiMuted)
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #names, -6 * (#names - 1) / #names, 1, 0)
		button.Activated:Connect(function()
			result.Select(index)
		end)
		table.insert(buttons, button)

		local page = Instance.new("Frame")
		page.Name = `Page{index}`
		page.BackgroundTransparency = 1
		page.Position = UDim2.fromOffset(0, barHeight + 6)
		page.Size = UDim2.new(1, 0, 1, -(barHeight + 6))
		page.Parent = parent
		table.insert(pages, page)
	end
	paint()
	return result
end

-- Lista vertical rolável: o conteúdo cresce e a barra de rolagem aparece só quando precisa.
function Components.ScrollList(parent: Instance, padding: number?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Palette.UiAccentDark
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	return scroll
end

-- Cartão claro com contorno, usado como linha de lista.
function Components.Card(parent: Instance, height: number, order: number?): Frame
	local card = Instance.new("Frame")
	card.LayoutOrder = order or 0
	card.Size = UDim2.new(1, -8, 0, height)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.Parent = parent
	Theme.Corner(card, UDim.new(0, 12))
	Theme.Stroke(card, Palette.UiNeutral, 2)
	return card
end

return Components
