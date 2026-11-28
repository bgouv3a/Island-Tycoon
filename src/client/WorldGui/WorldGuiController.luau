--!strict
--[[
	Ajustes locais de interfaces flutuantes criadas pelo servidor. A placa com o nome da ilha
	(BillboardGui "OwnerLabel") nasce com tamanho em studs e fica enorme de perto: aqui ela passa a
	ter tamanho fixo em pixels, alcance limitado e some quando o jogador está colado nela.
	Só visual e local: o servidor não é alterado.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LABEL_NAME = "OwnerLabel"
local LABEL_PIXELS = Vector2.new(220, 40)
local LABEL_MAX_DISTANCE = 150
local HIDE_NEAR_STUDS = 12
local CHECK_SECONDS = 0.25

local WorldGuiController = {}

local initialized = false
local labels: { [BillboardGui]: boolean } = {}

local function adopt(instance: Instance)
	if not instance:IsA("BillboardGui") or instance.Name ~= LABEL_NAME or labels[instance] then
		return
	end
	instance.Size = UDim2.fromOffset(LABEL_PIXELS.X, LABEL_PIXELS.Y)
	instance.MaxDistance = LABEL_MAX_DISTANCE
	labels[instance] = true
	instance.Destroying:Once(function()
		labels[instance] = nil
	end)
end

local function updateVisibility()
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	for gui in labels do
		local adornee = gui.Adornee
		if root ~= nil and root:IsA("BasePart") and adornee ~= nil and adornee:IsA("BasePart") then
			-- Distância horizontal até a placa: de perto ela some em vez de cobrir a tela.
			local offset = (root :: BasePart).Position - (adornee :: BasePart).Position
			gui.Enabled = Vector3.new(offset.X, 0, offset.Z).Magnitude > HIDE_NEAR_STUDS
		else
			gui.Enabled = true
		end
	end
end

local function watch(islands: Instance)
	for _, descendant in islands:GetDescendants() do
		adopt(descendant)
	end
	islands.DescendantAdded:Connect(adopt)
end

function WorldGuiController.Init()
	assert(not initialized, "WorldGuiController.Init chamado mais de uma vez")
	initialized = true

	local existing = Workspace:FindFirstChild("Islands")
	if existing ~= nil then
		watch(existing)
	else
		task.spawn(function()
			watch(Workspace:WaitForChild("Islands"))
		end)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= CHECK_SECONDS then
			elapsed = 0
			updateVisibility()
		end
	end)
end

return WorldGuiController
