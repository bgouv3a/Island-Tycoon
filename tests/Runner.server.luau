--!strict
--[[
	Executa os testes de lógica pura (TestEZ) ao iniciar o projeto de teste no Studio.
	Use `rojo serve test.project.json` e veja o resultado na saída do Studio.
	Este arquivo não existe no build de produção (default.project.json).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage:WaitForChild("DevPackages"):WaitForChild("TestEZ"))

TestEZ.TestBootstrap:run({ script.Parent.Logic })
