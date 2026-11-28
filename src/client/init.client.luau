--!strict
--[[
	Bootstrap do cliente. Apenas interface, input e feedback visual.
	Nenhuma decisão de saldo, inventário ou colocação é tomada aqui.
]]

local InputModeController = require(script.Input.InputModeController)
local ResourceController = require(script.Resources.ResourceController)
local BuildController = require(script.Build.BuildController)
local ProductionController = require(script.Production.ProductionController)
local MarketController = require(script.Market.MarketController)
local UpgradeController = require(script.Upgrade.UpgradeController)
local ExpansionController = require(script.Expansion.ExpansionController)
local OnboardingController = require(script.Onboarding.OnboardingController)
local StageController = require(script.Stage.StageController)
local SupplyController = require(script.Supply.SupplyController)
local WorldGuiController = require(script.WorldGui.WorldGuiController)

InputModeController.Init()
ResourceController.Init()
BuildController.Init()
ProductionController.Init()
MarketController.Init()
UpgradeController.Init()
ExpansionController.Init()
StageController.Init()
SupplyController.Init()
WorldGuiController.Init()
OnboardingController.Init()
