--!strict
--[[
	Detecta o tipo de entrada atual (toque, teclado/mouse, gamepad) e avisa os interessados.
	A interface deve reagir a esse modo, e não ao dispositivo, para que um futuro
	suporte a console use o mesmo caminho.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputMode = require(ReplicatedStorage:WaitForChild("Shared").Logic.InputMode)

type Mode = InputMode.Mode

local InputModeController = {}

local current: Mode = "Unknown"
local listeners: { (mode: Mode) -> () } = {}
local initialized = false

function InputModeController.GetCurrent(): Mode
	return current
end

function InputModeController.OnChanged(listener: (mode: Mode) -> ())
	table.insert(listeners, listener)
end

local function update(inputType: Enum.UserInputType)
	local mode = InputMode.FromInputTypeName(inputType.Name)
	if mode == "Unknown" or mode == current then
		return
	end
	current = mode
	for _, listener in listeners do
		task.spawn(listener, mode)
	end
end

function InputModeController.Init()
	assert(not initialized, "InputModeController.Init chamado mais de uma vez")
	initialized = true

	UserInputService.LastInputTypeChanged:Connect(update)
	update(UserInputService:GetLastInputType())
end

return InputModeController
