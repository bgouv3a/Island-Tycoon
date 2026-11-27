--!strict
--[[
	Orientação inicial: em que etapa o jogador está. Lógica pura, sem serviços do Roblox.
	A etapa é derivada do estado real (saldo, construções e estoque), então não precisa ser salva.

	Ciclo ensinado: coletar → construir → juntar para a Serraria → construir a Serraria →
	esperar a produção → recolher → Done.
	Quem já começou a sessão com uma construção produtiva não vê a orientação.
]]

local Onboarding = {}

export type Step = "Collect" | "Build" | "SaveForProducer" | "BuildProducer" | "WaitProduction" | "Harvest" | "Done"

export type State = {
	Wood: number,
	Buildings: number, -- construções na ilha (qualquer tipo)
	FirstCost: number, -- custo da estrutura mais barata
	Producers: number, -- construções produtivas na ilha
	ProducerCost: number, -- custo da primeira construção produtiva
	Stored: number, -- estoque somado das construções produtivas
	Harvested: boolean, -- já recolheu produção nesta sessão
	StartedWithProducer: boolean, -- a sessão começou com uma construção produtiva
}

local function covers(wood: number, cost: number): boolean
	return wood >= cost -- NaN nunca cobre o custo
end

function Onboarding.Step(state: State): Step
	if state.StartedWithProducer then
		return "Done"
	end
	if state.Buildings <= 0 then
		return if covers(state.Wood, state.FirstCost) then "Build" else "Collect"
	end
	if state.Producers <= 0 then
		return if covers(state.Wood, state.ProducerCost) then "BuildProducer" else "SaveForProducer"
	end
	if state.Harvested then
		return "Done"
	end
	return if state.Stored > 0 then "Harvest" else "WaitProduction"
end

-- Progresso (0 a 1) do saldo rumo a um custo.
function Onboarding.Progress(wood: number, cost: number): number
	if cost <= 0 then
		return 1
	end
	if wood ~= wood then
		return 0
	end
	return math.clamp(wood / cost, 0, 1)
end

return Onboarding
