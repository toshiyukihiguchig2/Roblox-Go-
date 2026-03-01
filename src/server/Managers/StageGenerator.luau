--==================================================
-- StageGenerator (ModuleScript)
-- Easyステージの自動生成管理
--==================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StageGenerator = {}
StageGenerator.__index = StageGenerator

--------------------------------------------------
-- 生成設定
--------------------------------------------------

local SEGMENT_COUNT = 19
local MIN_GAP = 4
local MAX_GAP = 6

--------------------------------------------------
-- コンストラクタ
--------------------------------------------------

function StageGenerator.new(stageFolder: Folder, difficultyFolder: Folder)

	local self = setmetatable({}, StageGenerator)

	self.StageFolder = stageFolder
	self.ModuleFolder = difficultyFolder

	self._shuffledModules = {}
	self._currentIndex = 1
	self._lastModuleName = nil
	self._nonSafeZoneCount = 0

	self:_shuffleModules()

	return self
end

--------------------------------------------------
-- ステージ初期化
--------------------------------------------------

function StageGenerator:_clearStage()

	for _, child in ipairs(self.StageFolder:GetChildren()) do
		child:Destroy()
	end
end

--------------------------------------------------
-- モジュールシャッフル
--------------------------------------------------

function StageGenerator:_shuffleModules()

	self._shuffledModules = {}

	for _, m in ipairs(self.ModuleFolder:GetChildren()) do
		if m.Name ~= "Goal"
			and m.Name ~= "SafeZone"
			and m.Name ~= "SafeZone_50" then
			table.insert(self._shuffledModules, m)
		end
	end

	for i = #self._shuffledModules, 2, -1 do
		local j = math.random(1, i)
		self._shuffledModules[i], self._shuffledModules[j] =
			self._shuffledModules[j], self._shuffledModules[i]
	end

	self._currentIndex = 1
end

--------------------------------------------------
-- 通常モジュール取得
--------------------------------------------------

function StageGenerator:_getNextNonSafeModule()

	if self._currentIndex > #self._shuffledModules then
		self:_shuffleModules()
	end

	local module = self._shuffledModules[self._currentIndex]
	self._currentIndex += 1

	return module
end

--------------------------------------------------
-- モジュール選択
--------------------------------------------------

function StageGenerator:_getRandomModule(isFirst: boolean)

	if isFirst then
		return self.ModuleFolder:FindFirstChild("SafeZone")
	end

	if self._nonSafeZoneCount >= 5 then
		self._nonSafeZoneCount = 0
		return self.ModuleFolder:FindFirstChild("SafeZone_50")
	end

	local selected = self:_getNextNonSafeModule()

	if self._lastModuleName and selected.Name == self._lastModuleName then
		selected = self:_getNextNonSafeModule()
	end

	self._lastModuleName = selected.Name
	self._nonSafeZoneCount += 1

	return selected
end

--------------------------------------------------
-- ステージ生成
--------------------------------------------------

function StageGenerator:Generate()

	self:_clearStage()

	local spawn = Workspace:WaitForChild("SpawnLocation")
	local spawnEnd = spawn:WaitForChild("EndMarker")

	local currentCFrame = spawnEnd.CFrame

	for i = 1, SEGMENT_COUNT do

		local template

		if i == SEGMENT_COUNT then
			template = self.ModuleFolder:WaitForChild("Goal")
		else
			template = self:_getRandomModule(i == 1)
		end

		if not template then
			warn("テンプレート取得失敗")
			return
		end

		local newSegment = template:Clone()
		newSegment.Parent = self.StageFolder

		-- チェックポイント設定
		if template.Name ~= "Goal" then
			local checkpoint =
				newSegment:FindFirstChild("CheckpointPart", true)

			if checkpoint then
				checkpoint:SetAttribute("CheckpointID", i)
			end
		end

		local startMarker = newSegment:FindFirstChild("StartMarker")
		local endMarker   = newSegment:FindFirstChild("EndMarker")

		if not startMarker or not endMarker then
			warn("Marker不足:", newSegment.Name)
			return
		end

		newSegment:PivotTo(currentCFrame)

		local offset =
			startMarker.CFrame:ToObjectSpace(endMarker.CFrame)

		local gap = math.random(MIN_GAP, MAX_GAP)

		currentCFrame =
			currentCFrame
			* offset
			* CFrame.new(0, 0, gap)
	end

	print("[StageGenerator] Stage generated")
end

return StageGenerator