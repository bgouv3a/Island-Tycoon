--!strict
--[[
	Estado do servidor que vários controllers do cliente precisam ler: estágio da ilha e objetivo atual.
	Alimentado por OnboardingController a partir de ObjectiveChanged. Só leitura para os demais.
]]

export type Requirement = { Text: string, Current: number, Target: number }
export type Stage = {
	Current: number,
	Name: string,
	NextName: string?,
	Requirements: { Requirement },
	Benefits: { string },
	Ready: boolean,
}

local ClientState = {}

local stage: Stage? = nil
local objectiveId: string? = nil
local changed = Instance.new("BindableEvent")

local function parseStage(raw: any): Stage?
	if type(raw) ~= "table" or type(raw.Current) ~= "number" or type(raw.Name) ~= "string" then
		return nil
	end
	local requirements: { Requirement } = {}
	if type(raw.Requirements) == "table" then
		for _, entry in raw.Requirements do
			if type(entry) == "table" and type(entry.Text) == "string" and type(entry.Target) == "number" then
				table.insert(requirements, {
					Text = entry.Text,
					Current = if type(entry.Current) == "number" then entry.Current else 0,
					Target = entry.Target,
				})
			end
		end
	end
	local benefits: { string } = {}
	if type(raw.Benefits) == "table" then
		for _, text in raw.Benefits do
			if type(text) == "string" then
				table.insert(benefits, text)
			end
		end
	end
	return {
		Current = raw.Current,
		Name = raw.Name,
		NextName = if type(raw.NextName) == "string" then raw.NextName else nil,
		Requirements = requirements,
		Benefits = benefits,
		Ready = raw.Ready == true,
	}
end

-- Recebe o estado bruto de ObjectiveChanged.
function ClientState.SetFromObjective(raw: any)
	if type(raw) ~= "table" then
		return
	end
	local parsed = parseStage(raw.Stage)
	if parsed ~= nil then
		stage = parsed
	end
	objectiveId = if type(raw.Id) == "string" then raw.Id else nil
	changed:Fire()
end

-- Estágio completo (nil até a primeira mensagem do servidor).
function ClientState.GetStage(): Stage?
	return stage
end

-- Número do estágio atual (1 enquanto o servidor não respondeu).
function ClientState.StageIndex(): number
	local current = stage
	return if current ~= nil then current.Current else 1
end

-- Identificador do objetivo atual (nil se concluídos ou desconhecido).
function ClientState.ObjectiveId(): string?
	return objectiveId
end

function ClientState.OnChanged(callback: () -> ()): RBXScriptConnection
	return changed.Event:Connect(callback)
end

return ClientState
