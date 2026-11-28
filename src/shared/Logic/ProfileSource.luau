--!strict
--[[
	Escolha da origem dos perfis. Lógica pura, sem serviços do Roblox.

	O perfil temporário (ProfileStore.Mock, só memória) é usado SOMENTE quando o servidor roda no
	Studio E o atributo de teste é exatamente `true`. Em servidores reais o atributo é ignorado:
	não há como um jogo publicado trocar os perfis reais por temporários, nem o contrário.
]]

local ProfileSource = {}

function ProfileSource.UseMock(isStudio: boolean, attribute: any): boolean
	return isStudio == true and attribute == true
end

return ProfileSource
