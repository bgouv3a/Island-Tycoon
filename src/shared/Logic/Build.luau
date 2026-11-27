--!strict
--[[
	Regras de construção: decide se uma compra pode acontecer e, se puder, aplica a ocupação
	do ponto e o desconto de madeira. Lógica pura, sem serviços do Roblox.

	- Recebe a cópia de trabalho dos dados (DataService.Mutate). Em caso de recusa, nada é alterado.
	- Ocupação e saldo são verificados e alterados na mesma chamada: duas compras do mesmo
	  ponto nunca passam, mesmo que cheguem juntas.
	- Ordem de verificação: ilha → dono → ponto → área liberada → estrutura → alcance → ocupação →
	  limite por ilha → saldo.
]]

local ResourceLedger = require(script.Parent.ResourceLedger)

local Build = {}

export type Structure = { Name: string, Cost: number, MaxPerIsland: number? }

-- Catálogo: pontos válidos (chave = identificador do ponto) e estruturas válidas.
export type Catalog = {
	Sites: { [string]: any },
	Structures: { [string]: Structure },
	CurrencyId: string,
	SiteAreas: { [string]: string }?, -- ponto → expansão que o libera (pontos sem área são livres)
}

export type Request = {
	OwnerSlot: number?, -- ilha do jogador (nil se não tiver ilha)
	TargetSlot: number, -- ilha onde fica o ponto
	SiteId: string,
	StructureId: string,
	Distance: number, -- distância entre o jogador e o ponto, em studs
	Reach: number, -- alcance máximo, em studs
}

-- Construções do jogador: ponto → estrutura. Os pontos são locais à ilha do jogador.
export type Buildings = { [string]: string }

export type Result =
	"Ok"
	| "NoIsland"
	| "NotOwner"
	| "UnknownSite"
	| "UnknownStructure"
	| "OutOfReach"
	| "Occupied"
	| "Locked"
	| "Limit"
	| "Insufficient"
	| "Invalid"

-- Verifica a compra e, se for válida, registra a construção e desconta a madeira.
-- Qualquer recusa retorna antes de alterar `data`.
function Build.Apply(
	data: { Resources: { [string]: number }, Buildings: Buildings, Expansions: { [string]: boolean }? },
	request: Request,
	catalog: Catalog
): Result
	if request.OwnerSlot == nil then
		return "NoIsland"
	end
	if request.OwnerSlot ~= request.TargetSlot then
		return "NotOwner"
	end
	if catalog.Sites[request.SiteId] == nil then
		return "UnknownSite"
	end
	local area = if catalog.SiteAreas ~= nil then catalog.SiteAreas[request.SiteId] else nil
	if area ~= nil then
		local expansions = data.Expansions
		if type(expansions) ~= "table" or expansions[area] ~= true then
			return "Locked"
		end
	end
	local structure = catalog.Structures[request.StructureId]
	if structure == nil then
		return "UnknownStructure"
	end
	-- A forma `not (a <= b)` também rejeita NaN.
	if not (request.Distance <= request.Reach) then
		return "OutOfReach"
	end
	local buildings = data.Buildings
	if type(buildings) ~= "table" then
		return "Invalid"
	end
	if buildings[request.SiteId] ~= nil then
		return "Occupied"
	end
	if structure.MaxPerIsland ~= nil then
		local owned = 0
		for _, structureId in buildings do
			if structureId == request.StructureId then
				owned += 1
			end
		end
		if owned >= structure.MaxPerIsland then
			return "Limit"
		end
	end
	if not ResourceLedger.Spend(data.Resources, catalog.CurrencyId, structure.Cost) then
		return "Insufficient"
	end
	buildings[request.SiteId] = request.StructureId
	return "Ok"
end

-- Devolve somente as construções válidas de um valor vindo do perfil salvo.
-- Pontos ou estruturas desconhecidos, e valores que não são texto, são descartados.
function Build.Restore(saved: any, catalog: Catalog): Buildings
	local result: Buildings = {}
	if type(saved) ~= "table" then
		return result
	end
	for siteId, structureId in saved do
		if
			type(siteId) == "string"
			and type(structureId) == "string"
			and catalog.Sites[siteId] ~= nil
			and catalog.Structures[structureId] ~= nil
		then
			result[siteId] = structureId
		end
	end
	return result
end

return Build
