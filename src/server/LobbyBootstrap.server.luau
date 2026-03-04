--==================================================
-- LobbyBootstrap.server.luau
-- ロビーサーバー初期化
-- ※このスクリプトはロビー Place（LOBBY_PLACE_ID）にのみ配置する
--
-- ［ロビーフロー］
--   1. プレイヤーがロビーに参加（DataManager がデータをロード）
--   2. LobbyManager が DifficultyGate タッチを受け付け
--   3. MatchmakingManager がキューを監視し条件を満たしたらテレポート
--
-- ［Workspace 要件］
--   LobbyStage フォルダ配下に難易度ゲートを配置する:
--     BasePart Name="DifficultyGate"  Attribute Difficulty="Easy"
--     BasePart Name="DifficultyGate"  Attribute Difficulty="Normal"
--     BasePart Name="DifficultyGate"  Attribute Difficulty="Hard"
--==================================================

--// Services
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Folders
local ManagersFolder   = script.Parent:WaitForChild("Managers")
local DataModuleFolder = script.Parent:WaitForChild("DataModule")
local SharedFolder     = ReplicatedStorage:WaitForChild("shared")

--// Modules
local DataManager              = require(DataModuleFolder:WaitForChild("DataManager"))
local LobbyManager             = require(ManagersFolder:WaitForChild("LobbyManager"))
local MatchmakingManager       = require(ManagersFolder:WaitForChild("MatchmakingManager"))
local BGMManager               = require(ManagersFolder:WaitForChild("BGMManager"))
local LobbyLeaderboardManager  = require(ManagersFolder:WaitForChild("LobbyLeaderboardManager"))
local Constants                = require(SharedFolder:WaitForChild("Constants"))

--// サーバー種別ガード（PlaceId 判定 + Studio フォールバック）
-- PlaceId が LOBBY_PLACE_ID と一致 = ロビーサーバー
-- Studio（PlaceId = 0）: ActiveStage なし = ロビーとして扱う
local _placeId = game.PlaceId
local _isLobby = (_placeId == Constants.LOBBY_PLACE_ID)
	or (_placeId == 0 and not Workspace:FindFirstChild("ActiveStage"))
if not _isLobby then
	return
end

-- LobbyStage を取得（なければ Workspace 全体をスキャン対象にする）
local LobbyStage = Workspace:FindFirstChild("LobbyStage") or Workspace

-- LobbyBoard を取得（Workspace 直下 or LobbyStage 配下）
local LobbyBoard = Workspace:FindFirstChild("LobbyBoard")
	or LobbyStage:FindFirstChild("LobbyBoard", true)

--==================================================
-- 初期化（依存関係順）
--==================================================

-- ① DataManager（プレイヤーデータ永続化）
local dataManager = DataManager.new()
dataManager:Init()

-- ② LobbyManager（ゲートタッチ・待機キュー管理）
local lobbyManager = LobbyManager.new(LobbyStage)
lobbyManager:Init()

-- ③ MatchmakingManager（「誰が走るか」決定・テレポート）
local matchmakingManager = MatchmakingManager.new(lobbyManager, {
	placeIds = {
		Easy   = Constants.EASY_PLACE_ID,
		Normal = Constants.NORMAL_PLACE_ID,
		Hard   = Constants.HARD_PLACE_ID,
	},
	maxPlayers        = Constants.MAX_PLAYERS,
	countdownInitial  = Constants.COUNTDOWN_INITIAL,
	countdownFullRoom = Constants.COUNTDOWN_FULLROOM,
})
matchmakingManager:Init()

-- ④ BGM（ロビー用トラック）
local bgmManager = BGMManager.new()
bgmManager:Play("lobby")  -- SoundLibrary.bgm.lobby を追加すること

-- ⑤ LeaderboardManager（Wins / BestTime / TopScore 掲示板）
local leaderboardManager = LobbyLeaderboardManager.new(LobbyBoard)
leaderboardManager:Init()

--==================================================
-- PlayerAdded（DataManager セッションロード + ランキング登録）
--==================================================

-- データロード完了を待ってランキングに登録するヘルパー
local function submitAfterLoad(player)
	for _ = 1, 10 do
		task.wait(1)
		if not player.Parent then return end  -- 退出済み
		local data = dataManager:GetData(player)
		if data then
			leaderboardManager:Submit(player.UserId, data)
			return
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	dataManager:_onPlayerAdded(player.UserId)
	task.spawn(submitAfterLoad, player)
end)

-- Studio テスト等、既参加プレイヤー対応
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		dataManager:_onPlayerAdded(player.UserId)
		submitAfterLoad(player)
	end)
end

print("[LobbyBootstrap] Initialized")
