--==================================================
-- Bootstrap.server.luau
-- サーバー初期化管理（仕様書 §11 フォルダ構成準拠）
--==================================================

--// Services
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--==================================================
-- サーバー種別ガード（PlaceId 判定 + Studio フォールバック）
-- PlaceId が LOBBY_PLACE_ID と一致 = ロビーサーバー → このスクリプトは不要
-- Studio（PlaceId = 0）: ActiveStage の有無で判定（テスト用）
--==================================================
local SharedFolder  = ReplicatedStorage:WaitForChild("shared")
local Constants     = require(SharedFolder:WaitForChild("Constants"))

local _placeId      = game.PlaceId
local _isGameServer = (_placeId ~= 0 and _placeId ~= Constants.LOBBY_PLACE_ID)
	or (_placeId == 0 and Workspace:FindFirstChild("ActiveStage") ~= nil)
if not _isGameServer then
	return
end

--==================================================
-- DIFFICULTY: PlaceId から自動判定（手動変更不要）
-- Studio（PlaceId = 0）は "Easy" にフォールバック
--==================================================
local _PLACE_TO_DIFFICULTY = {
	[Constants.EASY_PLACE_ID]   = "Easy",
	[Constants.NORMAL_PLACE_ID] = "Normal",
	[Constants.HARD_PLACE_ID]   = "Hard",
}
local DIFFICULTY = _PLACE_TO_DIFFICULTY[_placeId] or "Easy"

--==================================================
-- フォルダ取得
--==================================================
local ManagersFolder      = script.Parent:WaitForChild("Managers")
local DataModuleFolder    = script.Parent:WaitForChild("DataModule")
local StageConfigsFolder  = script.Parent:WaitForChild("StageConfigs")

-- ActiveStage: なければ自動生成（Workspace に手動配置不要）
local ActiveStage = Workspace:FindFirstChild("ActiveStage")
if not ActiveStage then
	ActiveStage = Instance.new("Folder")
	ActiveStage.Name   = "ActiveStage"
	ActiveStage.Parent = Workspace
end
local StageModels       = ReplicatedStorage:WaitForChild("StageModels")
local DifficultyFolder  = StageModels:WaitForChild(DIFFICULTY)

--==================================================
-- ModuleScript 読み込み（仕様§3.1 コンポーネント構成）
--==================================================

-- DataModule
local DataManager    = require(DataModuleFolder:WaitForChild("DataManager"))
local RankingManager = require(DataModuleFolder:WaitForChild("RankingManager"))

-- Managers
local CheckpointManager = require(ManagersFolder:WaitForChild("CheckpointManager"))
local GoalManager       = require(ManagersFolder:WaitForChild("GoalManager"))
local GoalEffectManager = require(ManagersFolder:WaitForChild("GoalEffectManager"))
local RunManager        = require(ManagersFolder:WaitForChild("RunManager"))
local StageGenerator    = require(ManagersFolder:WaitForChild("StageGenerator"))
local BGMManager  = require(ManagersFolder:WaitForChild("BGMManager"))
local RewardService     = require(ManagersFolder:WaitForChild("RewardService"))
local TeleportHandler   = require(ManagersFolder:WaitForChild("TeleportHandler"))

--==================================================
-- インスタンス生成・初期化（依存関係順）
--==================================================

-- ① ステージ生成（最初に行う：GoalManager が GoalTrigger を監視するため）
local StageConfig    = require(StageConfigsFolder:WaitForChild(DIFFICULTY .. "StageConfig"))
local stageGenerator = StageGenerator.new(ActiveStage, DifficultyFolder, StageConfig)
stageGenerator:Generate()

-- ② DataManager（全 Manager の永続化基盤、仕様§7.2）
local dataManager = DataManager.new()
dataManager:Init()  -- 保存トリガー3重起動（PlayerRemoving / BindToClose / AutoSave）

-- ③ RankingManager（OrderedDataStore、独立、仕様§8）
local rankingManager = RankingManager.new()

-- ④ RewardService（DataManager に依存、仕様§6）
local rewardService = RewardService.new(dataManager)

-- ⑤ RunManager（走行時間管理、仕様§5.2）
local runManager = RunManager.new()

-- ⑥ GoalManager（全依存を注入、仕様§3.1）
local goalManager = GoalManager.new(ActiveStage, {
	runManager     = runManager,
	dataManager    = dataManager,
	rewardService  = rewardService,
	rankingManager = rankingManager,
	difficulty     = DIFFICULTY,
})
goalManager:Init()

-- ⑦ CheckpointManager（中間地点管理、仕様§3.1、自己管理型）
CheckpointManager.new(ActiveStage)

-- ⑧ BGMManager（BGM 再生、仕様§3.1）
local bgmManager = BGMManager.new()
bgmManager:Play(string.lower(DIFFICULTY))  -- "easy" | "normal" | "hard"

-- ⑨ GoalEffectManager（ゴール視覚演出、GoalManager と並立、自己管理型）
GoalEffectManager.new(ActiveStage)

-- ⑩ TeleportHandler（難易度検証・不正送還、仕様§4.3）
local teleportHandler = TeleportHandler.new(DIFFICULTY)
teleportHandler:Init()

--==================================================
-- PlayerAdded（DataManager のセッションロード）
-- ※DataManager:Init() 内の PlayerRemoving とセットで管理
--==================================================
Players.PlayerAdded:Connect(function(player)
	dataManager:_onPlayerAdded(player.UserId)
end)

-- Studio テスト時など、既に参加済みのプレイヤーを処理
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		dataManager:_onPlayerAdded(player.UserId)
	end)
end

print("[Bootstrap] All Managers initialized - Difficulty:", DIFFICULTY)
