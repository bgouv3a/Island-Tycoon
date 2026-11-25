--!strict
--[[
	Validadores de argumentos recebidos do cliente. Lógica pura.
	Todo valor vindo de um RemoteEvent/RemoteFunction deve passar por aqui.
]]

local Validate = {}

function Validate.IsNumber(value: any, min: number, max: number): boolean
	return type(value) == "number"
		and value == value -- exclui NaN
		and value > -math.huge
		and value < math.huge
		and value >= min
		and value <= max
end

function Validate.IsInteger(value: any, min: number, max: number): boolean
	return Validate.IsNumber(value, min, max) and math.floor(value :: number) == value
end

function Validate.IsString(value: any, maxLength: number): boolean
	return type(value) == "string" and #value <= maxLength
end

function Validate.IsBoolean(value: any): boolean
	return type(value) == "boolean"
end

return Validate
