local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local stageFolder = Workspace:WaitForChild("ActiveStage")
local moduleFolder = ReplicatedStorage:WaitForChild("StageModules"):WaitForChild("Easy")

local SEGMENT_COUNT = 19
local MIN_GAP = 4
local MAX_GAP = 6

-- ルール1: SpawnLocationの位置を取得
local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
if not spawnLocation then
	warn("SpawnLocationが見つかりません")
	return
end

-- ルール1: スタート地点をSpawnLocationの位置に設定
local startPosition = spawnLocation.Position
-- ステージを消す
local function clearStage()
	for _, child in ipairs(stageFolder:GetChildren()) do
		child:Destroy()
	end
end

local shuffledModules = {}
local currentIndex = 1

local function shuffleModules()
	shuffledModules = {}

	for _, m in ipairs(moduleFolder:GetChildren()) do
		if m.Name ~= "Goal"
			and m.Name ~= "SafeZone"
			and m.Name ~= "SafeZone_50" then
			table.insert(shuffledModules, m)
		end
	end

	for i = #shuffledModules, 2, -1 do
		local j = math.random(1, i)
		shuffledModules[i], shuffledModules[j] =
			shuffledModules[j], shuffledModules[i]
	end

	currentIndex = 1
end

local function getNextNonSafeModule()

	if currentIndex > #shuffledModules then
		shuffleModules()
	end

	local module = shuffledModules[currentIndex]
	currentIndex += 1

	return module
end

-- モジュール取得
local lastModuleName = nil
local nonSafeZoneCount = 0

local function getRandomModule(isFirst)

	-- ?? Goal を除外したリストを作る
	local modules = {}

	for _, m in ipairs(moduleFolder:GetChildren()) do
		if m.Name ~= "Goal" then
			table.insert(modules, m)
		end
	end

	if #modules == 0 then
		warn("Easyフォルダにモジュールがありません")
		return nil
	end

	if isFirst then
		return moduleFolder:FindFirstChild("SafeZone")
	end

	if nonSafeZoneCount >= 5 then
		nonSafeZoneCount = 0
		return moduleFolder:FindFirstChild("SafeZone_50")
	end

	local selected = getNextNonSafeModule()
	-- ?? 同じモジュールを回避
	if lastModuleName and selected.Name == lastModuleName then
		selected = getNextNonSafeModule()
	end

	lastModuleName = selected.Name
	nonSafeZoneCount += 1

	return selected
end

local function generateStage()

	clearStage()

	-- ?? SpawnLocation の EndMarker を取得
	local spawn = workspace:WaitForChild("SpawnLocation")
	local spawnEnd = spawn:WaitForChild("EndMarker")

	-- ?? ここを起点にする
	local currentCFrame = spawnEnd.CFrame

	for i = 1, SEGMENT_COUNT do

		local template

		if i == SEGMENT_COUNT then
			template = moduleFolder:WaitForChild("Goal")
		else
			template = getRandomModule(i == 1)
		end

		if not template then return end

		local newSegment = template:Clone()
		newSegment.Parent = stageFolder

		-- チェックポイントにIDを設定
		if template.Name ~= "Goal" then
			local checkpointPart = newSegment:FindFirstChild("CheckpointPart", true)
			if checkpointPart then
				checkpointPart:SetAttribute("CheckpointID", i)
			end
		end

		local startMarker = newSegment:FindFirstChild("StartMarker")
		local endMarker   = newSegment:FindFirstChild("EndMarker")

		if not startMarker or not endMarker then
			warn("StartMarker または EndMarker がありません:", newSegment.Name)
			return
		end

		-- ?? まず現在位置に配置
		newSegment:PivotTo(currentCFrame)

		-- ?? ローカル差分を計算
		local offset =
			startMarker.CFrame:ToObjectSpace(endMarker.CFrame)

		-- ランダム隙間
		local gap = math.random(MIN_GAP, MAX_GAP)

		-- 次の位置へ
		currentCFrame =
			currentCFrame
			* offset
			* CFrame.new(0, 0, gap)
		---- ?? 次の基準位置を更新
		--currentCFrame = currentCFrame * offset
	end

	print("ステージ生成完了")
end

-- 起動時に生成
generateStage()