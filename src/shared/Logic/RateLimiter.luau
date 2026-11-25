--!strict
--[[
	Limitador por balde de fichas (token bucket). Lógica pura: o tempo é
	recebido como parâmetro, o que permite testar sem o Roblox.
]]

local RateLimiter = {}

export type Limiter = {
	Capacity: number,
	RefillPerSecond: number,
	Tokens: number,
	LastTime: number?,
}

function RateLimiter.new(capacity: number, refillPerSecond: number): Limiter
	assert(capacity > 0, "capacity deve ser maior que zero")
	assert(refillPerSecond >= 0, "refillPerSecond não pode ser negativo")
	return {
		Capacity = capacity,
		RefillPerSecond = refillPerSecond,
		Tokens = capacity,
		LastTime = nil,
	}
end

-- Retorna true se a ação é permitida (consome fichas), false se estiver acima do limite.
function RateLimiter.Consume(limiter: Limiter, now: number, cost: number?): boolean
	local amount = cost or 1

	local lastTime = limiter.LastTime
	if lastTime ~= nil then
		local elapsed = math.max(0, now - lastTime)
		limiter.Tokens = math.min(limiter.Capacity, limiter.Tokens + elapsed * limiter.RefillPerSecond)
	end
	limiter.LastTime = now

	if limiter.Tokens >= amount then
		limiter.Tokens = limiter.Tokens - amount
		return true
	end
	return false
end

return RateLimiter
