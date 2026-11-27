--!strict
--[[
	Mutação transacional: aplica uma função a uma CÓPIA dos dados e devolve o novo estado
	somente se ela terminar sem erro. Lógica pura, sem serviços do Roblox.

	- O estado original nunca é alterado, nem em caso de sucesso nem de erro.
	- Em caso de erro, nenhuma alteração parcial é devolvida.
	- O resultado é uma cópia nova, então referências guardadas pela função de mutação
	  não alteram o estado depois que a mutação termina.
]]

local DeepCopy = require(script.Parent.DeepCopy)

local Transaction = {}

-- Retorna (true, novoEstado) em caso de sucesso, ou (false, erro) se a função de mutação falhar.
function Transaction.Apply(current: any, mutator: (any) -> ()): (boolean, any)
	local working = DeepCopy.Clone(current)
	local ok, err = pcall(mutator, working)
	if not ok then
		return false, err
	end
	return true, DeepCopy.Clone(working)
end

return Transaction
