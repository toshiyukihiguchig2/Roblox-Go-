-- ServerScriptService/Managers/RunManager.lua
--!strict

local RunManager = {}
RunManager.__index = RunManager

local Players = game:GetService("Players")

local activeRuns: {[Player]: number} = {}

function RunManager:StartRun(player: Player)
	if activeRuns[player] then return end

	activeRuns[player] = os.clock()
end

function RunManager:FinishRun(player: Player): number?
	local startTime = activeRuns[player]
	if not startTime then return nil end

	local totalTime = os.clock() - startTime
	activeRuns[player] = nil

	return totalTime
end

Players.PlayerRemoving:Connect(function(player)
	activeRuns[player] = nil
end)

return RunManager