--==================================================
-- BGMManager.luau
-- BGM専用管理（Server）
--==================================================

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundLibrary = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundLibrary")
)

local BGMManager = {}
BGMManager.__index = BGMManager

--------------------------------------------------

function BGMManager.new()
	local self = setmetatable({}, BGMManager)

	self.CurrentSound = nil
	self.Volume = 0.5

	return self
end

--------------------------------------------------
-- BGM再生
--------------------------------------------------

function BGMManager:Play(trackName: string)
	self:Stop()

	local soundId = SoundLibrary.bgm[trackName]
	if not soundId then
		warn("BGM not found:", trackName)
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = self.Volume
	sound.Looped = true
	sound.Parent = SoundService

	sound:Play()

	self.CurrentSound = sound
end

--------------------------------------------------
-- 停止
--------------------------------------------------

function BGMManager:Stop()
	if self.CurrentSound then
		self.CurrentSound:Stop()
		self.CurrentSound:Destroy()
		self.CurrentSound = nil
	end
end

return BGMManager