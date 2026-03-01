--==================================================
-- CheckpointManager (ModuleScript)
-- サーバー側チェックポイント管理 + DataStore保存
--==================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local CheckpointManager = {}
CheckpointManager.__index = CheckpointManager

-- DataStore
local checkpointStore = DataStoreService:GetDataStore("CheckpointData_v1")

--------------------------------------------------
-- CFrameシリアライズ
--------------------------------------------------

local function serializeCFrame(cf)
	return {cf:GetComponents()}
end

local function deserializeCFrame(data)
	return CFrame.new(unpack(data))
end

--------------------------------------------------
-- コンストラクタ
--------------------------------------------------

function CheckpointManager.new(activeStage)
	local self = setmetatable({}, CheckpointManager)

	self.ActiveStage = activeStage
	self:_setupStage()

	self:_connectPlayers()

	return self
end

--------------------------------------------------
-- プレイヤー接続
--------------------------------------------------

function CheckpointManager:_connectPlayers()

	Players.PlayerAdded:Connect(function(player)

		-- データロード
		self:_loadPlayerData(player)

		player.CharacterAdded:Connect(function(character)
			self:_restoreCheckpoint(player, character)
		end)
	end)
end

--------------------------------------------------
-- チェックポイント復元
--------------------------------------------------

function CheckpointManager:_restoreCheckpoint(player, character)

	local savedData = player:GetAttribute("CheckpointCFrame")
	if not savedData then return end

	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then return end

	task.defer(function()
		root.CFrame = deserializeCFrame(savedData)
	end)
end

--------------------------------------------------
-- チェックポイント保存
--------------------------------------------------

function CheckpointManager:_savePlayerData(player)

	local data = {
		LastCheckpointID = player:GetAttribute("LastCheckpointID"),
		CheckpointCFrame = player:GetAttribute("CheckpointCFrame")
	}

	local success, err = pcall(function()
		checkpointStore:SetAsync(player.UserId, data)
	end)

	if not success then
		warn("DataStore save failed:", err)
	end
end

--------------------------------------------------
-- データロード
--------------------------------------------------

function CheckpointManager:_loadPlayerData(player)

	local success, result = pcall(function()
		return checkpointStore:GetAsync(player.UserId)
	end)

	if success and result then
		player:SetAttribute("LastCheckpointID", result.LastCheckpointID)
		player:SetAttribute("CheckpointCFrame", result.CheckpointCFrame)
	else
		if not success then
			warn("DataStore load failed")
		end
	end
end

--------------------------------------------------
-- チェックポイント設定
--------------------------------------------------

function CheckpointManager:_setupCheckpoint(part)

	if part:GetAttribute("Initialized") then return end
	part:SetAttribute("Initialized", true)

	part.Touched:Connect(function(hit)

		if hit.Name ~= "HumanoidRootPart" then return end

		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local checkpointID = part:GetAttribute("CheckpointID")
		if not checkpointID then return end

		if player:GetAttribute("LastCheckpointID") == checkpointID then
			return
		end

		local forward = -part.CFrame.LookVector
		local position = part.Position + Vector3.new(0, 4, 0)
		local fixedCFrame = CFrame.new(position, position + forward)

		player:SetAttribute("LastCheckpointID", checkpointID)
		player:SetAttribute("CheckpointCFrame", serializeCFrame(fixedCFrame))

		self:_savePlayerData(player)

		part.CanTouch = false
		task.delay(1, function()
			if part.Parent then
				part.CanTouch = true
			end
		end)
	end)
end

--------------------------------------------------
-- ステージ登録
--------------------------------------------------

function CheckpointManager:_setupStage()

	for _, obj in ipairs(self.ActiveStage:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "CheckpointPart" then
			self:_setupCheckpoint(obj)
		end
	end

	self.ActiveStage.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") and obj.Name == "CheckpointPart" then
			self:_setupCheckpoint(obj)
		end
	end)
end

return CheckpointManager