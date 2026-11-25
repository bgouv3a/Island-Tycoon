--!strict
-- selene: allow(undefined_variable)
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local InputMode = require(ReplicatedStorage.Shared.Logic.InputMode)

	describe("InputMode.FromInputTypeName", function()
		it("classifica toque", function()
			expect(InputMode.FromInputTypeName("Touch")).to.equal("Touch")
		end)

		it("classifica teclado e mouse", function()
			expect(InputMode.FromInputTypeName("Keyboard")).to.equal("KeyboardMouse")
			expect(InputMode.FromInputTypeName("MouseButton1")).to.equal("KeyboardMouse")
			expect(InputMode.FromInputTypeName("MouseMovement")).to.equal("KeyboardMouse")
		end)

		it("classifica gamepad (base para console)", function()
			expect(InputMode.FromInputTypeName("Gamepad1")).to.equal("Gamepad")
		end)

		it("retorna Unknown para tipos não tratados", function()
			expect(InputMode.FromInputTypeName("Gyro")).to.equal("Unknown")
		end)
	end)
end
