local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local httpService = cloneref(game:GetService('HttpService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local sessioninfo = vape.Libraries.sessioninfo
local entitylib = vape.Libraries.entity
local prediction = vape.Libraries.prediction
local targetinfo = vape.Libraries.targetinfo
local tween = vape.Libraries.tween

-- All universal modules (AimAssist, SilentAim, Reach, etc.) are already loaded by universal.lua
-- Only add game-specific modules or logic for Tribes 3v3 below this line

run(function()
	local kills = sessioninfo:AddItem('Kills')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')
end)
