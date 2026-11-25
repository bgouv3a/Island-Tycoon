--!strict
--[[
	Classifica o tipo de entrada usado pelo jogador (toque, teclado/mouse, gamepad).
	Mantém a base para controles de console no futuro: gamepad já é classificado.
	Recebe o nome de Enum.UserInputType, para ser puro e testável.
]]

local InputMode = {}

export type Mode = "Touch" | "KeyboardMouse" | "Gamepad" | "Unknown"

function InputMode.FromInputTypeName(name: string): Mode
	if name == "Touch" then
		return "Touch"
	end
	if
		name == "Keyboard"
		or name == "TextInput"
		or name == "MouseMovement"
		or name == "MouseWheel"
		or string.sub(name, 1, 11) == "MouseButton"
	then
		return "KeyboardMouse"
	end
	if string.sub(name, 1, 7) == "Gamepad" then
		return "Gamepad"
	end
	return "Unknown"
end

return InputMode
