--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Validate = require(ReplicatedStorage.Shared.Logic.Validate)

	describe("Validate", function()
		it("IsNumber aceita apenas números finitos dentro da faixa", function()
			expect(Validate.IsNumber(5, 0, 10)).to.equal(true)
			expect(Validate.IsNumber(11, 0, 10)).to.equal(false)
			expect(Validate.IsNumber("5", 0, 10)).to.equal(false)
			expect(Validate.IsNumber(0 / 0, 0, 10)).to.equal(false)
			expect(Validate.IsNumber(math.huge, 0, math.huge)).to.equal(false)
		end)

		it("IsInteger rejeita decimais", function()
			expect(Validate.IsInteger(3, 0, 10)).to.equal(true)
			expect(Validate.IsInteger(3.5, 0, 10)).to.equal(false)
		end)

		it("IsString respeita o tamanho máximo", function()
			expect(Validate.IsString("abc", 3)).to.equal(true)
			expect(Validate.IsString("abcd", 3)).to.equal(false)
			expect(Validate.IsString(1, 3)).to.equal(false)
		end)

		it("IsBoolean aceita apenas booleanos", function()
			expect(Validate.IsBoolean(true)).to.equal(true)
			expect(Validate.IsBoolean(1)).to.equal(false)
		end)
	end)
end
