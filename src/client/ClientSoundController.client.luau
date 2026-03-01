--==================================================
-- ClientSoundController
-- UI音 / 接触音（Client専用）
--==================================================

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local SoundLibrary = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("SoundLibrary")
)

--------------------------------------------------
-- 汎用再生関数
--------------------------------------------------

local function playSound(soundId: string, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = SoundService

	sound.Ended:Once(function()
		sound:Destroy()
	end)

	sound:Play()
end

--------------------------------------------------
-- UI音
--------------------------------------------------

function PlayUISound(name: string)
	local soundId = SoundLibrary.ui[name]
	if soundId then
		playSound(soundId)
	end
end

--------------------------------------------------
-- NPC接触音（例）
--------------------------------------------------

function PlayNPCHit()
	local soundId = SoundLibrary.gameplay.npcHit
	if soundId then
		playSound(soundId)
	end
end